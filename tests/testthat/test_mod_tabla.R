library(shiny)
library(testthat)

# Cargar la definición del módulo a probar
source("../../R/mod_tabla.R")

test_that("El botón de favoritos añade un ID correctamente en la tabla", {
  
  # Mock reactivo de prueba
  datos_mock <- reactive({
    data.frame(
      id = c("1", "2"),
      ciudad = c("Madrid", "Barcelona"),
      tipo = c("Piso", "Atico"),
      precio = c(1000, 1500),
      superficie = c(70, 90),
      stringsAsFactors = FALSE
    )
  })
  
  favoritos_ids <- reactiveVal(c())
  
  # Prueba reactiva interna del servidor del módulo
  testServer(tablaServer, args = list(datos_reactivos = datos_mock, favoritos_ids = favoritos_ids), {
    session$setInputs(tabla_inmuebles_rows_selected = 1)
    session$setInputs(btn_guardar_fav = 1)
    
    expect_equal(favoritos_ids(), "1")
  })
})