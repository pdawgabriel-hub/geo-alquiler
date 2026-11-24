# Estructura del proyecto

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
│   └── www/               # custom.css y custom.js (ver "Recorrido por el código" y "Rendimiento")
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
├── docs/                  # Esta guía (MkDocs): una página por capítulo
│   └── img/               # Esquema de arquitectura y capturas (las usan también los README)
├── mkdocs.yml             # Configuración de la guía: menú, tema y extensiones
├── requirements-docs.txt  # MkDocs y MkDocs Material, solo para construir la guía
├── reporte_plantilla.Rmd  # Plantilla del Informe Ejecutivo
├── tests/testthat/        # Tests (ver "Calidad")
├── .github/workflows/
│   ├── ci.yml             # Integración continua: tests y despliegue (ver "Calidad")
│   └── docs.yml           # Publica esta guía en GitHub Pages
└── renv.lock              # Versiones exactas de todas las dependencias
```

## Convenciones

- **Módulos**: cada pantalla vive en su `mod_*.R` con el patrón de [Shiny Modules](https://shiny.posit.co/r/articles/improve/modules/) (`NS(id)`, `*UI()` y `*Server()`). Así no colisionan los `inputId`/`outputId` y `app_ui.R`/`app_server.R` solo orquestan.
- **Lógica sin Shiny** en `fct_*.R`: si una función no necesita reactividad, va ahí y se testea sin servidor.
- **`app_ui.R`** define solo la estructura visual: el `dashboardPage`, el menú lateral (Panel Principal, Observatorio, Exploración, Analítica, Inversión e Información) y los `tabItems` que enlazan cada pestaña con la UI de su módulo.
- **`run_app.R`** envuelve la `shinyApp` con `golem::with_golem_options()`, de modo que se pueden pasar opciones (`golem_opts`) sin tocar el resto del código.
- **`app.R`** es el lanzador universal: hace `pkgload::load_all()` y activa `golem.app.prod = TRUE`, así que funciona igual en local que en Shiny Server, Posit Connect, shinyapps.io o un contenedor, sin instalar el paquete.
- **Datos empaquetados** en `inst/app/data/`, siguiendo la convención de `{golem}`: viajan con el paquete y están disponibles tanto en desarrollo como desplegado.
- **Dependencias reproducibles** con `{renv}` (`renv.lock` + `.Rprofile`).
