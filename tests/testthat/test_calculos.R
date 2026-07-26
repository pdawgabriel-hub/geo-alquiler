library(testthat)

test_that("El cálculo de precio por metro cuadrado funciona correctamente", {
  precio <- 1200
  superficie <- 80
  
  precio_m2 <- round(precio / superficie, 1)
  
  expect_equal(precio_m2, 15.0)
  expect_type(precio_m2, "double")
})

test_that("Manejo seguro de conjuntos de datos vacíos en KPIs", {
  df_vacio <- data.frame(id = character(), precio = numeric(), superficie = numeric())
  
  precio_medio <- if (nrow(df_vacio) > 0) mean(df_vacio$precio, na.rm = TRUE) else 0
  
  expect_equal(precio_medio, 0)
})