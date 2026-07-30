# Lanzador estandarizado compatible con Servidores de Despliegue y Golem
#
# shiny.autoload.r = FALSE es imprescindible en shinyapps.io/Posit Connect:
# al ver un directorio R/ junto a app.R, Shiny lo autocarga como "ficheros de
# apoyo" ANTES de que se ejecute este script, cargando cada mod_*.R como
# script suelto (no como parte del paquete). Eso duplica la carga y rompe la
# resolución de funciones como box() (shinydashboard::box vs graphics::box).
# pkgload::load_all() ya hace la carga correcta como paquete, así que se
# desactiva el autoload de Shiny para que no interfiera.
options(shiny.autoload.r = FALSE)
pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
options("golem.app.prod" = TRUE)
run_app()