# Despliegue

La app está desplegada en shinyapps.io: **[pdawgabriel-hub.shinyapps.io/geoalquiler](https://pdawgabriel-hub.shinyapps.io/geoalquiler/)**. Se despliega de dos formas:

- **A mano**: `Rscript scripts/deploy.R`, que sube los ficheros que haya en tu disco.
- **Automática**: el job `despliegue` de `.github/workflows/ci.yml` ejecuta ese mismo script después de cada push a `main`, solo si los tests pasan (ver [Integración continua](calidad.md#ci)). Necesita dos secretos en el repositorio (*Settings > Secrets and variables > Actions*): `SHINYAPPS_TOKEN` y `SHINYAPPS_SECRET`, que se obtienen en shinyapps.io en *Account > Tokens*. Sin ellos el job termina en verde sin desplegar nada.

## Lecciones de los despliegues

- **`scripts/deploy.R` enumera a mano los ficheros que se suben.** Incluye los dos Parquet de `inst/app/data/`. Si añades otro fichero de datos, añádelo también ahí o no llegará al servidor.
- **`shiny.autoload.r`**: en shinyapps.io/Posit Connect, una carpeta `R/` junto a `app.R` hace que Shiny la cargue como "ficheros de apoyo" **antes** de ejecutar `app.R`. Por eso `.Rprofile` fija `options(shiny.autoload.r = FALSE)`. Si reaparece `Error in box: plot.new has not been called yet`, esa opción no se está aplicando a tiempo.
- **`terra`**: la versión más reciente de CRAN puede no compilar en shinyapps.io por una API de GDAL más nueva que la del servidor (error con `GDALMDArray::AsClassicDataset`). Fija una versión anterior: `renv::install("terra@1.8-42")` y `renv::record("terra@1.8-42")`, siempre por encima de la mínima que exige `{raster}` (`>= 1.8.5`).
- Ejecuta `renv::snapshot()` (o `renv::record()` para un paquete concreto) antes de desplegar, para que `renv.lock` refleje lo que necesita el servidor.
- Regenera los datos antes de cada despliegue si las fuentes se han actualizado (Bilbao publica cada trimestre).

## Esta guía

La guía técnica se publica aparte, en GitHub Pages: **[pdawgabriel-hub.github.io/geo-alquiler](https://pdawgabriel-hub.github.io/geo-alquiler/)**. La publica `.github/workflows/docs.yml` en cada push a `main` que cambie `docs/`, `mkdocs.yml` o `requirements-docs.txt`, y también se puede lanzar a mano desde *Actions*. Necesita, una sola vez, *Settings > Pages > Source: GitHub Actions*. Cómo verla en local: [Desarrollo local](desarrollo-local.md#ver-esta-guia-en-local).
