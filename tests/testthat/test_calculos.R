library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(testthat)

# Cálculos de negocio de la app (R/fct_calculos.R) y su uso desde los módulos
source("../../R/fct_calculos.R")
source("../../R/mod_calculadora.R")

inmuebles_mock <- function() {
  data.frame(
    id = c("A", "B", "C", "D", "E"),
    ciudad = c("Madrid", "Madrid", "Madrid", "Sevilla", "Sevilla"),
    tipo = c("Piso", "Piso", "Ático", "Piso", "Estudio"),
    precio = c(1000, 1000, 700, 800, 600),
    superficie = c(100, 100, 100, 80, 60),
    lat = c(40.40, 40.41, 40.45, 37.38, 37.39),
    lng = c(-3.70, -3.71, -3.65, -5.98, -5.99),
    stringsAsFactors = FALSE
  )
}

# --- Panel Principal -------------------------------------------------------------

test_that("kpis_mercado calcula medias y precio/m² del mercado visible", {
  k <- kpis_mercado(inmuebles_mock())
  expect_equal(k$precio_medio, 820)
  expect_equal(k$superficie_media, 88)
  expect_equal(k$precio_m2_medio, round(mean(c(10, 10, 7, 10, 10)), 1))
  expect_equal(k$total, 5)
})

test_that("kpis_mercado devuelve ceros (no NaN) con un conjunto vacío o NULL", {
  vacio <- list(precio_medio = 0, superficie_media = 0, precio_m2_medio = 0, total = 0)
  expect_equal(kpis_mercado(inmuebles_mock()[0, ]), vacio)
  expect_equal(kpis_mercado(NULL), vacio)
})

# --- Encuadre del mapa ------------------------------------------------------------

test_that("encuadre_valido rechaza encuadres ausentes, incompletos, no numéricos o sin área", {
  bueno <- list(north = 41, south = 40, east = -3, west = -4)
  expect_true(encuadre_valido(bueno))
  expect_false(encuadre_valido(NULL))
  expect_false(encuadre_valido(bueno[c("north", "south")]))
  expect_false(encuadre_valido(modifyList(bueno, list(north = NA_real_))))
  expect_false(encuadre_valido(modifyList(bueno, list(east = "x"))))
  expect_false(encuadre_valido(modifyList(bueno, list(north = 40))))   # sin altura
  expect_false(encuadre_valido(modifyList(bueno, list(west = -2))))    # oeste > este
})

test_that("filtrar_por_encuadre recorta al encuadre y, si no es válido, no vacía los datos", {
  df <- inmuebles_mock()
  madrid <- list(north = 40.5, south = 40.3, east = -3.6, west = -3.8)
  expect_equal(filtrar_por_encuadre(df, madrid)$id, c("A", "B", "C"))
  # El caso que vaciaba las pantallas: un encuadre degenerado durante un redimensionado
  degenerado <- list(north = 40.5, south = 40.5, east = -3.6, west = -3.6)
  expect_equal(nrow(filtrar_por_encuadre(df, degenerado)), nrow(df))
  expect_equal(nrow(filtrar_por_encuadre(df, NULL)), nrow(df))
})

# --- Calculadora de rentabilidad --------------------------------------------------

test_that("cuota_hipoteca aplica el sistema francés", {
  # Valor de referencia: 200.000 € a 30 años al 3 % -> 843,21 €/mes
  expect_equal(round(cuota_hipoteca(200000, 0.03, 30), 2), 843.21)
  # Sin interés, la cuota es el capital entre el número de meses
  expect_equal(cuota_hipoteca(120000, 0, 10), 1000)
})

test_that("rentabilidad_bruta y cash_flow_mensual", {
  expect_equal(rentabilidad_bruta(200000, 1000), 6)
  expect_equal(rentabilidad_bruta(0, 1000), 0)
  expect_equal(cash_flow_mensual(1000, 1200, 700), 200)
})

