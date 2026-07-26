library(testthat)
library(shiny)
library(DT)

# Cargar el código del módulo
source(file.path("../../R", "mod_tabla.R"))

datos_mues_tabla <- data.frame(
  id = c("A1", "A2", "A3"),
  ciudad = c("Madrid", "Barcelona", "Sevilla"),
  tipo = c("Piso", "Estudio", "Ático"),
  precio = c(1000, 700, 900),
  superficie = c(50, 35, 60),
  stringsAsFactors = FALSE
)

test_that("Módulo tablaServer maneja la selección e inclusión/eliminación de favoritos", {
  
  favs_val <- reactiveVal(c("A2"))
  
  testServer(tablaServer, args = list(id = "test_tbl", datos_reactivos = reactive({ datos_mues_tabla }), favoritos_ids = favs_val), {
    
    # 1. Simular la selección de filas y forzar ejecución reactiva
    session$setInputs(tabla_inmuebles_rows_selected = c(1, 3))
    session$setInputs(btn_guardar_fav = 1)
    
    # Flush reactivo implícito
    session$flushReact()
    
    # Verificar adición
    expect_setequal(favs_val(), c("A2", "A1", "A3"))
    
    # 2. Desmarcar elemento (Toggle)
    session$setInputs(tabla_inmuebles_rows_selected = c(2))
    session$setInputs(btn_guardar_fav = 2)
    
    session$flushReact()
    
    # Verificar eliminación
    expect_setequal(favs_val(), c("A1", "A3"))
  })
})