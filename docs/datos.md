# Pipeline de datos

Todo se regenera con:

```bash
Rscript scripts/ingesta/run_pipeline.R                       # anuncios + observatorio
Rscript scripts/ingesta/run_pipeline.R --solo-observatorio   # solo el observatorio
```

Las descargas se cachean en `data/raw/` para no repetir peticiones si ya son recientes. Si una fuente cambia de formato o de URL, el paso correspondiente se detiene con un error explícito que indica qué ha encontrado, en vez de guardar datos mal interpretados en silencio. Un fallo del observatorio dentro del pipeline completo no invalida el dataset de anuncios ya guardado.

Solo para regenerar datos hacen falta, además de las dependencias de la app:

| Dependencia | Uso |
|---|---|
| `{httr}` | Descarga de las fuentes (Suggests en `DESCRIPTION`) |
| `{readxl}` | Lectura del Excel de Barcelona (Suggests) |
| `{jsonlite}` | Geocodificación vía Nominatim (ya en Imports) |
| `{sf}` | Lectura y simplificación del shapefile de SERPAVI (ya en Imports) |
| `pdftotext` (paquete de sistema `poppler-utils`) | Texto del informe trimestral de Bilbao. En Linux: `sudo apt install poppler-utils` |

## Dataset de anuncios (`alquileres.parquet`) {#pipeline-anuncios}

Pasos 01 a 08: configuración → utilidades → una fuente por ciudad → anclas manuales → geocodificación → armonización → generación. Para añadir una ciudad basta con tocar `00_config.R` y, si no hay fuente oficial, `data/raw/anclas_manuales.csv`.

| Ciudad | Fuente | Detalle | Fiabilidad |
|---|---|---|---|
| **Barcelona** | Generalitat de Catalunya (INCASÒL), fianzas de alquiler depositadas | Por barrio (73 barrios) | Oficial |
| **Bilbao** | Gobierno Vasco (Etxebide), Informe EMAL trimestral | Por barrio (€/m² ya calculado por la fuente) | Oficial |
| **Valencia** | Generalitat Valenciana, registro de fianzas | Por código postal (barrio resuelto por geocodificación inversa) | Oficial |
| **Madrid, Sevilla** | Sin fuente pública con importe y geografía (verificado) | Municipio + algunos barrios conocidos | Ancla manual en `data/raw/anclas_manuales.csv` |

En Madrid y Sevilla no existe ningún registro público, ni estatal ni autonómico, de fianzas con importe y desglose geográfico; se comprobó expresamente. Para esos casos se usa un **ancla manual**: un precio/m² documentado a mano a partir de un índice publicado (idealista/fotocasa), con fecha, URL y nota de fiabilidad. Esas filas quedan marcadas como estimadas.

