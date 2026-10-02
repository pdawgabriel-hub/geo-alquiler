<a id="top"></a>
# GeoAlquiler

**Español** | [English](./README.en.md)

### Inteligencia Inmobiliaria y Análisis Espacial del Mercado de Alquiler

![R](https://img.shields.io/badge/R-4.x-276DC3?logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-App-blue?logo=rstudio&logoColor=white)
![golem](https://img.shields.io/badge/Framework-golem-6E4A7E)
![License](https://img.shields.io/badge/Licencia-Portfolio%20%2F%20Uso%20restringido-red)
![Status](https://img.shields.io/badge/Estado-En%20desarrollo-yellow)
[![Tests](https://github.com/pdawgabriel-hub/geo-alquiler/actions/workflows/ci.yml/badge.svg)](https://github.com/pdawgabriel-hub/geo-alquiler/actions/workflows/ci.yml)

---

## Índice

- [Descripción General](#descripcion-general)
- [Arquitectura](#arquitectura)
- [Características Principales / Módulos](#caracteristicas-principales)
  - [1. Exploración Espacial](#exploracion-espacial)
  - [2. Analítica & Machine Learning](#analitica-ml)
  - [3. Herramientas de Inversión](#herramientas-inversion)
  - [4. Observatorio del Alquiler en España](#observatorio)
- [Capturas de Pantalla](#capturas-pantalla)
- [Fuente de los Datos](#fuente-datos)
- [Puesta en Marcha](#puesta-en-marcha)
- [Calidad y Tests](#calidad-tests)
- [Documentación Técnica](#documentacion-tecnica)
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

### Cómo está construido

La app se organiza en tres capas que no se mezclan, y cada cambio tiene un sitio claro (el esquema completo está en [Arquitectura](#arquitectura)):

- **Ingesta offline** (`scripts/ingesta/`). Descargar, limpiar y cruzar las fuentes se hace a mano con `Rscript scripts/ingesta/run_pipeline.R`, nunca dentro de la app. El resultado son dos ficheros Parquet que viajan con el paquete, así que la app arranca rápido y no depende de que ninguna web externa responda. Si una fuente cambia de formato, falla el pipeline con un error explícito, no la app en producción.
- **Lógica de negocio sin Shiny** (`R/fct_*.R`). Los cálculos que importan (indicadores, cruce de nombres de municipio, formato de cifras, geometría del mapa) son funciones puras que usan tanto el pipeline como la app, y se prueban con `testthat` sin levantar un servidor.
- **Interfaz por módulos** (`R/mod_*.R`). Cada pantalla es un módulo independiente. `app_server.R` solo los ensambla y decide qué versión de los datos recibe cada uno, que es la decisión de diseño central de la app:

| El módulo recibe… | Módulos | Por qué |
|---|---|---|
| `datos_visibles`: filtros + lo que se ve en el mapa | Tabla, Analítica, Estadística, Oportunidades, Calculadora, Informe, Exportar | Responden a "lo que estoy mirando ahora" |
| Datos filtrados, sin recorte del mapa | Recomendador KNN | Buscar similares solo en el encuadre daría muy pocos candidatos |
| Dataset completo | Comparador, Predicción, Barrios, Favoritos | Necesitan todo el mercado: entrenar el modelo, comparar ciudades, no perder favoritos al filtrar |
| Su propio dataset | Observatorio | Datos oficiales agregados por municipio, independientes de los filtros |

El trabajo pesado se hace en el servidor y al navegador solo llega lo que se va a pintar (ver [cómo carga rápido](docs/GUIA_TECNICA.md#rendimiento) en la guía técnica).

El proyecto está pensado como pieza de **portfolio técnico**, demostrando dominio de arquitectura de aplicaciones Shiny a nivel de paquete de R (framework `{golem}`), modularización, buenas prácticas de testing y un enfoque de producto orientado a un caso de uso real (PropTech / Real Estate Analytics). Los precios por zona proceden de fuentes reales (Generalitat de Catalunya, Generalitat Valenciana, Gobierno Vasco) o, donde no existe fuente oficial, de índices publicados documentados a mano (ver `scripts/ingesta/`).

[⬆ Volver arriba](#top)

---

<a id="arquitectura"></a>
## Arquitectura

![Esquema de la arquitectura de GeoAlquiler: la ingesta offline genera dos ficheros Parquet; la app Shiny los carga en app_server.R, que reparte datos visibles, filtrados o completos a cada módulo, y el Observatorio carga su propio fichero una vez por proceso; el navegador recibe widgets ya preparados y devuelve clics, filtros y encuadre como eventos.](man/figures/arquitectura.svg)

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

País Vasco y Navarra no tienen datos de alquiler ni de Catastro (régimen foral), y los municipios con muy pocos contratos declarados no tienen mediana de alquiler. Cuando falta un dato, la ficha del municipio explica el motivo. Los detalles de las fuentes, el cruce entre ellas y sus limitaciones están en la [guía técnica](docs/GUIA_TECNICA.md#pipeline-observatorio).

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

<a id="fuente-datos"></a>
## Fuente de los Datos

Todos los datos proceden de fuentes reales y se preparan con un pipeline offline (`scripts/ingesta/`), nunca dentro de la app.

**Anuncios** (`inst/app/data/alquileres.parquet`): el precio/m² de cada zona sale de la fuente oficial más desagregada disponible para cada ciudad. Los anuncios individuales son una ilustración generada dentro de cada zona, pero su precio siempre parte del €/m² real.

| Ciudad | Fuente | Detalle |
|---|---|---|
| **Barcelona** | Generalitat de Catalunya (INCASÒL), fianzas de alquiler | Por barrio |
| **Bilbao** | Gobierno Vasco (Etxebide), Informe EMAL trimestral | Por barrio |
| **Valencia** | Generalitat Valenciana, registro de fianzas | Por código postal |
| **Madrid, Sevilla** | Sin fuente pública con importe y geografía (verificado) | Ancla manual documentada, marcada como estimada |

**Observatorio** (`inst/app/data/observatorio_municipios.parquet`): SERPAVI (Ministerio de Vivienda y Agenda Urbana), INE (Atlas de Distribución de Renta de los Hogares y Padrón) y Catastro, cruzados por código INE de municipio y referidos todos a 2022.

Cómo se descarga y cruza cada fuente, el esquema de los datos y cómo regenerarlos: [guía técnica, sección 4](docs/GUIA_TECNICA.md#pipeline).

[⬆ Volver arriba](#top)

---

<a id="puesta-en-marcha"></a>
## Puesta en Marcha

Necesitas **R ≥ 4.1**. Desde la raíz del proyecto:

```bash
git clone https://github.com/pdawgabriel-hub/geo-alquiler.git
cd geo-alquiler
Rscript -e 'renv::restore()'                         # instala las versiones exactas de renv.lock
Rscript app.R                                        # lanza la app
Rscript -e 'testthat::test_dir("tests/testthat")'    # ejecuta los tests
```

Desde RStudio: abre `geo-alquiler.Rproj`, acepta restaurar el entorno y pulsa **Run App** sobre `app.R`. La app no descarga nada al arrancar: los datos ya generados viajan en `inst/app/data/`.

La app está desplegada en **[pdawgabriel-hub.shinyapps.io/geoalquiler](https://pdawgabriel-hub.shinyapps.io/geoalquiler/)**.

[⬆ Volver arriba](#top)

---

<a id="calidad-tests"></a>
## Calidad y Tests

Los cálculos de negocio (KPIs, hipoteca y proyección de la inversión, detección de oportunidades, similitud del recomendador, indicadores del Observatorio, cruce de nombres de municipio entre fuentes…) son funciones puras en `R/fct_*.R`, separadas de la interfaz, y se prueban directamente:

- **29 tests con 102 comprobaciones** (`tests/testthat/`), con valores de referencia calculados a mano (por ejemplo, la cuota de una hipoteca de 200.000 € a 30 años al 3 %), los casos límite y cada fallo ya corregido, para que no vuelva.
- **Módulos probados con `testServer()`**, sin navegador, para comprobar que cada pantalla pasa bien sus datos a los cálculos.
- **Integración continua con GitHub Actions**: en cada push, GitHub instala desde cero las versiones exactas de `renv.lock` y ejecuta todos los tests. La insignia **Tests** de arriba muestra el resultado del último commit.

Cómo están organizados los tests, cómo escribir uno nuevo y cómo funciona el workflow: [guía técnica, secciones 8 y 9](docs/GUIA_TECNICA.md#tests).

[⬆ Volver arriba](#top)

---

<a id="documentacion-tecnica"></a>
## Documentación Técnica

La **[guía técnica](docs/GUIA_TECNICA.md)** explica el código en detalle:

- Estructura del proyecto y convenciones del paquete `{golem}`.
- Flujo de datos dentro de la app: qué datos recibe cada módulo y por qué.
- Recorrido por el código: cómo es un módulo, cómo se separa el cálculo de la interfaz y cómo se comunica el servidor con el navegador, con fragmentos reales.
- Pipeline de datos paso a paso, con el esquema del dataset y el cruce de fuentes del Observatorio.
- Optimizaciones de rendimiento, en especial cómo el Observatorio carga ~8.200 polígonos.
- Instalación detallada (RStudio y terminal) y problemas conocidos.
- Tests, integración continua (incluido cómo reproducirla en local) y despliegue.
- Dónde tocar para hacer los cambios más habituales.

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