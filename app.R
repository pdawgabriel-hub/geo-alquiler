# Lanzador estandarizado compatible con Servidores de Despliegue y Golem
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
options("golem.app.prod" = TRUE)
run_app()