La geocodificación usa [Nominatim/OpenStreetMap](https://nominatim.openstreetmap.org/) respetando su política de uso (1 petición por segundo, User-Agent identificable) y se cachea en `data/raw/geocache_zonas.csv`.

Esquema del dataset final:

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | texto | Identificador único del inmueble |
| `titulo` | texto | Título generado (tipo + zona + ciudad) |
| `ciudad` | texto | Municipio |
| `barrio` | texto | Barrio/distrito/código postal resuelto (o el municipio si no hay desglose) |
| `tipo` | texto | Piso, Apartamento, Ático, Estudio o Casa / Chalet |
| `precio` | numérico | Alquiler mensual estimado (€), derivado del €/m² real de la zona |
| `superficie` | numérico | Superficie (m²) |
| `habitaciones` / `banos` | numérico | Nº de habitaciones / baños |
| `lat` / `lon` / `lng` | numérico | Coordenadas reales de la zona (no aleatorias) |
| `fuente_dato` | texto | Fuente del €/m² de esa zona |
| `es_estimado` | lógico | `TRUE` si la zona no tiene fuente oficial (ancla manual) |
| `nivel_geo` | texto | Granularidad real del dato: `barrio`, `municipio`, `zona_sin_fuente_oficial`… |

Los "anuncios" individuales son una ilustración generada dentro de cada zona (superficie, tipología y un margen de ruido aleatorio con semilla fija), pero el precio de cada uno **siempre parte del €/m² real de su zona**.

## Observatorio del Alquiler (`observatorio_municipios.parquet`) {#pipeline-observatorio}

Lo genera `09_observatorio.R`: una fila por municipio (~4,8 MB) con los indicadores y la geometría en WKB a dos niveles de detalle. Todas las fuentes se refieren al mismo año, `ANIO_OBSERVATORIO` en `00_config.R` (2022), para que los ratios entre ellas comparen el mismo ejercicio. Las descargas se cachean en `data/raw/observatorio/` (no versionado, ~100 MB).

| Fuente | Qué se descarga | Cómo |
|---|---|---|
| **SERPAVI** (Ministerio de Vivienda y Agenda Urbana) | Medianas de alquiler (€/m², €/mes, superficie, nº de viviendas) y geometría municipal (IGN) | La web de SERPAVI es una calculadora con reCAPTCHA, pero el CDN del Ministerio publica la capa completa como shapefile (`ALQ_Municipios_2022_Web.zip`, ~43 MB) |
| **INE, ADRH** | Renta neta media por hogar y por persona | Tabla nacional 30824 (~350 MB sin comprimir, con todas las secciones censales): se descarga comprimida y se filtra en streaming a las filas de municipio del año de referencia |
| **INE, Padrón** | Población por municipio | Tabla 29005 (cifras oficiales de todos los municipios y años) |
| **Catastro** | Nº de inmuebles y valor catastral de uso residencial | Tablas JAXI por provincia (`URAO`/`URBO`). No hay descarga directa del `.px`: se reproduce el envío del formulario "Consultar todo" y se parsea la tabla HTML |

**Mediana de alquiler.** Se usa la de vivienda colectiva (pisos). SERPAVI solo la publica si hay suficientes contratos de pisos; en 749 municipios (p. ej. Torrent) solo hay mediana de unifamiliares, y en ese caso se usa esa y la columna `tipo_vivienda_alquiler` lo indica para que la ficha lo advierta.

**Cruce del Catastro con el INE.** El Catastro no publica el código INE en sus tablas municipales, así que se cruza por nombre en tres pasos, siempre dentro de cada provincia:

1. **Nombre normalizado** (`claves_municipio()`): sin tildes ni signos, con el artículo delante ("Acebeda (La)", "Acebeda, La" y "La Acebeda" dan la misma clave) y una clave por idioma en los nombres bilingües ("Alicante/Alacant").
2. **Equivalencias manuales** (`EQUIVALENCIAS_CATASTRO`): renombramientos completos que no se pueden deducir con seguridad, como Alfara de Algimia → Alfara de la Baronia.
3. **Nombre aproximado** (`emparejar_aproximado()`), solo con lo que queda sin cruzar: distancia de edición relativa ≤ 0,35, o un nombre contenido en el otro. Los empates ambiguos se descartan y, si en una provincia queda exactamente un nombre y un código libres, se emparejan entre sí. El pipeline imprime los cruces aproximados para poder revisarlos.

Con esto se cruzan los 7.612 nombres del Catastro. Cuatro corresponden a municipios gallegos fusionados en 2013 y 2016 (Oza-Cesuras, Cerdedo-Cotobade) que el Catastro aún lista por separado y no aparecen en el mapa.

**Geometría.** Se simplifica a dos tolerancias sobre EPSG:3857: ~250 m (vista de una provincia) y ~1,5 km (vista de toda España). Se guarda en WKB y `observatorio_a_sf()` la reconstruye en la app.

**Limitaciones conocidas** (la app las explica en la ficha de cada municipio, mediante `motivo_sin_dato()`):

- **País Vasco y Navarra** no aparecen en SERPAVI ni en el Catastro estatal (tienen Hacienda y Catastro forales). Sus municipios solo tienen renta y población; el nombre de provincia se rellena a partir del código INE porque SERPAVI lo deja vacío.
- SERPAVI publica la mediana en 2.966 de 8.131 municipios, que concentran el 90 % de la población. El resto no tiene suficientes contratos declarados.
- El INE no publica la renta de los municipios muy pequeños, por secreto estadístico.
- "Viviendas en alquiler" cuenta **alquileres declarados** a Hacienda: es una cota inferior del peso real del alquiler.
- Los 86 polígonos con código 53xxx/54xxx no son municipios sino territorios compartidos entre varios (parzonerías, comunidades de montes). Se marcan con `es_municipio = FALSE`.
