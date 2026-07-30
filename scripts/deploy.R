# scripts/deploy.R
#
# Despliegue a shinyapps.io. Requiere tener ya configurada la cuenta con
# rsconnect::setAccountInfo() (ver README, sección de despliegue).
#
# IMPORTANTE: no se usa el descubrimiento automático de ficheros de
# rsconnect (ni .Rbuildignore ni .rscignore -- este último se probó y se
# comportó de forma inconsistente entre ejecuciones idénticas). En su lugar
# se pasa la lista exacta de ficheros necesarios en tiempo de ejecución, para
# no subir por accidente cachés de datos (data/raw/), el pipeline de
# ingesta, tests, capturas, ni -sobre todo- cualquier fichero suelto y ajeno
# al proyecto que hubiera en la carpeta.
#
# Uso: Rscript scripts/deploy.R

archivos <- c(
  "app.R", ".Rprofile", "DESCRIPTION", "NAMESPACE", "renv.lock",
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  "inst/app/data/alquileres.parquet"
)

rsconnect::deployApp(
  appDir = ".",
  appFiles = archivos,
  appName = "geoalquiler",
  account = "pdawgabriel-hub",
  forceUpdate = TRUE,
  launch.browser = FALSE
)