test_that("simular_inversion cuadra entrada, amortización y cash flow año a año", {
  sim <- simular_inversion(precio = 200000, alquiler_mensual = 1000, gastos_anuales = 1200,
                           pct_entrada = 0.2, tin = 0.03, anos = 25,
                           inc_alquiler = 0.02, aprec_inmueble = 0.01)
  p <- sim$proyeccion
  expect_equal(sim$entrada, 40000)
  expect_equal(sim$monto_prestamo, 160000)
  expect_equal(sim$cuota_mensual, cuota_hipoteca(160000, 0.03, 25))
  expect_equal(nrow(p), 26)

  # Año 0: compra
  expect_equal(p$Cash_Flow_Anual[1], -40000)
  expect_equal(p$Saldo_Pendiente[1], 160000)
  # Año 1: alquiler y gastos sin actualizar todavía
  expect_equal(p$Ingreso_Alquiler_Anual[2], 12000)
  expect_equal(p$Gastos_Operativos_Anuales[2], 1200)
  expect_equal(p$Cash_Flow_Anual[2], round(12000 - 1200 - 12 * sim$cuota_mensual))
  # Año 2: alquiler y gastos suben un 2 %
  expect_equal(p$Ingreso_Alquiler_Anual[3], round(12000 * 1.02))
  # Revalorización compuesta del inmueble
  expect_equal(p$Valor_Inmueble[26], round(200000 * 1.01^25))
  # La deuda baja cada año y queda saldada al final del plazo
  expect_true(all(diff(p$Saldo_Pendiente) < 0))
  expect_equal(p$Saldo_Pendiente[26], 0)
  # El acumulado es la suma de los flujos anuales (salvo redondeo a euros)
  expect_lt(abs(p$Cash_Flow_Acumulado[26] - sum(p$Cash_Flow_Anual)), 26)
})

test_that("La calculadora pasa los porcentajes de los inputs a tanto por uno", {
  testServer(calculadoraServer, {
    session$setInputs(precio_compra = 200000, alquiler_mensual = 1000, gastos_mantenimiento = 1200,
                      porcentaje_entrada = 20, interes_hipoteca = 3, plazo_anos = "25",
                      incremento_alquiler = 2, apreciacion_inmueble = 1)
    esperado <- simular_inversion(200000, 1000, 1200, 0.2, 0.03, 25, 0.02, 0.01)
    expect_equal(simulacion(), esperado)
  })
})

# --- Detector de oportunidades -----------------------------------------------------

test_that("detectar_oportunidades compara cada inmueble con la media de su ciudad", {
  # Madrid: 10, 10 y 7 €/m² (media 9) -> C está un 22,2 % por debajo.
  # Sevilla: 10 y 10 €/m² -> ninguno por debajo de la media.
  op <- detectar_oportunidades(inmuebles_mock(), 20)
  expect_equal(op$id, "C")
  expect_equal(round(op$pct_diferencia, 1), 22.2)

  # Con umbral 0 entran los que están en la media o por debajo, ordenados por descuento
  op0 <- detectar_oportunidades(inmuebles_mock(), 0)
  expect_equal(op0$id[1], "C")
  expect_setequal(op0$id, c("C", "D", "E"))

  expect_null(detectar_oportunidades(inmuebles_mock()[0, ], 10))
})

# --- Recomendador KNN --------------------------------------------------------------

test_that("inmuebles_similares excluye la referencia y ordena por parecido", {
  df <- inmuebles_mock()
  res <- inmuebles_similares(df[df$id == "A", ], df, 3)
  expect_equal(nrow(res), 3)
  expect_false("A" %in% res$id)
  # B tiene el mismo precio y superficie y está al lado: es el más parecido
  expect_equal(res$id[1], "B")
  expect_true(all(diff(res$score) >= 0))
  expect_equal(res$precio_m2[1], 10)
})

test_that("inmuebles_similares funciona sin coordenadas y con pocos datos", {
  df <- inmuebles_mock()
  sin_coords <- df[, setdiff(names(df), c("lat", "lng"))]
  res <- inmuebles_similares(sin_coords[1, ], sin_coords, 2)
  expect_equal(res$id[1], "B")
  # Sin coordenadas la distancia solo usa precio (60 %) y superficie (40 %)
  todos <- inmuebles_similares(sin_coords[1, ], sin_coords, 5)
  d_pre <- abs(800 - 1000) / (1000 - 600 + 1e-5)
  d_sup <- abs(80 - 100) / (100 - 60 + 1e-5)
  expect_equal(todos$score[todos$id == "D"], sqrt(0.6 * d_pre^2 + 0.4 * d_sup^2))

  expect_null(inmuebles_similares(df[1, ], df[1, ], 3))
})

# --- Predicción de precios -------------------------------------------------------

test_that("formula_prediccion deja fuera los factores de un solo nivel", {
  df <- inmuebles_mock()
  expect_equal(deparse(formula_prediccion(df)), "precio ~ superficie + factor(ciudad) + factor(tipo)")

  # Con una sola ciudad, factor(ciudad) haría fallar lm()
  madrid <- df[df$ciudad == "Madrid", ]
  f <- formula_prediccion(madrid)
  expect_false(grepl("ciudad", deparse(f)))
  expect_s3_class(lm(f, data = madrid), "lm")
})
