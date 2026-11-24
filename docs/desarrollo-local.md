# Desarrollo local

## Requisitos

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

## Puesta en marcha

```bash
git clone https://github.com/pdawgabriel-hub/geo-alquiler.git
cd geo-alquiler
Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")'   # si no tienes renv
Rscript -e 'renv::restore()'      # instala las versiones exactas de renv.lock
Rscript app.R                     # lanza la app
```

Desde RStudio es lo mismo: abre `geo-alquiler.Rproj` (activa `renv` mediante `.Rprofile`), acepta restaurar el entorno y pulsa **Run App** sobre `app.R`.

La app abre el navegador en `http://127.0.0.1:<puerto>` con el Panel Principal. No necesita descargar nada: los datos ya generados viajan en `inst/app/data/`.

## Otras formas de lanzarla

```bash
Rscript -e 'pkgload::load_all(); run_app()'      # modo desarrollo
Rscript -e 'library(GeoAlquiler); run_app()'     # si la has instalado con devtools::install()
```

En un servidor sin entorno gráfico, desactiva la apertura del navegador y fija host y puerto:

```bash
Rscript -e 'pkgload::load_all(); options(shiny.launch.browser = FALSE); shiny::runApp(run_app(), host = "0.0.0.0", port = 3838)'
```

## `NAMESPACE`

`NAMESPACE` está versionado en el repositorio, así que no hace falta generarlo para ejecutar la app. Solo hay que regenerarlo si cambias las etiquetas `#' @import` / `#' @importFrom` de `R/`:

```bash
Rscript -e 'roxygen2::roxygenise()'
```

## Equivalencias RStudio ↔ terminal

| Acción | En RStudio | En la terminal |
|---|---|---|
| Restaurar dependencias | Se ofrece al abrir el `.Rproj` | `Rscript -e 'renv::restore()'` |
| Regenerar `NAMESPACE` | `Ctrl/Cmd + Shift + D` | `Rscript -e 'roxygen2::roxygenise()'` |
| Cargar el paquete | `Ctrl/Cmd + Shift + L` | `Rscript -e 'pkgload::load_all()'` |
| Lanzar la app | Botón "Run App" | `Rscript app.R` |
| Ejecutar tests | `Ctrl/Cmd + Shift + T` | `Rscript -e 'testthat::test_dir("tests/testthat")'` |
| Check completo | `Ctrl/Cmd + Shift + E` | `R CMD build . && R CMD check --no-manual GeoAlquiler_*.tar.gz` |

## Si `renv` no encuentra los paquetes

`renv` asocia la librería de paquetes a la ruta del proyecto. Si mueves o renombras la carpeta, al arrancar verás `One or more packages recorded in the lockfile are not installed` y errores como `there is no package called 'testthat'`. Se resuelve con:

```bash
Rscript -e 'renv::restore()'
```

Los paquetes que ya están en la caché de `renv` se enlazan desde ahí, sin descargar ni compilar. Comprueba el resultado con `Rscript -e 'renv::status()'`, que debe decir "No issues found".

!!! note "Copias anteriores a octubre de 2026"
    Si `renv::restore()` falla con `[NULL]: failed to download` o con paquetes en `dependency failed`, actualiza `renv.lock` y `renv/activate.R` desde el repositorio: eran dos problemas del lockfile y de `renv` 1.2.3, ya corregidos (ver [Dos problemas que aparecieron al montarlo](calidad.md#problemas-ci)).

## Ver esta guía en local {#ver-esta-guia-en-local}

La guía se construye con [MkDocs Material](https://squidfunk.github.io/mkdocs-material/), que es Python. Solo hace falta para previsualizar cambios en `docs/`; la app no lo necesita.

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-docs.txt
.venv/bin/mkdocs serve                # http://127.0.0.1:8000, se recarga al guardar
.venv/bin/mkdocs build --strict       # lo mismo que hace el workflow: falla con un enlace roto
```

Al hacer push a `main` con cambios en `docs/`, `mkdocs.yml` o `requirements-docs.txt`, el workflow `.github/workflows/docs.yml` la construye y la publica en GitHub Pages.
