if (file.exists("renv/activate.R")) source("renv/activate.R")

# En shinyapps.io/Posit Connect, la mera presencia de R/ junto a app.R hace
# que Shiny autocargue esos ficheros como "helpers" antes de que se ejecute
# app.R (donde poner esta misma opción llega demasiado tarde). Se fija aquí,
# en .Rprofile, que se ejecuta al arrancar R, antes que cualquier otra cosa.
options(shiny.autoload.r = FALSE)
