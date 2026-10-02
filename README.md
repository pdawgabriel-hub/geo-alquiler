<a id="top"></a>
# GeoAlquiler

**Español** | [English](./README.en.md)

### Inteligencia Inmobiliaria y Análisis Espacial del Mercado de Alquiler

![R](https://img.shields.io/badge/R-4.x-276DC3?logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-App-blue?logo=rstudio&logoColor=white)
![golem](https://img.shields.io/badge/Framework-golem-6E4A7E)
![License](https://img.shields.io/badge/Licencia-Portfolio%20%2F%20Uso%20restringido-red)
![Status](https://img.shields.io/badge/Estado-En%20desarrollo-yellow)

---

## Índice

- [Descripción General](#descripcion-general)
- [Características Principales / Módulos](#caracteristicas-principales)
  - [1. Exploración Espacial](#exploracion-espacial)
  - [2. Analítica & Machine Learning](#analitica-ml)
  - [3. Herramientas de Inversión](#herramientas-inversion)
  - [4. Observatorio del Alquiler en España](#observatorio)
- [Rendimiento y Diseño Responsive](#rendimiento-responsive)
- [Capturas de Pantalla](#capturas-pantalla)
- [Estructura del Proyecto (`{golem}`)](#estructura-proyecto)
- [Fuente de los Datos](#fuente-datos)
- [Requisitos e Instalación](#requisitos-instalacion)
- [Uso y Ejecución](#uso-ejecucion)
- [Uso desde la Terminal (sin RStudio)](#uso-terminal)
- [Testing & Calidad](#testing-calidad)
- [Despliegue](#despliegue)
- [Licencia](#licencia)
- [Autor](#autor)

---

<a id="descripcion-general"></a>
## Descripción General

**GeoAlquiler** es una aplicación web analítica construida en **R** con **Shiny**, diseñada para transformar datos crudos de anuncios de alquiler inmobiliario en **inteligencia de mercado accionable**. El proyecto combina geolocalización, ciencia de datos y herramientas de decisión financiera en un único panel interactivo, permitiendo a un usuario (inversor, analista o particular) responder preguntas como:

- ¿Dónde están las zonas con mejor relación precio/m² de una ciudad?
- ¿Cuál sería el precio "justo" de mercado para un inmueble con unas características determinadas?
- ¿Qué inmuebles del dataset destacan como oportunidades de inversión frente al resto del mercado?
- ¿Cuál sería la rentabilidad y el cash flow estimado si compro un inmueble concreto para alquilarlo?
- ¿En qué municipios de España se va una parte mayor de la renta de los hogares en pagar el alquiler?

Para lograrlo, GeoAlquiler se apoya en tres pilares, más un observatorio a escala nacional:

1. **Exploración Espacial** — visualizar y filtrar el parque de inmuebles sobre un mapa interactivo.
2. **Analítica & Machine Learning** — extraer patrones, generar predicciones de precio y recomendar inmuebles similares.
3. **Herramientas de Inversión** — traducir los datos en decisiones concretas de compra/alquiler mediante calculadoras y comparativas.
4. **Observatorio del Alquiler en España** — mapa coroplético de los ~8.200 municipios que cruza el índice oficial de alquiler del Ministerio de Vivienda (SERPAVI) con la renta y la población del INE y el parque residencial del Catastro.

El proyecto está pensado como pieza de **portfolio técnico**, demostrando dominio de arquitectura de aplicaciones Shiny a nivel de paquete de R (framework `{golem}`), modularización, buenas prácticas de testing y un enfoque de producto orientado a un caso de uso real (PropTech / Real Estate Analytics). Los precios por zona proceden de fuentes reales (Generalitat de Catalunya, Generalitat Valenciana, Gobierno Vasco) o, donde no existe fuente oficial, de índices publicados documentados a mano (ver `scripts/ingesta/`).

[⬆ Volver arriba](#top)

---

<a id="caracteristicas-principales"></a>
## Características Principales / Módulos

La aplicación está organizada en tres bloques funcionales, reflejados directamente en la navegación de la interfaz (`sidebarMenu`), más el Observatorio del Alquiler (entrada propia en el menú, justo debajo del Panel Principal) y una sección informativa:

<a id="exploracion-espacial"></a>
### 1. Exploración Espacial

| Módulo | Descripción |
|---|---|
| **Panel Principal** | Cuadro de mando (KPIs) con precio medio, superficie media, precio por m² y total de inmuebles disponibles según los filtros activos. |
| **Mapa Interactivo** (`mod_mapa`) | Mapa basado en `leaflet`/`leaflet.extras` con geolocalización de cada inmueble y una **capa de calor (heatmap)** que revela visualmente la concentración de precios y oferta por zona. |
| **Panel de Filtros Globales** (`mod_filtros`) | Barra de filtros horizontal y colapsable (ciudad, tipología, rango de precio, superficie, habitaciones, etc.) que alimenta de forma reactiva a **todos** los módulos de la aplicación. |
| **Explorador de Datos** (`mod_tabla`) | Tabla interactiva (`DT`) de los inmuebles filtrados, con indicador visual de favoritos y exportación de resultados. |
| **Análisis por Barrios** (`mod_barrios`) | Analítica zonal: dispersión de precios, valor medio del m² y volumen de oferta desagregado por distrito/barrio dentro de cada ciudad. |
| **Mis Favoritos** (`mod_favoritos`) | Gestión de una lista de inmuebles marcados por el usuario durante la sesión, con sus propios KPIs (precio medio de favoritos, total guardado, etc.). |
| **Exportar Datos** (`mod_exportar`) | Descarga en CSV del subconjunto de inmuebles resultante de los filtros aplicados. |

<a id="analitica-ml"></a>
### 2. Analítica & Machine Learning

| Módulo | Descripción |
|---|---|
| **Analítica Visual** (`mod_graficos`) | Visualizaciones interactivas con `plotly`: relación precio vs. superficie, distribución de precios y comparativas gráficas del mercado visible. |
| **Estadística Avanzada** (`mod_estadistica`) | Resumen estadístico del mercado filtrado: mediana, percentiles, boxplots y otras medidas de dispersión para entender la distribución real de precios (más allá de la media). |
| **Predicción ML** (`mod_prediccion`) | Modelo predictivo de precios (regresión) entrenado sobre el dataset, que estima el alquiler esperado de un inmueble a partir de ciudad, barrio, tipología, superficie y número de habitaciones introducidos por el usuario. |
| **Recomendador KNN** (`mod_recomendador`) | Sistema de recomendación basado en el algoritmo **K-Nearest Neighbors**: dado un inmueble de referencia, sugiere los inmuebles más similares del dataset según sus características. |

<a id="herramientas-inversion"></a>
### 3. Herramientas de Inversión

| Módulo | Descripción |
|---|---|
| **Comparador A/B** (`mod_comparador`) | Comparativa cara a cara entre dos ciudades, barrios o tipologías, útil para decidir entre dos mercados o segmentos alternativos. |
| **Detector de Oportunidades** (`mod_oportunidades`) | Identifica automáticamente inmuebles que se desvían favorablemente de la media de mercado (p. ej. precio por debajo del esperado para su zona/tipología), señalándolos como posibles oportunidades de inversión. |
| **Calculadora de Rentabilidad** (`mod_calculadora`) | Calculadora financiera completa: rentabilidad bruta/neta, amortización hipotecaria y proyección de cash flow a partir del precio de compra, alquiler estimado y gastos de mantenimiento. |
| **Informe Ejecutivo** (`mod_reporte`) | Generación y descarga de un informe (a partir de la plantilla `reporte_plantilla.Rmd`) con los métricos clave del mercado y los inmuebles filtrados, listo para compartir o imprimir. |

<a id="observatorio"></a>
### 4. Observatorio del Alquiler en España

| Módulo | Descripción |
|---|---|
| **Observatorio España** (`mod_observatorio`) | Mapa coroplético municipal de toda España (o de una provincia) con 8 indicadores seleccionables, KPIs del ámbito, ficha de cada municipio con su percentil nacional en cada indicador, gráfico de burbujas renta vs. alquiler €/m² (tamaño = población, color = esfuerzo) y ranking de municipios. Se puede seleccionar un municipio desde el mapa, el gráfico o el ranking, y las tres vistas se sincronizan. |

A diferencia del resto de la app (que trabaja con anuncios ilustrativos de 5 ciudades), el observatorio usa **solo datos agregados oficiales**, cruzados por código INE de municipio y **todos referidos al mismo año (2022)**, para que los ratios entre fuentes comparen el mismo ejercicio:

| Indicador | Fuente | Cálculo |
|---|---|---|
| Alquiler mediano (€/m² y €/mes) | SERPAVI — Ministerio de Vivienda y Agenda Urbana | Mediana de los contratos de alquiler declarados en el IRPF. Se usa la de vivienda colectiva (pisos); donde SERPAVI solo la publica para unifamiliares (749 municipios, p. ej. Torrent), se usa esa y la ficha lo indica |
| Esfuerzo de alquiler (% renta) | SERPAVI + INE | 12 × alquiler mensual mediano / renta neta media por hogar |
| Renta neta media por hogar | INE — Atlas de Distribución de Renta de los Hogares | Dato directo |
| Viviendas en alquiler (% del parque) | SERPAVI + Catastro | Viviendas con alquiler declarado / inmuebles de uso residencial |
| Valor catastral medio por inmueble residencial | Catastro — estadística del Catastro Inmobiliario Urbano | Valor catastral residencial / nº de inmuebles residenciales |
| Población y crecimiento de población | INE — Padrón municipal | Población 2022 y variación 2022 → último año publicado |

Limitaciones que la propia app indica:

- **País Vasco y Navarra** no aparecen en SERPAVI ni en el Catastro estatal (tienen Hacienda y Catastro forales), así que sus municipios solo tienen renta y población.
- SERPAVI publica la mediana solo en los municipios con suficientes contratos declarados (2.966 de 8.131, contando los 749 con dato solo de unifamiliares), que concentran el 90 % de la población. El resto se pinta en gris ("Sin dato").
- Cuando falta un dato, la ficha del municipio explica el motivo (pocos contratos declarados, secreto estadístico del INE en municipios muy pequeños, régimen foral...) en vez de mostrar solo "s/d".
- Los 86 polígonos con código 53xxx/54xxx no son municipios sino territorios compartidos entre varios (parzonerías, comunidades de montes). Se pintan en gris y su ficha lo indica.
- "Viviendas en alquiler" cuenta **alquileres declarados** a Hacienda, así que es una cota inferior del peso real del alquiler.
- El Catastro no publica el código INE en sus tablas municipales: se cruza por nombre normalizado dentro de cada provincia y, para lo que queda, por nombre aproximado (renombramientos y nombres en otro idioma, p. ej. Castrillo Matajudíos → Castrillo Mota de Judíos o Santa Eulalia del Río → Santa Eulària des Riu). Dos renombramientos completos que no se pueden deducir con seguridad están en una tabla de equivalencias explícita (`EQUIVALENCIAS_CATASTRO`). Se cruzan los 7.612 nombres del Catastro; el pipeline lista en su salida los cruces aproximados para poder revisarlos.

[⬆ Volver arriba](#top)

---

<a id="rendimiento-responsive"></a>
## Rendimiento y Diseño Responsive

GeoAlquiler está pensado para usarse tanto en escritorio como en el móvil, no solo para adaptarse visualmente sino para cargar rápido con conexiones más lentas. Esto se traduce en decisiones concretas de arquitectura, no solo en CSS:

| Optimización | Qué resuelve |
|---|---|
| **Gráficos con `plotly` nativo (no `ggplotly()`)** | Los 10 gráficos interactivos de la app se construyen directamente con `plot_ly()`/`add_trace()` en vez de convertir un `ggplot2` con `ggplotly()`, que genera un payload JSON notablemente más pesado para el mismo gráfico. |
| **Histogramas pre-agregados en el servidor** | Los histogramas calculan los bins en R con `hist()` y envían solo las barras ya agregadas, en vez de mandar cada precio en crudo al navegador para que los calcule `type = "histogram"` de Plotly. |
| **Submuestreo transparente en gráficos densos** | El scatter de precio/superficie y los boxplots de Estadística Avanzada limitan cuántos puntos viajan al navegador (con una muestra aleatoria y un aviso visible de cuántos se están representando) cuando el conjunto filtrado es muy grande. |
| **Mapa agregado por barrio en servidor** | La capa por defecto del mapa no manda cada inmueble individual, sino un resumen por barrio (precio medio + nº de inmuebles) calculado en R — una reducción de miles de puntos a un par de cientos. Los pines individuales y el mapa de calor se cargan bajo demanda (`leafletProxy`) solo si el usuario activa esa capa. |
| **Clustering en mapas con muchos marcadores** | El mapa de Oportunidades agrupa (`markerClusterOptions`) los marcadores en vez de pintarlos todos sueltos, evitando que un umbral poco restrictivo (cientos de resultados) sature el navegador. |
| **CSS responsive propio** (`inst/app/www/custom.css`) | Ajusta a distintos anchos de pantalla las alturas de los widgets de Leaflet/Plotly (fijas en píxeles por defecto), el control de capas del mapa y los controles de `DT`, con `scrollX` activado en todas las tablas para que las columnas que no caben se puedan desplazar en vez de quedar cortadas. |
| **JS mínimo para UX móvil** (`inst/app/www/custom.js`) | El sidebar de `shinydashboard` se cierra automáticamente al navegar a una pestaña en pantallas estrechas, en vez de quedarse superpuesto tapando el contenido. |
| **Dos niveles de detalle en la geometría del Observatorio** | El pipeline guarda los polígonos municipales simplificados a dos tolerancias: ~1,5 km para la vista de toda España (a zoom 5-6 un píxel ya son ~2 km) y ~250 m para cuando se filtra una provincia. La vista nacional pasa de ~260.000 a ~90.000 vértices. |
| **Recolorear en el navegador en vez de reenviar polígonos** | Al cambiar de indicador en el Observatorio solo cambian el color y la etiqueta de cada municipio, no su forma. Un pequeño manejador JS (`custom.js`) recolorea los polígonos ya pintados a partir de su código INE, así que el cambio envía ~200 KB en vez de volver a mandar los ~8.000 polígonos. |
| **Geometría serializada a mano y cacheada por proceso** | El camino estándar (`addPolygons()` + `jsonlite`) tarda ~6 s en convertir los ~8.000 polígonos al JSON de Leaflet, porque construye cientos de miles de listas anidadas. `geometria_a_json_leaflet()` genera el mismo JSON (hay un test que lo compara con el de Leaflet) directamente desde las coordenadas con operaciones vectorizadas, en ~1,4 s. El resultado se cachea por ámbito (España / cada provincia), y el parquet se lee y se convierte a `sf` una sola vez por proceso, no en cada sesión. El mapa usa el renderizador canvas de Leaflet (`preferCanvas`), mucho más ligero que SVG con miles de polígonos. |
| **El mapa primero, el resto después** | Los polígonos viajan dentro del propio render del mapa, sin esperar a que el navegador avise de que existe. Además, el gráfico y el ranking esperan a que el navegador confirme que el mapa ya está pintado: Shiny envía juntas todas las salidas de un ciclo y no pinta ninguna hasta cargar las librerías de todas, y la primera vez eso incluye `plotly.js` (~3,5 MB). En local, el mapa nacional aparece a los ~1,2 s de abrir la pestaña (antes ~3,2 s), y a los ~2,6 s la primera vez tras arrancar el servidor (antes ~9,8 s). |
| **Mapas base sin clave de API** | Usa OpenStreetMap como capa base por defecto (los mapas Positron/DarkMatter de CartoDB ahora exigen API key en su plan gratuito). |

[⬆ Volver arriba](#top)

---

<a id="capturas-pantalla"></a>
## Capturas de Pantalla

A continuación se muestran las pantallas principales de la aplicación, organizadas por los mismos bloques funcionales que la navegación.

### Exploración Espacial

| Panel Principal |
|---|
| ![Panel Principal](man/figures/panel-principal.png) |

| Explorador de Datos | Análisis por Barrios |
|---|---|
| ![Explorador de Datos](man/figures/explorador-datos.png) | ![Análisis por Barrios](man/figures/analisis-barrios.png) |

### Analítica & Machine Learning

| Analítica Visual | Predicción ML |
|---|---|
| ![Analítica Visual](man/figures/analitica-visual.png) | ![Predicción ML](man/figures/prediccion-ml.png) |

| Recomendador KNN | Estadística Avanzada |
|---|---|
| ![Recomendador KNN](man/figures/recomendador-knn.png) | ![Estadística Avanzada](man/figures/estadistica-avanzada.png) |

### Herramientas de Inversión

| Comparador A/B | Detector de Oportunidades |
|---|---|
| ![Comparador A/B](man/figures/comparador-ab.png) | ![Detector de Oportunidades](man/figures/detector-oportunidades.png) |

| Calculadora de Rentabilidad | Informe Ejecutivo |
|---|---|
| ![Calculadora de Rentabilidad](man/figures/calculadora-rentabilidad.png) | ![Informe Ejecutivo](man/figures/informe-ejecutivo.png) |

### Observatorio del Alquiler en España

| Observatorio (alquiler €/m² por municipio, ficha de Madrid) |
|---|
| ![Observatorio del Alquiler en España](man/figures/observatorio-alquiler.png) |

---

<a id="estructura-proyecto"></a>
## Estructura del Proyecto (`{golem}`)

GeoAlquiler **no es una simple app de Shiny en un único `app.R`**, sino un **paquete de R** construido con el framework **[`{golem}`](https://thinkr-open.github.io/golem/)**. Este enfoque aporta las ventajas propias de un paquete (documentación con `roxygen2`, gestión formal de dependencias vía `DESCRIPTION`, testing con `testthat`, y un ciclo de vida claro de desarrollo → build → despliegue), aplicadas a una aplicación Shiny de tamaño y complejidad reales.

```
geo-alquiler/
├── DESCRIPTION            # Metadatos del paquete y dependencias (Imports)
├── app.R                  # Lanzador estandarizado (pkgload::load_all + run_app())
├── R/                     # Código fuente del paquete (namespace de la app)
│   ├── run_app.R          # Punto de entrada: shinyApp(ui = app_ui, server = app_server)
│   ├── app_ui.R            # UI global: dashboardPage, sidebarMenu y tabItems
│   ├── app_server.R        # Server global: orquesta la lógica reactiva y llama a cada módulo
│   ├── mod_mapa.R           # Módulo: mapa interactivo + heatmap
│   ├── mod_filtros.R        # Módulo: filtros globales reactivos
│   ├── mod_tabla.R          # Módulo: explorador de datos (DT)
│   ├── mod_barrios.R        # Módulo: analítica por barrios
│   ├── mod_favoritos.R      # Módulo: gestión de favoritos
│   ├── mod_exportar.R       # Módulo: exportación a CSV
│   ├── mod_graficos.R       # Módulo: analítica visual (plotly)
│   ├── mod_estadistica.R    # Módulo: estadística avanzada
│   ├── mod_prediccion.R     # Módulo: predicción de precios (ML)
│   ├── mod_recomendador.R   # Módulo: recomendador KNN
│   ├── mod_comparador.R     # Módulo: comparador A/B
│   ├── mod_oportunidades.R  # Módulo: detector de oportunidades
│   ├── mod_calculadora.R    # Módulo: calculadora de rentabilidad
│   ├── mod_reporte.R        # Módulo: informe ejecutivo descargable
│   ├── mod_observatorio.R   # Módulo: Observatorio del Alquiler en España (mapa coroplético)
│   └── fct_observatorio.R   # Lógica del observatorio sin Shiny (indicadores, formato, WKB -> sf)
├── inst/
│   └── app/
│       ├── data/           # Datos empaquetados con la app (alquileres.parquet, observatorio_municipios.parquet)
│       └── www/            # CSS/JS responsive (custom.css, custom.js) -- ver "Rendimiento y Diseño Responsive"
├── man/
│   └── figures/            # Capturas de pantalla usadas en este README
├── data/
│   └── processed/          # Datos procesados en formatos .rds / .parquet
├── scripts/
│   └── ingesta/                    # Pipeline de ingesta de datos reales (sustituye a los
│       ├── 00_config.R             # generadores de datos ficticios que había antes)
│       ├── 01_utils.R               # Descarga con caché + geocodificación (Nominatim)
│       ├── 02_fuente_barcelona.R    # Fuente real: Generalitat de Catalunya (INCASÒL)
│       ├── 03_fuente_valencia.R     # Fuente real: Generalitat Valenciana (fianzas)
│       ├── 04_fuente_bilbao.R       # Fuente real: Etxebide / Gobierno Vasco (Informe EMAL)
│       ├── 05_anclas_manuales.R     # Precios documentados a mano donde no hay fuente oficial
│       ├── 06_geocodificar_zonas.R  # Lat/lon reales por zona
│       ├── 07_armonizar_precios.R   # Combina todas las fuentes en una tabla única
│       ├── 08_generar_anuncios.R    # Genera los inmuebles individuales que usa la app
│       ├── 09_observatorio.R        # Observatorio: SERPAVI + INE (renta, padrón) + Catastro por municipio
│       └── run_pipeline.R           # Orquestador: Rscript scripts/ingesta/run_pipeline.R
├── data/raw/
│   └── anclas_manuales.csv        # Precios documentados a mano (ciudades sin fuente oficial)
├── reporte_plantilla.Rmd          # Plantilla R Markdown usada por el módulo de Informe Ejecutivo
├── tests/
│   ├── testthat.R                 # Runner estándar de testthat para el paquete
│   └── testthat/
│       ├── test_calculos.R        # Tests de lógica de cálculo (precio/m², KPIs, etc.)
│       ├── test_mod_tabla.R       # Tests del módulo de tabla
│       ├── test_tabla.R           # Tests adicionales de tabla/datos
│       └── test_observatorio.R    # Tests del observatorio (indicadores, cruce de nombres, módulo)
├── renv.lock                      # Lockfile de renv (reproducibilidad de dependencias)
└── geo-alquiler.Rproj             # Proyecto de RStudio
```

### Filosofía de arquitectura

- **Separación UI/Server por módulo**: cada funcionalidad (mapa, predicción, calculadora, etc.) vive en su propio archivo `mod_*.R`, siguiendo el patrón de [Shiny Modules](https://shiny.posit.co/r/articles/improve/modules/) (`NS(id)`, función `*UI()` y función `*Server()`). Esto evita colisiones de `inputId`/`outputId` y permite que `app_ui.R` y `app_server.R` actúen como **orquestadores** en lugar de contener lógica de negocio.
- **`app_ui.R`** define exclusivamente la estructura visual: el `dashboardPage` (`{shinydashboard}`), el menú de navegación con sus cuatro bloques (Exploración, Analítica, Inversión, Información) y el `tabItems` que enlaza cada pestaña con la `UI` de su módulo correspondiente.
- **`app_server.R`** es responsable de instanciar el `server` de cada módulo, pasar el estado reactivo compartido (por ejemplo, los datos ya filtrados por `mod_filtros`) y coordinar la comunicación entre módulos cuando es necesaria (p. ej. favoritos disponibles en la tabla).
- **`run_app.R`** expone la función `run_app()`, que envuelve la `shinyApp` con `golem::with_golem_options()`, permitiendo pasar opciones de configuración (`golem_opts`) sin tocar el resto del código — el patrón estándar de cualquier app basada en `{golem}`.
- **`app.R`** en la raíz es el lanzador "universal": hace `pkgload::load_all()` para cargar el paquete en modo desarrollo y activa `golem.app.prod = TRUE`, lo que lo hace compatible tanto con `shiny::runApp()` local como con servidores de despliegue (Shiny Server, Posit Connect, shinyapps.io, contenedores Docker, etc.) sin necesidad de instalar el paquete previamente.
- **Datos como recurso empaquetado**: el dataset vive en `inst/app/data/`, lo que garantiza que viaje junto con el paquete y esté disponible tanto en desarrollo como una vez instalado/desplegado, siguiendo la convención de `{golem}` para assets de la aplicación.
- **Gestión de dependencias reproducible**: el proyecto usa `{renv}` (`renv.lock` + `.Rprofile`) para fijar versiones exactas de todos los paquetes, asegurando que el entorno de desarrollo y el de despliegue sean idénticos.

[⬆ Volver arriba](#top)

---

<a id="fuente-datos"></a>
## Fuente de los Datos

El dataset que consume la app (`inst/app/data/alquileres.parquet`) **ya no se genera con datos ficticios**: se construye con un pipeline de ingesta (`scripts/ingesta/`) que descarga y combina fuentes reales, priorizando siempre la fuente oficial más desagregada disponible para cada ciudad.

### Fuentes por ciudad

| Ciudad | Fuente real | Detalle | Fiabilidad |
|---|---|---|---|
| **Barcelona** | Generalitat de Catalunya (INCASÒL) — fianzas de lloguer depositadas | Por barrio (73 barrios) | Oficial |
| **Bilbao** | Gobierno Vasco (Etxebide) — Informe EMAL trimestral | Por barrio (€/m² ya calculado por la fuente) | Oficial |
| **Valencia** | Generalitat Valenciana — registro de fianzas de alquiler depositadas | Por código postal (barrio real resuelto vía geocodificación inversa) | Oficial |
| **Madrid, Sevilla** | Sin fuente pública con importe + geografía (verificado) | Municipio + un puñado de barrios conocidos | Ancla manual, documentada en `data/raw/anclas_manuales.csv` |

En Madrid y Sevilla no existe ningún registro público (ni estatal ni autonómico) de fianzas de alquiler con importe y desglose geográfico — se comprobó expresamente antes de recurrir a una alternativa. Para esos casos (y para cualquier zona sin fuente oficial que se quiera destacar) se usa un **ancla manual**: un precio/m² documentado a mano a partir de un índice publicado (idealista/fotocasa), con fecha, URL y nota de fiabilidad en `data/raw/anclas_manuales.csv`. Estas filas quedan siempre marcadas como estimadas (ver esquema de columnas más abajo) para no aparentar más precisión de la que realmente tienen.

### Cómo se regenera el dataset

```bash
Rscript scripts/ingesta/run_pipeline.R
```

Esto descarga (con caché en `data/raw/`, para no repetir peticiones si ya está reciente) cada fuente, la geocodifica con [Nominatim/OpenStreetMap](https://nominatim.openstreetmap.org/), combina todo en una tabla única de precio/m² por zona y genera los inmuebles individuales que ve la app, guardando el resultado en `data/processed/` e `inst/app/data/`. El pipeline está organizado en pasos numerados dentro de `scripts/ingesta/` (config → utilidades → una fuente por ciudad → anclas manuales → geocodificación → armonización → generación), pensado para poder añadir una ciudad nueva tocando solo `00_config.R` y, si hace falta, `data/raw/anclas_manuales.csv`.

Si alguna fuente cambia de formato o de URL, el script correspondiente se detiene con un error explícito indicando qué columnas ha encontrado, en vez de guardar datos mal interpretados en silencio.

### Esquema del dataset final

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | texto | Identificador único del inmueble |
| `titulo` | texto | Título descriptivo generado (tipo + zona + ciudad) |
| `ciudad` | texto | Municipio |
| `barrio` | texto | Barrio/distrito/código postal resuelto (o el nombre del municipio si no hay desglose) |
| `tipo` | texto | Piso, Apartamento, Ático, Estudio o Casa / Chalet |
| `precio` | numérico | Alquiler mensual estimado (€), derivado del €/m² real de la zona |
| `superficie` | numérico | Superficie (m²) |
| `habitaciones` / `banos` | numérico | Nº de habitaciones / baños |
| `lat` / `lon` / `lng` | numérico | Coordenadas reales (geocodificación de la zona, no aleatorias) |
| `fuente_dato` | texto | De dónde sale el precio/m² de esa zona (nombre de la fuente oficial, o del índice usado como ancla) |
| `es_estimado` | lógico | `TRUE` si la zona no tiene fuente oficial (ancla manual) — la app lo señala como tal |
| `nivel_geo` | texto | Granularidad real del dato: `barrio`, `municipio`, `zona_sin_fuente_oficial`, etc. |

Los "anuncios" individuales son una ilustración generada dentro de cada zona geolocalizada (superficie, tipología y un margen de ruido aleatorio), pero el precio de cada uno **siempre parte del precio/m² real de su zona** — nunca de un número inventado desde cero.

### Observatorio del Alquiler (SERPAVI + INE + Catastro)

El Observatorio usa un segundo fichero, `inst/app/data/observatorio_municipios.parquet` (~4,7 MB, una fila por municipio con su geometría en WKB), generado por `scripts/ingesta/09_observatorio.R`:

| Fuente | Qué se descarga | Cómo |
|---|---|---|
| **SERPAVI** (Ministerio de Vivienda y Agenda Urbana) | Capa municipal con medianas de alquiler (€/m², €/mes, superficie, nº de viviendas) y la geometría de cada municipio (IGN) | La web de SERPAVI es una calculadora con reCAPTCHA (por eso no se usa para los anuncios), pero el CDN del Ministerio publica la capa completa como shapefile (`ALQ_Municipios_2022_Web.zip`, ~43 MB) |
| **INE — ADRH** | Renta neta media por hogar y por persona | Tabla nacional 30824 (~350 MB sin comprimir, con todas las secciones censales): se descarga comprimida y se filtra en streaming a las filas de municipio del año de referencia, cacheando solo ese extracto |
| **INE — Padrón** | Población por municipio | Tabla 29005 (cifras oficiales de todos los municipios y años) |
| **Catastro** (Dirección General del Catastro) | Nº de inmuebles y valor catastral de uso residencial | Tablas JAXI municipales por provincia (`URAO`/`URBO`); no hay descarga directa del `.px`, así que se reproduce el envío del formulario "Consultar todo" y se parsea la tabla HTML |

Para regenerarlo sin volver a descargar ni geocodificar las fuentes de los anuncios:

```bash
Rscript scripts/ingesta/run_pipeline.R --solo-observatorio
```

El año de referencia común está en `ANIO_OBSERVATORIO` (`scripts/ingesta/00_config.R`). Las descargas se cachean en `data/raw/observatorio/` (no versionado, ~100 MB). Si una fuente cambia de formato, el paso correspondiente se detiene con un error que indica qué ha encontrado; un fallo del observatorio dentro del pipeline completo no invalida el dataset de anuncios ya guardado.

[⬆ Volver arriba](#top)

---

<a id="requisitos-instalacion"></a>
## Requisitos e Instalación

### Requisitos previos

- **R** ≥ 4.1 (recomendado 4.3 o superior)
- **RStudio** (recomendado, aunque no imprescindible, desarrollado en Visual Studio Code)
- Sistema operativo: Windows, macOS o Linux
- Conexión a internet para la instalación inicial de dependencias vía `{renv}`

### Dependencias principales (`Imports` en `DESCRIPTION`)

| Paquete | Uso en el proyecto |
|---|---|
| [`golem`](https://cran.r-project.org/package=golem) | Framework de estructuración de la app como paquete de R |
| [`shiny`](https://cran.r-project.org/package=shiny) | Motor reactivo y framework web de la aplicación |
| [`shinydashboard`](https://cran.r-project.org/package=shinydashboard) | Layout de dashboard (sidebar, boxes, valueBoxes) |
| [`arrow`](https://cran.r-project.org/package=arrow) | Lectura/escritura eficiente de datos en formato Parquet |
| [`leaflet`](https://cran.r-project.org/package=leaflet) / [`leaflet.extras`](https://cran.r-project.org/package=leaflet.extras) | Mapa interactivo y capa de calor (heatmap) |
| [`DT`](https://cran.r-project.org/package=DT) | Tablas de datos interactivas |
| [`plotly`](https://cran.r-project.org/package=plotly) | Gráficos interactivos de analítica visual |
| [`sf`](https://cran.r-project.org/package=sf) | Geometría municipal del Observatorio (lectura del WKB guardado en Parquet) |
| [`jsonlite`](https://cran.r-project.org/package=jsonlite) / [`htmltools`](https://cran.r-project.org/package=htmltools) | Serialización en caché de la geometría del Observatorio y etiquetas HTML |

A esto se suma `{testthat}` como dependencia de desarrollo para la suite de tests, y `{renv}` para el control de versiones de todas las dependencias. Además, necesitas `{roxygen2}` instalado para generar el archivo `NAMESPACE` del paquete (ver paso 4 de la instalación) — sin él, la aplicación **no arranca correctamente**, ya que `NAMESPACE` es lo que le indica a R qué funciones de `shiny`, `leaflet`, `DT`, etc. debe poner a disposición del código de la app.

**Solo si vas a regenerar los datos** (`Rscript scripts/ingesta/run_pipeline.R`, ver [Fuente de los Datos](#fuente-datos)) necesitas además:

| Dependencia | Uso |
|---|---|
| `{httr}` | Descarga de las fuentes (Suggests en `DESCRIPTION`) |
| `{readxl}` | Lectura del Excel de Barcelona (Suggests) |
| `{jsonlite}` | Geocodificación vía Nominatim (ya en Imports, lo usa también la app) |
| `{sf}` | Lectura y simplificación del shapefile de SERPAVI (ya en Imports) |
| `pdftotext` (paquete de sistema `poppler-utils`) | Extraer texto del informe trimestral de Bilbao. En Linux: `sudo apt install poppler-utils` |

La app en sí **no necesita nada de esto** para arrancar: viaja con el dataset ya generado en `inst/app/data/alquileres.parquet`.

### Instalación paso a paso

1. **Clonar el repositorio**

   ```bash
   git clone https://github.com/pdawgabriel-hub/geo-alquiler.git
   cd geo-alquiler
   ```

2. **Abrir el proyecto en RStudio**

   Abre el archivo `geo-alquiler.Rproj`. Esto configurará automáticamente el directorio de trabajo y activará `{renv}` gracias al `.Rprofile` del proyecto (`source("renv/activate.R")`).

3. **Restaurar el entorno de dependencias con `{renv}`**

   Al abrir el proyecto, `{renv}` detectará el `renv.lock` y te propondrá restaurar el entorno. Si no ocurre automáticamente, ejecútalo manualmente desde la consola de R:

   ```r
   install.packages("renv")   # si aún no lo tienes instalado
   renv::restore()
   ```

   Esto instalará exactamente las mismas versiones de todos los paquetes (incluyendo `golem`, `shiny`, `leaflet`, `plotly`, etc.) que se usaron durante el desarrollo del proyecto.

4. **Generar el `NAMESPACE` del paquete con `{roxygen2}`**

   Este paso es **obligatorio** la primera vez que clonas el proyecto (el archivo `NAMESPACE` no viaja generado en el repositorio, sino que se construye a partir de los comentarios `#' @import`/`#' @importFrom` de la carpeta `R/`):

   ```r
   install.packages("roxygen2")   # si aún no lo tienes instalado
   roxygen2::roxygenise()
   ```

   Si te saltas este paso, `pkgload::load_all()` no sabrá qué funciones de `shiny`, `shinydashboard`, `leaflet`, `leaflet.extras`, `DT` y `plotly` debe poner a disposición del código de los módulos, y la app fallará con errores de tipo *"could not find function..."*.

5. **Verificar que el paquete carga correctamente**

   ```r
   pkgload::load_all()
   ```

   Si no aparece ningún error (los avisos/`Warning` en amarillo son normales), el paquete está listo para ejecutarse.

[⬆ Volver arriba](#top)

---

<a id="uso-ejecucion"></a>
## Uso y Ejecución

Al tratarse de un paquete `{golem}`, la aplicación **no se lanza como un script Shiny convencional**, sino a través de la función exportada `run_app()`.

### Opción 1 — Desde la consola de R (modo desarrollo)

```r
# Carga el paquete en memoria sin necesidad de instalarlo
pkgload::load_all()

# Lanza la aplicación
run_app()
```

### Opción 2 — Ejecutando directamente `app.R`

El archivo `app.R` de la raíz del proyecto ya encapsula ambos pasos anteriores y activa las opciones de producción de `{golem}`. Puedes lanzarlo:

- Desde RStudio, con el botón **Run App** al abrir `app.R`.
- Desde la terminal:

  ```bash
  Rscript app.R
  ```

### Opción 3 — Como paquete instalado

```r
# Instalar el paquete localmente
devtools::install()

# Cargarlo y ejecutarlo como cualquier otra librería
library(GeoAlquiler)
run_app()
```

Por defecto, la aplicación se abrirá en el navegador (o en el visor de RStudio) en `http://127.0.0.1:<puerto>`, mostrando el **Panel Principal** con los KPIs globales y el mapa de calor como punto de entrada.

[⬆ Volver arriba](#top)

---

<a id="uso-terminal"></a>
## Uso desde la Terminal (sin RStudio)

Todo lo anterior puede hacerse íntegramente desde una terminal Bash, sin abrir RStudio en ningún momento — útil para servidores, contenedores, CI/CD o si simplemente prefieres la línea de comandos. La clave es usar `Rscript` (el intérprete de R en modo no interactivo) en vez de pegar código en la consola de RStudio.

### 1. Clonar el repositorio

```bash
git clone <URL-del-repositorio>
cd geo-alquiler
```

### 2. Instalar/restaurar dependencias con `{renv}`

```bash
Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")'
Rscript -e 'renv::restore()'
```

`renv::restore()` lee el `.Rprofile` y el `renv.lock` igual que si hubieras abierto el `.Rproj` en RStudio, así que instala exactamente las mismas versiones de los paquetes.

### 3. Generar el `NAMESPACE` del paquete con `{roxygen2}`

Paso obligatorio, igual que en RStudio: el `NAMESPACE` no viene generado en el repositorio, y sin él `pkgload::load_all()` no podrá poner a disposición del código las funciones de `shiny`, `leaflet`, `DT`, `plotly`, etc.

```bash
Rscript -e 'install.packages("roxygen2", repos = "https://cloud.r-project.org")'
Rscript -e 'roxygen2::roxygenise()'
```

### 4. Verificar que el paquete carga correctamente

```bash
Rscript -e 'pkgload::load_all()'
```

### 5. Ejecutar la aplicación

Cualquiera de estas tres opciones es equivalente a pulsar "Run App" en RStudio:

```bash
# Opción A: usando el lanzador de la raíz del proyecto
Rscript app.R

# Opción B: cargando el paquete en modo desarrollo y llamando a run_app()
Rscript -e 'pkgload::load_all(); run_app()'

# Opción C: si ya lo has instalado como paquete (devtools::install())
Rscript -e 'library(GeoAlquiler); run_app()'
```

> Por defecto, `run_app()` intentará abrir un navegador automáticamente, algo que no existe en un servidor sin entorno gráfico. Si ejecutas esto en remoto (una VM, un contenedor, etc.), añade `options(shiny.launch.browser = FALSE)` antes de llamar a `run_app()`, y opcionalmente fija un puerto y host fijos:
>
> ```bash
> Rscript -e 'pkgload::load_all(); options(shiny.launch.browser = FALSE); shiny::runApp(shiny::shinyApp(ui = app_ui, server = app_server), host = "0.0.0.0", port = 3838)'
> ```
>
> Así la app queda escuchando en `http://<IP-del-servidor>:3838` y puedes acceder desde cualquier navegador sin depender del entorno gráfico de la máquina donde corre.

### 6. Ejecutar los tests

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

o, si tienes `{devtools}` instalado (es una dependencia pesada, no obligatoria para el día a día):

```bash
Rscript -e 'devtools::test()'
```

### 7. Comprobación completa del paquete (`R CMD check`)

Sin necesidad de `{devtools}`, usando directamente las herramientas de línea de comandos de R (además, es el equivalente que se usaría en un pipeline de CI):

```bash
R CMD build .
R CMD check --no-manual GeoAlquiler_*.tar.gz
```

### Resumen — equivalencias RStudio ↔ Terminal

| Acción | En RStudio | En Bash |
|---|---|---|
| Restaurar dependencias | Se ofrece al abrir el `.Rproj` | `Rscript -e 'renv::restore()'` |
| Generar `NAMESPACE` | `Ctrl/Cmd + Shift + D` (o al hacer *Build*) | `Rscript -e 'roxygen2::roxygenise()'` |
| Cargar el paquete | `Ctrl/Cmd + Shift + L` | `Rscript -e 'pkgload::load_all()'` |
| Lanzar la app | Botón "Run App" | `Rscript app.R` |
| Ejecutar tests | `Ctrl/Cmd + Shift + T` | `Rscript -e 'testthat::test_dir("tests/testthat")'` |
| Check completo del paquete | `Ctrl/Cmd + Shift + E` | `R CMD build . && R CMD check --no-manual *.tar.gz` |

[⬆ Volver arriba](#top)

---

<a id="testing-calidad"></a>
## Testing & Calidad

GeoAlquiler incluye una suite de **pruebas unitarias** con **[`{testthat}`](https://testthat.r-lib.org/)**, siguiendo la estructura estándar de un paquete de R (`tests/testthat/`). Las pruebas actuales cubren, entre otros aspectos, la lógica de cálculo de métricas (p. ej. precio por m²) y el comportamiento seguro de los KPIs ante conjuntos de datos vacíos, el módulo de tabla y el Observatorio (`test_observatorio.R`: indicadores derivados y su manejo de datos ausentes, formato numérico español, cortes por cuantiles, reconstrucción de la geometría, normalización y cruce de nombres de municipio entre INE/Catastro/IGN, parseo de las tablas del Catastro, y el módulo con `testServer`).

### Ejecutar todos los tests

Desde la consola de R, en la raíz del proyecto:

```r
testthat::test_dir("tests/testthat")
```

o, si tienes `{devtools}` instalado:

```r
devtools::test()
```

### Ejecutar un archivo de test concreto

```r
testthat::test_file("tests/testthat/test_calculos.R")
```

### Comprobación completa del paquete (build check)

Para una validación más exhaustiva —similar a la que se ejecutaría antes de un release o de subir el paquete a un repositorio—, se recomienda:

```r
devtools::check()
```

Este comando verifica, además de los tests, la consistencia del `DESCRIPTION`, la documentación `roxygen2` y la estructura general del paquete.

> **Buenas prácticas seguidas en el proyecto:** cada nueva funcionalidad de cálculo (predicción de precios, rentabilidad, detección de oportunidades) debería idealmente acompañarse de su correspondiente test en `tests/testthat/`, manteniendo el patrón `test_that("descripción del comportamiento", { expect_*(...) })` ya presente en `test_calculos.R`.

[⬆ Volver arriba](#top)

---

<a id="despliegue"></a>
## Despliegue

Al estar construido como paquete `{golem}` con un lanzador (`app.R`) desacoplado del entorno de desarrollo, GeoAlquiler está preparado para desplegarse en varios entornos habituales del ecosistema Shiny. Actualmente está desplegado de forma gratuita en shinyapps.io:

**[https://pdawgabriel-hub.shinyapps.io/geoalquiler/](https://pdawgabriel-hub.shinyapps.io/geoalquiler/)**

### Notas de compatibilidad (lecciones del primer despliegue)

- **`terra`**: la versión más reciente de CRAN puede fallar al compilar en shinyapps.io por una API de GDAL más nueva de la que tiene su imagen del servidor (error típico: `GDALMDArray::AsClassicDataset` con firma distinta). Si pasa, fija una versión anterior a la que introdujo el soporte GDAL multidimensional (`renv::install("terra@1.8-42")` seguido de `renv::record("terra@1.8-42")`) — pero por encima de la versión mínima que exige `{raster}` (`>= 1.8.5`).
- **`shiny.autoload.r`**: en shinyapps.io/Posit Connect, la sola presencia de una carpeta `R/` junto a `app.R` hace que Shiny la autocargue como "ficheros de apoyo" **antes** de que se ejecute `app.R` (donde poner esta opción llega tarde). Por eso `.Rprofile` fija `options(shiny.autoload.r = FALSE)` — si el error `Error in box: plot.new has not been called yet` reaparece, es que esta opción no se está aplicando a tiempo.
- Recuerda ejecutar `renv::snapshot()` (o `renv::record()` para un paquete concreto) antes de desplegar, para que `renv.lock` refleje exactamente lo que necesita el servidor.
- Refresca los datos periódicamente con `Rscript scripts/ingesta/run_pipeline.R` (ver [Fuente de los Datos](#fuente-datos)) antes de cada despliegue, ya que las fuentes oficiales se actualizan con periodicidad propia (trimestral en el caso de Bilbao).
- `scripts/deploy.R` enumera a mano los ficheros que se suben: incluye `inst/app/data/observatorio_municipios.parquet`. Si añades otro fichero de datos, añádelo también ahí o no llegará al servidor (la app arranca igualmente y el Observatorio muestra un aviso si falta su fichero).

[⬆ Volver arriba](#top)

---

<a id="licencia"></a>
## Licencia

Este proyecto se publica como **pieza de portfolio personal** y tiene una licencia de uso restringido. En detalle:

- Puedes **ver, clonar y ejecutar** el código con fines de **aprendizaje, evaluación técnica o revisión de portfolio** (por ejemplo, como parte de un proceso de selección o para estudiar la arquitectura del proyecto).
- Puedes **modificar el código para uso personal, no comercial**, siempre citando la autoría original.
- **No está permitido el uso comercial** del proyecto, ni total ni parcial (incluyendo su despliegue como producto o servicio, su reventa, o su integración en soluciones comerciales de terceros) sin autorización expresa del autor.
- **El único titular con derecho a explotación comercial del proyecto es el autor original**, [Gabriel](https://github.com/pdawgabriel-hub) (autor y desarrollador de GeoAlquiler).

El texto legal completo se encuentra en el archivo [`LICENSE.md`](./LICENSE.md) (versión en inglés: [`LICENSE.en.md`](./LICENSE.en.md)).

[⬆ Volver arriba](#top)

---

<a id="autor"></a>
## Autor

Desarrollado por **Gabriel Iborra Vicente** como proyecto de portfolio, con el objetivo de demostrar el desarrollo de aplicaciones Shiny de nivel profesional estructuradas como paquete de R (`{golem}`), combinando analítica geoespacial, modelos de Machine Learning y herramientas de decisión de inversión inmobiliaria.

[⬆ Volver arriba](#top)