<a id="top"></a>
# Guía técnica de GeoAlquiler

Esta guía explica el código en detalle: cómo está organizado, cómo fluyen los datos, cómo se generan y cómo se ejecuta, prueba y despliega la app. Para una visión general del proyecto, empieza por el [README](../README.md).

## Índice

- [1. Arquitectura](#arquitectura)
- [2. Estructura del proyecto](#estructura)
- [3. Flujo de datos dentro de la app](#flujo-datos)
- [4. Recorrido por el código](#codigo)
- [5. Pipeline de datos](#pipeline)
  - [5.1 Dataset de anuncios](#pipeline-anuncios)
  - [5.2 Observatorio del Alquiler](#pipeline-observatorio)
- [6. Rendimiento](#rendimiento)
- [7. Instalación y ejecución](#instalacion)
- [8. Tests](#tests)
- [9. Integración continua](#ci)
- [10. Despliegue](#despliegue)
- [11. Dónde tocar para…](#donde-tocar)

---

<a id="arquitectura"></a>
## 1. Arquitectura

![Esquema de la arquitectura de GeoAlquiler](../man/figures/arquitectura.svg)

La app se organiza en tres capas que no se mezclan:

1. **Ingesta offline** (`scripts/ingesta/`): descarga, limpia y cruza las fuentes. Se ejecuta a mano y produce dos ficheros Parquet que viajan con el paquete. La app nunca descarga nada en tiempo de ejecución.
2. **Lógica de negocio sin Shiny** (`R/fct_*.R`): funciones puras, sin `input`, `output` ni reactividad, que usan tanto el pipeline como la app y se prueban directamente con `testthat`.
3. **Interfaz reactiva por módulos** (`R/mod_*.R`): cada pantalla es un módulo; `app_ui.R` y `app_server.R` solo los ensamblan.

[⬆ Volver arriba](#top)

---

<a id="estructura"></a>
## 2. Estructura del proyecto

GeoAlquiler no es una app de Shiny en un único `app.R`, sino un **paquete de R** construido con [`{golem}`](https://thinkr-open.github.io/golem/). Eso aporta lo propio de un paquete: dependencias declaradas en `DESCRIPTION`, documentación con `roxygen2`, tests con `testthat` y un ciclo claro de desarrollo → build → despliegue.

```
geo-alquiler/
├── DESCRIPTION            # Metadatos del paquete y dependencias (Imports / Suggests)
├── NAMESPACE              # Generado por roxygen2 a partir de las etiquetas @import (versionado)
├── app.R                  # Lanzador: pkgload::load_all() + run_app()
├── R/
│   ├── run_app.R          # Punto de entrada: shinyApp(ui = app_ui, server = app_server)
│   ├── app_ui.R           # UI global: dashboardPage, menú lateral y tabItems
│   ├── app_server.R       # Server global: carga los datos y llama a cada módulo
│   ├── mod_mapa.R         # Mapa del Panel Principal + heatmap; devuelve los datos del encuadre
│   ├── mod_filtros.R      # Filtros globales
│   ├── mod_tabla.R        # Explorador de datos (DT)
│   ├── mod_barrios.R      # Analítica por barrios
│   ├── mod_favoritos.R    # Favoritos de la sesión
│   ├── mod_exportar.R     # Exportación a CSV
│   ├── mod_graficos.R     # Analítica visual (plotly)
│   ├── mod_estadistica.R  # Estadística avanzada
│   ├── mod_prediccion.R   # Predicción de precios (regresión)
│   ├── mod_recomendador.R # Recomendador KNN
│   ├── mod_comparador.R   # Comparador A/B
│   ├── mod_oportunidades.R# Detector de oportunidades
│   ├── mod_calculadora.R  # Calculadora de rentabilidad
│   ├── mod_reporte.R      # Informe ejecutivo descargable
│   ├── mod_observatorio.R # Observatorio del Alquiler (mapa coroplético municipal)
│   ├── fct_calculos.R     # Cálculos de negocio sin Shiny: KPIs, encuadre del mapa, hipoteca y
│   │                      #   proyección, oportunidades, similitud KNN, fórmula de predicción
│   └── fct_observatorio.R # Lógica del observatorio sin Shiny: indicadores, formato,
│                          #   motivos de "sin dato", WKB -> sf, JSON de geometría, caché
├── inst/app/
│   ├── data/              # alquileres.parquet y observatorio_municipios.parquet
│   └── www/               # custom.css y custom.js (ver secciones 4.4 y 6)
├── scripts/
│   ├── deploy.R           # Despliegue a shinyapps.io (lista de ficheros a subir)
│   └── ingesta/
│       ├── 00_config.R            # Ciudades, rutas, año de referencia del observatorio
│       ├── 01_utils.R             # Descarga con caché + geocodificación (Nominatim)
│       ├── 02_fuente_barcelona.R  # Generalitat de Catalunya (INCASÒL)
│       ├── 03_fuente_valencia.R   # Generalitat Valenciana (fianzas)
│       ├── 04_fuente_bilbao.R     # Etxebide / Gobierno Vasco (Informe EMAL)
│       ├── 05_anclas_manuales.R   # Precios documentados a mano donde no hay fuente oficial
│       ├── 06_geocodificar_zonas.R# Lat/lon reales por zona
│       ├── 07_armonizar_precios.R # Combina todas las fuentes en una tabla única
│       ├── 08_generar_anuncios.R  # Genera los inmuebles que usa la app
│       ├── 09_observatorio.R      # SERPAVI + INE (renta, padrón) + Catastro por municipio
│       └── run_pipeline.R         # Orquestador
├── data/
│   ├── raw/               # Cachés de descarga (no versionadas) + anclas_manuales.csv (versionado)
│   └── processed/         # Copia de los Parquet generados
├── man/figures/           # Capturas y esquema de arquitectura de la documentación
├── docs/                  # Esta guía
├── reporte_plantilla.Rmd  # Plantilla del Informe Ejecutivo
├── tests/testthat/        # Tests (ver sección 8)
├── .github/workflows/
│   └── ci.yml             # Integración continua: tests y despliegue (ver sección 9)
└── renv.lock              # Versiones exactas de todas las dependencias
```

### Convenciones

- **Módulos**: cada pantalla vive en su `mod_*.R` con el patrón de [Shiny Modules](https://shiny.posit.co/r/articles/improve/modules/) (`NS(id)`, `*UI()` y `*Server()`). Así no colisionan los `inputId`/`outputId` y `app_ui.R`/`app_server.R` solo orquestan.
- **Lógica sin Shiny** en `fct_*.R`: si una función no necesita reactividad, va ahí y se testea sin servidor.
- **`app_ui.R`** define solo la estructura visual: el `dashboardPage`, el menú lateral (Panel Principal, Observatorio, Exploración, Analítica, Inversión e Información) y los `tabItems` que enlazan cada pestaña con la UI de su módulo.
- **`run_app.R`** envuelve la `shinyApp` con `golem::with_golem_options()`, de modo que se pueden pasar opciones (`golem_opts`) sin tocar el resto del código.
- **`app.R`** es el lanzador universal: hace `pkgload::load_all()` y activa `golem.app.prod = TRUE`, así que funciona igual en local que en Shiny Server, Posit Connect, shinyapps.io o un contenedor, sin instalar el paquete.
- **Datos empaquetados** en `inst/app/data/`, siguiendo la convención de `{golem}`: viajan con el paquete y están disponibles tanto en desarrollo como desplegado.
- **Dependencias reproducibles** con `{renv}` (`renv.lock` + `.Rprofile`).

[⬆ Volver arriba](#top)

---

<a id="flujo-datos"></a>
## 3. Flujo de datos dentro de la app

`app_server.R` carga los dos ficheros Parquet y decide qué versión de los datos recibe cada módulo. Es la decisión de diseño central de la app:

```
alquileres.parquet ──► datos_totales ──► mod_filtros ──► datos filtrados ──► mod_mapa ──► datos_visibles
                            │                                  │                              │
                            │                                  └─► Recomendador KNN           └─► Tabla, Analítica, Estadística,
                            └─► Comparador, Predicción,                                           Oportunidades, Calculadora,
                                Barrios, Favoritos                                                Informe, Exportar

observatorio_municipios.parquet ──► cargar_observatorio() (una vez por proceso) ──► mod_observatorio
```

| El módulo recibe… | Módulos | Por qué |
|---|---|---|
| `datos_visibles`: filtros + lo que se ve en el mapa del Panel Principal | Tabla, Analítica, Estadística, Oportunidades, Calculadora, Informe, Exportar | Responden a "lo que estoy mirando ahora" |
| Datos filtrados, sin recorte del mapa | Recomendador KNN | Buscar similares solo en el encuadre daría muy pocos candidatos |
| Dataset completo (`datos_totales`) | Comparador, Predicción, Barrios, Favoritos | Necesitan todo el mercado: entrenar el modelo, comparar ciudades, no perder favoritos al filtrar |
| Su propio dataset | Observatorio | Datos oficiales agregados por municipio, independientes de los filtros |

Detalles que conviene conocer:

- **`mod_mapa` devuelve los datos del encuadre visible.** Filtra por `input$mapa_alquiler_bounds`. Un redimensionado del mapa (rotar el móvil, abrir el menú) puede hacer que Leaflet informe un momento de un encuadre inválido; en ese caso se devuelven todos los datos en vez de vaciar las siete pantallas que dependen de `datos_visibles`.
- **Favoritos** se guardan en un `reactiveVal` (`favoritos_ids`) creado en `app_server.R` y compartido entre `mod_tabla` (donde se marcan) y `mod_favoritos` (donde se gestionan). Viven solo durante la sesión.
- **El Observatorio no depende de los filtros globales.** Tiene sus propios controles (indicador, ámbito, población mínima) y su propio estado de municipio seleccionado, que sincroniza mapa, ficha, gráfico y ranking.

[⬆ Volver arriba](#top)

---

<a id="codigo"></a>
## 4. Recorrido por el código

Esta sección recorre los patrones que se repiten en el código, con fragmentos reales del repositorio. Si entiendes estos cinco, puedes leer cualquier fichero de `R/`.

### 4.1 Un módulo: interfaz por un lado, servidor por otro

Cada pantalla es un par de funciones en su `mod_*.R`. La de interfaz (`*UI(id)`) construye los controles con `NS(id)`, que antepone el identificador del módulo a cada `inputId` para que dos módulos puedan tener un control llamado igual sin pisarse. La de servidor (`*Server(id, ...)`) recibe los datos ya preparados como argumento y no sabe de dónde vienen:

```r
oportunidadesServer <- function(id, datos_visibles) {
  moduleServer(id, function(input, output, session) {
    df_oportunidades <- reactive({
      detectar_oportunidades(datos_visibles(), input$pct_descuento)
    })
    # ... KPIs, mapa y tabla a partir de df_oportunidades()
  })
}
```

`datos_visibles` es un `reactive`: el módulo lo llama como función (`datos_visibles()`) y Shiny vuelve a calcular `df_oportunidades` cada vez que cambian los filtros, el encuadre del mapa o el umbral.

### 4.2 Separar el cálculo de la reactividad

La regla del proyecto: **un módulo lee inputs, llama a una función y pinta el resultado**. El cálculo vive en una función pura de `R/fct_calculos.R` o `R/fct_observatorio.R`, sin `input`, `output` ni `reactive`. Así se puede probar con valores concretos, sin levantar un servidor.

La Calculadora es el ejemplo más claro. Toda su lógica financiera (cuota hipotecaria, amortización mes a mes, proyección a N años) está en `simular_inversion()`, y el módulo solo traduce los inputs, que llegan en porcentaje, a tanto por uno:

```r
simulacion <- reactive({
  simular_inversion(
    precio = req(input$precio_compra),
    alquiler_mensual = req(input$alquiler_mensual),
    gastos_anuales = req(input$gastos_mantenimiento),
    pct_entrada = req(input$porcentaje_entrada) / 100,
    tin = req(input$interes_hipoteca) / 100,
    anos = as.numeric(req(input$plazo_anos)),
    inc_alquiler = req(input$incremento_alquiler) / 100,
    aprec_inmueble = req(input$apreciacion_inmueble) / 100
  )
})
```

`req()` detiene el cálculo en silencio mientras un input esté vacío, en vez de propagar un error a la pantalla.

### 4.3 `app_server.R`: el único sitio que sabe qué datos recibe cada módulo

`app_server.R` no contiene lógica: carga los datos, encadena filtros y mapa, y reparte. Leyendo estas líneas se ve el flujo completo descrito en la [sección 3](#flujo-datos):

```r
datos_filtrados_sidebar <- filtrosServer("filtros_sidebar", datos_totales)
datos_visibles <- mapaServer("mapa_principal", datos_filtrados_sidebar)

tablaServer("tabla_principal", datos_visibles, favoritos_ids)
oportunidadesServer("oportunidades_principal", datos_visibles)
recomendadorServer("recomendador_principal", datos_filtrados_sidebar)
prediccionServer("prediccion_principal", datos_totales)
observatorioServer("observatorio_principal", datos_observatorio)
# ...
```

`mapaServer()` es a la vez un módulo y un filtro: pinta el mapa y **devuelve** un `reactive` con los inmuebles del encuadre visible, que es lo que reciben las pantallas que dependen de "lo que estoy mirando". El estado que comparten varios módulos (los favoritos) se crea aquí con `reactiveVal()` y se pasa a los que lo necesitan.

### 4.4 Hablar con el navegador sin reenviar todo

Shiny actualiza una salida mandando su contenido completo. Para el mapa del Observatorio (~8.200 polígonos) eso es demasiado, así que hay tres canales directos con el navegador:

**Servidor → navegador, con un mensaje propio.** Al cambiar de indicador, el servidor no vuelve a pintar el mapa: manda solo los colores y los valores nuevos, identificados por código INE.

```r
session$sendCustomMessage("observatorio_recolorear", list(
  mapa = ns("mapa"), ids = df$cod_ine, colores = est$colores,
  valores = est$valores_txt, sin_dato = formatear_indicador(NA, input$indicador),
  separador = SEP_ETIQUETA
))
```

Y `inst/app/www/custom.js` lo recibe y recolorea los polígonos que ya están dibujados (versión simplificada):

```js
Shiny.addCustomMessageHandler('observatorio_recolorear', function (msg) {
  var mapa = HTMLWidgets.find('#' + msg.mapa).getMap();
  for (var i = 0; i < msg.ids.length; i++) {
    var capa = mapa.layerManager.getLayer('shape', msg.ids[i]);
    if (!capa) continue;
    capa.setStyle({ fillColor: msg.colores[i], fillOpacity: msg.valores[i] === msg.sin_dato ? 0.35 : 0.8 });
    // ... y actualiza la etiqueta conservando el nombre del municipio
  }
});
```

**Navegador → servidor, con un input propio.** Para mandar el gráfico y el ranking solo cuando el mapa ya se ve, el navegador avisa con `Shiny.setInputValue()`, que en el servidor aparece como un input más (`input$mapa_pintado`):

```r
htmlwidgets::onRender("
  function(el) {
    requestAnimationFrame(function() {
      requestAnimationFrame(function() {
        Shiny.setInputValue(el.id + '_pintado', true);
      });
    });
  }")
```

El gráfico y el ranking empiezan con `req(input$mapa_pintado)`, así que no se calculan hasta ese momento.

**Leaflet por proxy.** Cambiar de provincia sustituye los polígonos con `leafletProxy("mapa")`, que manda órdenes al mapa existente (`clearShapes()`, añadir polígonos, encuadrar) en vez de recrearlo.

### 4.5 El pipeline: fallar pronto y con un mensaje útil

Cada fuente del pipeline tiene una función de descarga (con caché) y otra de lectura. La de lectura comprueba primero que el fichero tiene la forma esperada y, si no, se detiene diciendo qué ha encontrado. Así un cambio de formato en una web del Ministerio no acaba en un dataset mal interpretado:

```r
esperadas <- c("CodINE", "CPRO", "LITPRO", "NAMEUNIT", "Num_VC", "Renta_Medi", ...)
faltan <- setdiff(esperadas, names(x))
if (length(faltan) > 0) {
  stop("[SERPAVI] Faltan columnas esperadas en el shapefile: ", paste(faltan, collapse = ", "),
       ". Columnas encontradas: ", paste(names(x), collapse = ", "))
}
```

Los cálculos que comparten pipeline y app (indicadores del Observatorio, normalización de nombres) están en `R/fct_observatorio.R`, y el pipeline los carga con `source()`. Así una misma función no puede dar un resultado al generar los datos y otro distinto al mostrarlos.

[⬆ Volver arriba](#top)

---

<a id="pipeline"></a>
## 5. Pipeline de datos

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

<a id="pipeline-anuncios"></a>
### 5.1 Dataset de anuncios (`alquileres.parquet`)

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

<a id="pipeline-observatorio"></a>
### 5.2 Observatorio del Alquiler (`observatorio_municipios.parquet`)

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

[⬆ Volver arriba](#top)

---

<a id="rendimiento"></a>
## 6. Rendimiento

La app está pensada para cargar rápido también en el móvil y con conexiones lentas. La regla general es hacer el trabajo pesado en el servidor y mandar al navegador solo lo que se va a pintar.

| Optimización | Qué resuelve |
|---|---|
| **Gráficos con `plotly` nativo (no `ggplotly()`)** | Todos los gráficos interactivos se construyen con `plot_ly()`/`add_trace()` en vez de convertir un `ggplot2` con `ggplotly()`, que genera un JSON notablemente más pesado para el mismo gráfico. |
| **Histogramas pre-agregados en el servidor** | Los bins se calculan en R con `hist()` y se envían solo las barras, en vez de cada precio en crudo para que Plotly los agrupe en el navegador. |
| **Submuestreo en gráficos densos** | El scatter de precio/superficie y los boxplots de Estadística Avanzada limitan los puntos que viajan al navegador (muestra aleatoria con un aviso visible) cuando el conjunto filtrado es muy grande. |
| **Mapa agregado por barrio** | La capa por defecto del Panel Principal manda un resumen por barrio (precio medio + nº de inmuebles), no cada inmueble. Los pines individuales y el mapa de calor se cargan bajo demanda (`leafletProxy`) solo si se activa esa capa. |
| **Clustering de marcadores** | El mapa de Oportunidades agrupa sus marcadores (`markerClusterOptions`) para que un umbral poco restrictivo no sature el navegador. |
| **CSS responsive** (`inst/app/www/custom.css`) | Ajusta las alturas de Leaflet/Plotly (fijas en píxeles por defecto), el control de capas y los controles de `DT` a cada ancho de pantalla, con `scrollX` en todas las tablas. |
| **JS mínimo** (`inst/app/www/custom.js`) | Cierra el menú lateral al navegar en pantallas estrechas, y recolorea el mapa del Observatorio (ver abajo). |
| **Mapas base sin clave de API** | OpenStreetMap como capa base por defecto (Positron/DarkMatter de CartoDB exigen ahora API key). |

### Observatorio: cómo carga ~8.200 polígonos

| Técnica | Detalle |
|---|---|
| **Dos niveles de detalle** | La vista nacional usa la geometría simplificada a ~1,5 km (a zoom 5-6 un píxel ya son ~2 km): ~90.000 vértices en vez de ~260.000. Al elegir una provincia se usa la de ~250 m. |
| **Canvas en vez de SVG** | `leafletOptions(preferCanvas = TRUE)`: miles de polígonos en SVG son muy lentos de dibujar. |
| **JSON de geometría generado a mano** | `addPolygons()` + `jsonlite` tarda ~6 s en convertir los polígonos al JSON de Leaflet, porque construye cientos de miles de listas anidadas. `geometria_a_json_leaflet()` genera el mismo JSON directamente desde `st_coordinates()` con operaciones vectorizadas, en ~1,4 s. Se marca con clase `json` para que shiny y htmlwidgets lo inserten sin volver a serializarlo. Un test comprueba que es idéntico al de Leaflet. |
| **Caché por proceso** | `cargar_observatorio()` lee el parquet y lo convierte a `sf` una sola vez por proceso (en shinyapps.io un proceso atiende muchas sesiones), y la geometría serializada se cachea por ámbito dentro de ese objeto. |
| **Los polígonos van con el mapa** | El primer render del mapa ya incluye los polígonos, sin esperar a que el navegador avise de que el mapa existe. Los cambios de ámbito posteriores van por `leafletProxy`: volver a renderizar el widget lo destruiría con un redibujado de canvas pendiente y Leaflet daría un error (`clearRect`). |
| **Recolorear en el navegador** | Cambiar de indicador no cambia la forma de los municipios. Un manejador JS (`observatorio_recolorear` en `custom.js`) busca cada polígono por su código INE y cambia su color y su etiqueta: ~200 KB en vez de reenviar toda la geometría. El resaltado de Leaflet solo restaura el borde en `mouseout`, así que el nuevo relleno se mantiene. |
| **El mapa primero, el resto después** | Shiny envía juntas todas las salidas de un ciclo y no pinta ninguna hasta cargar las librerías de todas; la primera vez eso incluye `plotly.js` (~3,5 MB). El gráfico y el ranking esperan a `input$mapa_pintado`, que el navegador envía (`htmlwidgets::onRender` + dos `requestAnimationFrame`) cuando el mapa ya está en pantalla. |
| **Clics del gráfico sin `event_data()`** | Se lee directamente el input `plotly_click-<source>`: `event_data()` emitía en cada sesión un aviso diferido de "evento no registrado" que no se puede silenciar. |

Resultado medido en local con Chromium: el mapa nacional aparece a ~1,2 s de abrir la pestaña (antes ~3,2 s), y a ~2,6 s la primera vez tras arrancar el servidor (antes ~9,8 s).

[⬆ Volver arriba](#top)

---

<a id="instalacion"></a>
## 7. Instalación y ejecución

### Requisitos

- **R** ≥ 4.1 (recomendado 4.3 o superior).
- RStudio es opcional; todo se puede hacer desde la terminal.
- Conexión a internet para instalar las dependencias la primera vez.

Dependencias principales (`Imports` en `DESCRIPTION`):

| Paquete | Uso |
|---|---|
| [`golem`](https://cran.r-project.org/package=golem) | Estructura de la app como paquete de R |
| [`shiny`](https://cran.r-project.org/package=shiny) / [`shinydashboard`](https://cran.r-project.org/package=shinydashboard) | Motor reactivo y layout del dashboard |
| [`arrow`](https://cran.r-project.org/package=arrow) | Lectura de los ficheros Parquet |
| [`leaflet`](https://cran.r-project.org/package=leaflet) / [`leaflet.extras`](https://cran.r-project.org/package=leaflet.extras) | Mapas y capa de calor |
| [`DT`](https://cran.r-project.org/package=DT) | Tablas interactivas |
| [`plotly`](https://cran.r-project.org/package=plotly) | Gráficos interactivos |
| [`sf`](https://cran.r-project.org/package=sf) | Geometría municipal del Observatorio |
| [`htmlwidgets`](https://cran.r-project.org/package=htmlwidgets) | Aviso del navegador cuando el mapa del Observatorio ya está pintado (`onRender`) |
| [`jsonlite`](https://cran.r-project.org/package=jsonlite) | Lectura de los clics del gráfico del Observatorio |

### Puesta en marcha

```bash
git clone https://github.com/pdawgabriel-hub/geo-alquiler.git
cd geo-alquiler
Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")'   # si no tienes renv
Rscript -e 'renv::restore()'      # instala las versiones exactas de renv.lock
Rscript app.R                     # lanza la app
```

Desde RStudio es lo mismo: abre `geo-alquiler.Rproj` (activa `renv` mediante `.Rprofile`), acepta restaurar el entorno y pulsa **Run App** sobre `app.R`.

La app abre el navegador en `http://127.0.0.1:<puerto>` con el Panel Principal. No necesita descargar nada: los datos ya generados viajan en `inst/app/data/`.

### Otras formas de lanzarla

```bash
Rscript -e 'pkgload::load_all(); run_app()'      # modo desarrollo
Rscript -e 'library(GeoAlquiler); run_app()'     # si la has instalado con devtools::install()
```

En un servidor sin entorno gráfico, desactiva la apertura del navegador y fija host y puerto:

```bash
Rscript -e 'pkgload::load_all(); options(shiny.launch.browser = FALSE); shiny::runApp(run_app(), host = "0.0.0.0", port = 3838)'
```

### `NAMESPACE`

`NAMESPACE` está versionado en el repositorio, así que no hace falta generarlo para ejecutar la app. Solo hay que regenerarlo si cambias las etiquetas `#' @import` / `#' @importFrom` de `R/`:

```bash
Rscript -e 'roxygen2::roxygenise()'
```

### Equivalencias RStudio ↔ terminal

| Acción | En RStudio | En la terminal |
|---|---|---|
| Restaurar dependencias | Se ofrece al abrir el `.Rproj` | `Rscript -e 'renv::restore()'` |
| Regenerar `NAMESPACE` | `Ctrl/Cmd + Shift + D` | `Rscript -e 'roxygen2::roxygenise()'` |
| Cargar el paquete | `Ctrl/Cmd + Shift + L` | `Rscript -e 'pkgload::load_all()'` |
| Lanzar la app | Botón "Run App" | `Rscript app.R` |
| Ejecutar tests | `Ctrl/Cmd + Shift + T` | `Rscript -e 'testthat::test_dir("tests/testthat")'` |
| Check completo | `Ctrl/Cmd + Shift + E` | `R CMD build . && R CMD check --no-manual GeoAlquiler_*.tar.gz` |

### Si `renv` no encuentra los paquetes

`renv` asocia la librería de paquetes a la ruta del proyecto. Si mueves o renombras la carpeta, al arrancar verás `One or more packages recorded in the lockfile are not installed` y errores como `there is no package called 'testthat'`. Se resuelve con:

```bash
Rscript -e 'renv::restore()'
```

Los paquetes que ya están en la caché de `renv` se enlazan desde ahí, sin descargar ni compilar. Comprueba el resultado con `Rscript -e 'renv::status()'`, que debe decir "No issues found".

> Si trabajas con una copia del proyecto anterior a octubre de 2026 y `renv::restore()` falla con `[NULL]: failed to download` o con paquetes en `dependency failed`, actualiza `renv.lock` y `renv/activate.R` desde el repositorio: eran dos problemas del lockfile y de `renv` 1.2.3, ya corregidos (ver [sección 9](#ci)).

[⬆ Volver arriba](#top)

---

<a id="tests"></a>
## 8. Tests

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'                       # todos
Rscript -e 'testthat::test_file("tests/testthat/test_observatorio.R")'   # uno concreto
```

Hay **29 tests** (`test_that()`) con **102 comprobaciones** (`expect_*()`):

| Fichero | Tests | Comprobaciones | Qué cubre |
|---|---|---|---|
| `test_calculos.R` | 12 | 52 | Las funciones de `fct_calculos.R`: KPIs (también con un conjunto vacío); validación del encuadre del mapa; cuota hipotecaria y proyección año a año; oportunidades frente a la media de su ciudad; distancia del recomendador KNN, con y sin coordenadas; fórmula de predicción con una sola ciudad. Más un `testServer` de la Calculadora |
| `test_observatorio.R` | 15 | 47 | Indicadores derivados y datos ausentes; formato numérico español; cortes por cuantiles; reconstrucción de la geometría; normalización y cruce exacto y aproximado de nombres de municipio; motivo de cada dato ausente; parseo de las tablas del Catastro; JSON de geometría idéntico al de Leaflet; caché por ámbito; y el módulo completo con `testServer` |
| `test_mod_tabla.R`, `test_tabla.R` | 2 | 3 | Módulo de tabla: marcar y desmarcar favoritos (`testServer`) |

### Cómo están organizados

Los tests cargan el código que prueban con `source()`, en vez de instalar el paquete:

```r
source("../../R/fct_calculos.R")
source("../../R/mod_calculadora.R")
```

`testthat::test_dir()` ejecuta cada fichero con `tests/testthat/` como directorio de trabajo, de ahí la ruta `../../R/`. Esto tiene dos ventajas: los tests corren en segundos sin construir el paquete, y cada fichero declara exactamente qué código usa. A cambio, si el código usa funciones de otros paquetes sin prefijo (por ejemplo `renderValueBox` de `shinydashboard`), el test tiene que cargarlos con `library()`.

Hay tres tipos de test, de más simple a más completo:

**1. Funciones puras con valores de referencia.** La mayoría. Se comprueba el resultado contra un valor calculado a mano o conocido, nunca recalculándolo con la misma fórmula dentro del test (eso solo comprobaría que la fórmula es igual a sí misma):

```r
test_that("cuota_hipoteca aplica el sistema francés", {
  # Valor de referencia: 200.000 € a 30 años al 3 % -> 843,21 €/mes
  expect_equal(round(cuota_hipoteca(200000, 0.03, 30), 2), 843.21)
  # Sin interés, la cuota es el capital entre el número de meses
  expect_equal(cuota_hipoteca(120000, 0, 10), 1000)
})
```

**2. Tests de regresión: casos que ya fallaron una vez.** Cuando se arregla un fallo, se añade un test con el caso exacto que lo provocaba, para que no vuelva. Por ejemplo, un encuadre del mapa sin área (que Leaflet reporta un instante al redimensionar) vaciaba siete pantallas:

```r
degenerado <- list(north = 40.5, south = 40.5, east = -3.6, west = -3.6)
expect_equal(nrow(filtrar_por_encuadre(df, degenerado)), nrow(df))
```

Otro del mismo tipo: la predicción con una sola ciudad, con la que `lm()` fallaba por tener un factor de un solo nivel.

**3. Módulos con `testServer()`.** Ejecuta el servidor de un módulo sin navegador: se simulan inputs con `session$setInputs()` y se inspeccionan sus `reactive` internos directamente por su nombre:

```r
test_that("La calculadora pasa los porcentajes de los inputs a tanto por uno", {
  testServer(calculadoraServer, {
    session$setInputs(precio_compra = 200000, alquiler_mensual = 1000, gastos_mantenimiento = 1200,
                      porcentaje_entrada = 20, interes_hipoteca = 3, plazo_anos = "25",
                      incremento_alquiler = 2, apreciacion_inmueble = 1)
    expect_equal(simulacion(), simular_inversion(200000, 1000, 1200, 0.2, 0.03, 25, 0.02, 0.01))
  })
})
```

Este test no repite la lógica financiera (ya la prueba el tipo 1): solo comprueba el **cableado**, que es justo lo que puede romperse en el módulo, por ejemplo olvidar dividir entre 100.

### Datos de prueba

Los tests no leen los Parquet reales: construyen pequeños `data.frame` con valores elegidos para que el resultado esperado sea fácil de calcular a mano. En `test_calculos.R`, `inmuebles_mock()` tiene cinco inmuebles en dos ciudades, con precios/m² de 10, 10 y 7 en Madrid, de modo que la media es 9 y el tercero está un 22,2 % por debajo. En `test_observatorio.R`, `observatorio_mock()` reproduce el formato del Parquet del Observatorio (geometría en WKB incluida) con dos municipios.

### Refactorizar sin cambiar el comportamiento

Al mover los cálculos de los módulos a `fct_calculos.R`, antes de tocar ningún módulo se comprobó que cada función nueva daba exactamente lo mismo que el código original: se compararon contra una copia literal del código antiguo con datos reales y entradas aleatorias (200 simulaciones de la Calculadora, siete umbrales de oportunidades, 20 inmuebles del recomendador y los KPIs con datos completos, vacíos y de una sola ciudad). Es la forma segura de reorganizar código que no tenía tests: primero fijar su comportamiento actual y luego moverlo.

### Escribir un test nuevo

1. Si el cálculo está dentro de un módulo, sácalo a una función en `R/fct_*.R` y haz que el módulo la llame.
2. Escribe en `tests/testthat/test_*.R` un `test_that("frase que describe el comportamiento", { ... })` con datos pequeños y resultados calculados a mano. Prueba también el caso vacío y los extremos.
3. Si arreglas un fallo, añade el caso exacto que lo provocaba.
4. Ejecuta `Rscript -e 'testthat::test_dir("tests/testthat")'`. Al hacer push, GitHub ejecutará los mismos tests (ver [sección 9](#ci)).

Para una validación completa del paquete (tests, `DESCRIPTION`, documentación y estructura):

```bash
R CMD build .
R CMD check --no-manual GeoAlquiler_*.tar.gz
```

[⬆ Volver arriba](#top)

---

<a id="ci"></a>
## 9. Integración continua

`.github/workflows/ci.yml` ejecuta los tests en GitHub en cada push y en cada pull request. El resultado aparece en la insignia **Tests** del README, junto a cada commit y en la pestaña [*Actions*](https://github.com/pdawgabriel-hub/geo-alquiler/actions) del repositorio.

### Qué hace el workflow

Tiene dos jobs. **Tests** se ejecuta siempre:

| Paso | Qué hace y por qué |
|---|---|
| `actions/checkout@v5` | Descarga el código del commit. |
| Instalar librerías del sistema | `apt-get install` de GDAL, GEOS, PROJ, udunits, SQLite, libcurl, OpenSSL y libxml2: las librerías de C que necesitan `sf`, `terra`, `arrow` y `curl`. |
| `r-lib/actions/setup-r@v2` | Instala **R 4.3.3**, la misma versión que `renv.lock`. Con `use-public-rspm: true` usa paquetes **precompilados** de Posit Package Manager para Ubuntu 24.04: sin eso habría que compilar `arrow`, `sf` o `terra` desde el código fuente, y cada ejecución tardaría mucho más. |
| `r-lib/actions/setup-renv@v2` | Ejecuta `renv::restore()` para instalar las versiones exactas del lockfile, y guarda la librería en caché: si `renv.lock` no cambia, la siguiente ejecución la reutiliza. |
| Ejecutar tests | `testthat::test_dir("tests/testthat", stop_on_failure = TRUE)`: si falla una comprobación, el proceso termina con error y el commit queda en rojo. |

Una ejecución completa tarda unos 2 minutos.

**Despliegue** solo se ejecuta en un push a `main` y solo si **Tests** ha pasado (`needs: tests`). Antes de nada comprueba si existen los secretos del repositorio:

```yaml
- name: Comprobar credenciales
  id: credenciales
  env:
    SHINYAPPS_TOKEN: ${{ secrets.SHINYAPPS_TOKEN }}
    SHINYAPPS_SECRET: ${{ secrets.SHINYAPPS_SECRET }}
  run: |
    if [ -n "$SHINYAPPS_TOKEN" ] && [ -n "$SHINYAPPS_SECRET" ]; then
      echo "disponibles=true" >> "$GITHUB_OUTPUT"
    else
      echo "::notice::Sin secretos SHINYAPPS_TOKEN/SHINYAPPS_SECRET: se omite el despliegue."
    fi
```

El resto de pasos llevan `if: steps.credenciales.outputs.disponibles == 'true'`. Este rodeo es necesario porque GitHub no permite usar `secrets` directamente en un `if`. Sin secretos, el job termina en verde sin desplegar nada; con ellos, configura la cuenta con `rsconnect::setAccountInfo()` y ejecuta `scripts/deploy.R`. `concurrency` impide que dos push seguidos lancen dos despliegues a la vez.

### Leer un fallo

En *Actions*, entra en la ejecución con la cruz roja, después en el job y despliega el paso marcado en rojo:

- **Falla "Ejecutar tests"**: el final del log indica qué `test_that` ha fallado, en qué línea y qué valor esperaba frente al obtenido. Reprodúcelo en local con `testthat::test_file()` sobre ese fichero.
- **Falla `setup-renv`**: no se ha podido instalar algún paquete. El resumen final (`The following package(s) were not installed successfully`) lista cada paquete con su motivo; el que importa es el que no dice `dependency failed`, porque los demás caen en cadena.

### Reproducir el CI en local

En tu ordenador, `renv` reutiliza su caché y no ve los problemas que aparecen al instalar desde cero. Para repetir en local lo que hace GitHub, restaura sobre una librería vacía, fuera del proyecto, sin caché y con los mismos binarios:

```bash
RENV_PATHS_LIBRARY=/tmp/libreria-ci \
RENV_CONFIG_CACHE_ENABLED=FALSE \
RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest" \
Rscript -e 'renv::restore(prompt = FALSE)'

RENV_PATHS_LIBRARY=/tmp/libreria-ci Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
```

Es fiel si tu sistema es Ubuntu 24.04 con R 4.3.3, como el de GitHub. La librería tiene que estar fuera de la carpeta del proyecto: si está dentro, `renv` lee también el código de los paquetes instalados al buscar dependencias y da avisos falsos.

### Dos problemas que aparecieron al montarlo

Ninguno se veía en local, porque los paquetes salían de la caché de `renv`. Los dos rompían la instalación desde cero, que es lo que hace GitHub en cada ejecución nueva.

1. **Entradas `null` en `renv.lock`.** Nueve paquetes (`rstudioapi`, `rsconnect`, `httr2`…) tenían un `null` en su lista de dependencias. `renv` lo interpretaba como un paquete por descargar (`[NULL]: failed to download`) y, al fallar, deshacía toda la instalación. Se corrigió quitando esas entradas del lockfile, sin cambiar ninguna versión.
2. **Bug de `renv` 1.2.3 con `curl`.** Al instalar desde cero, `renv` 1.2.3 asignaba a `curl` las dependencias del propio proyecto (las de su `DESCRIPTION`). Como `plotly` depende de `curl` a través de `httr`, se formaba un ciclo y `renv` dejaba sin instalar `curl`, `httr`, `httr2`, `plotly`, `rsconnect` y `snowflakeauth`: todos aparecían como `dependency failed` sin ningún error real. Se localizó interceptando la función interna que genera ese mensaje para ver qué dependencias había calculado para cada paquete, y se corrigió actualizando a `renv` 1.3.0 (`renv::upgrade()`), que no tiene el fallo.

La lección para el futuro: **antes de dar por bueno un cambio en `renv.lock`, prueba una restauración desde cero** con el comando de arriba.

[⬆ Volver arriba](#top)

---

<a id="despliegue"></a>
## 10. Despliegue

La app está desplegada en shinyapps.io: **[pdawgabriel-hub.shinyapps.io/geoalquiler](https://pdawgabriel-hub.shinyapps.io/geoalquiler/)**. Se despliega de dos formas:

- **A mano**: `Rscript scripts/deploy.R`, que sube los ficheros que haya en tu disco.
- **Automática**: el job `despliegue` de `.github/workflows/ci.yml` ejecuta ese mismo script después de cada push a `main`, solo si los tests pasan (ver [sección 9](#ci)). Necesita dos secretos en el repositorio (*Settings > Secrets and variables > Actions*): `SHINYAPPS_TOKEN` y `SHINYAPPS_SECRET`, que se obtienen en shinyapps.io en *Account > Tokens*. Sin ellos el job termina en verde sin desplegar nada.

Lecciones de los despliegues:

- **`scripts/deploy.R` enumera a mano los ficheros que se suben.** Incluye los dos Parquet de `inst/app/data/`. Si añades otro fichero de datos, añádelo también ahí o no llegará al servidor.
- **`shiny.autoload.r`**: en shinyapps.io/Posit Connect, una carpeta `R/` junto a `app.R` hace que Shiny la cargue como "ficheros de apoyo" **antes** de ejecutar `app.R`. Por eso `.Rprofile` fija `options(shiny.autoload.r = FALSE)`. Si reaparece `Error in box: plot.new has not been called yet`, esa opción no se está aplicando a tiempo.
- **`terra`**: la versión más reciente de CRAN puede no compilar en shinyapps.io por una API de GDAL más nueva que la del servidor (error con `GDALMDArray::AsClassicDataset`). Fija una versión anterior: `renv::install("terra@1.8-42")` y `renv::record("terra@1.8-42")`, siempre por encima de la mínima que exige `{raster}` (`>= 1.8.5`).
- Ejecuta `renv::snapshot()` (o `renv::record()` para un paquete concreto) antes de desplegar, para que `renv.lock` refleje lo que necesita el servidor.
- Regenera los datos antes de cada despliegue si las fuentes se han actualizado (Bilbao publica cada trimestre).

[⬆ Volver arriba](#top)

---

<a id="donde-tocar"></a>
## 11. Dónde tocar para…

| Quiero… | Cambiar | No hace falta tocar |
|---|---|---|
| Añadir o actualizar una ciudad | `scripts/ingesta/00_config.R` (y `data/raw/anclas_manuales.csv` si no hay fuente oficial); regenerar los datos | La app |
| Añadir un indicador al Observatorio | La columna en `09_observatorio.R` si viene de una fuente nueva; `calcular_indicadores_observatorio()`, `indicadores_observatorio()` y `motivo_sin_dato()` en `R/fct_observatorio.R` | El módulo: selector, leyenda, ficha y ranking salen del catálogo |
| Cambiar el año del Observatorio | `ANIO_OBSERVATORIO` en `00_config.R`, y la URL de SERPAVI en `09_observatorio.R` si el Ministerio publica una capa nueva | La app |
| Corregir el cruce de un municipio del Catastro | `EQUIVALENCIAS_CATASTRO` en `09_observatorio.R` | — |
| Añadir una pantalla nueva | Un `R/mod_nuevo.R`; registrarlo en `app_ui.R` (menú + `tabItem`) y en `app_server.R`, decidiendo qué dataset recibe | El resto de módulos |
| Cambiar un cálculo de negocio | La función en `R/fct_calculos.R` (o `fct_observatorio.R`) y su test en `tests/testthat/` | El módulo, que solo llama a la función |
| Añadir un fichero de datos a la app | `inst/app/data/` y la lista de `scripts/deploy.R` | — |

[⬆ Volver arriba](#top)
