library(shiny)
library(testthat)
library(leaflet)
library(plotly)
library(DT)

source("../../R/fct_observatorio.R")
source("../../R/mod_observatorio.R")

# Funciones de ingesta que no necesitan red (normalización de nombres y
# parseo de números y tablas JAXI)
source("../../scripts/ingesta/09_observatorio.R")

# Dos municipios con geometría mínima (cuadrados) y datos realistas, en el
# mismo formato que guarda el pipeline (WKB en dos niveles de detalle).
observatorio_mock <- function() {
  cuadrado <- function(x, y) sf::st_polygon(list(rbind(c(x, y), c(x + 0.1, y), c(x + 0.1, y + 0.1), c(x, y + 0.1), c(x, y))))
  geom <- sf::st_sfc(sf::st_multipolygon(list(cuadrado(-3.7, 40.4))), sf::st_multipolygon(list(cuadrado(-3.6, 40.3))), crs = 4326)
  wkb <- lapply(sf::st_as_binary(geom), as.raw)
  df <- data.frame(
    cod_ine = c("28079", "28065"),
    cod_provincia = c("28", "28"),
    provincia = c("Madrid", "Madrid"),
    municipio = c("Madrid", "Getafe"),
    alquiler_m2_mediana = c(12.77, 9.1),
    alquiler_mes_mediana = c(800, 650),
    viviendas_alquiler = c(281462, 9500),
    renta_hogar = c(46651, 38000),
    poblacion = c(3280782, 185180),
    poblacion_ultima = c(3506730, 190000),
    inmuebles_residenciales = c(1502436, 78727),
    valor_catastral_residencial_miles = c(178998537, 4000000),
    anio_referencia = 2022,
    anio_poblacion_ultima = 2025,
    lng_centro = c(-3.65, -3.55),
    lat_centro = c(40.45, 40.35),
    stringsAsFactors = FALSE
  )
  df <- calcular_indicadores_observatorio(df)
  df$geometria <- wkb
  df$geometria_baja <- wkb
  df
}

test_that("El esfuerzo de alquiler es el alquiler anual sobre la renta del hogar", {
  df <- calcular_indicadores_observatorio(data.frame(
    alquiler_mes_mediana = 800, renta_hogar = 46651, poblacion = 100, poblacion_ultima = 110,
    viviendas_alquiler = 20, inmuebles_residenciales = 200, valor_catastral_residencial_miles = 30000
  ))
  expect_equal(df$esfuerzo_alquiler_pct, round(100 * 800 * 12 / 46651, 1))
  expect_equal(df$crecimiento_poblacion_pct, 10)
  expect_equal(df$pct_viviendas_alquiler, 10)
  expect_equal(df$valor_catastral_medio, 150000)
  expect_equal(df$viviendas_por_1000_hab, 2000)
})

test_that("Los indicadores con datos ausentes o nulos quedan como NA, nunca Inf", {
  df <- calcular_indicadores_observatorio(data.frame(
    alquiler_mes_mediana = c(NA, 500), renta_hogar = c(30000, 0), poblacion = c(0, NA),
    poblacion_ultima = c(10, 10), viviendas_alquiler = c(5, 5), inmuebles_residenciales = c(0, NA),
    valor_catastral_residencial_miles = c(100, 100)
  ))
  indicadores <- df[, c("esfuerzo_alquiler_pct", "crecimiento_poblacion_pct", "pct_viviendas_alquiler",
                        "valor_catastral_medio", "viviendas_por_1000_hab")]
  expect_true(all(is.na(unlist(indicadores))))
})

test_that("formatear_indicador usa formato español y marca los datos ausentes", {
  expect_equal(formatear_indicador(12.765, "alquiler_m2_mediana"), "12,77 €/m²")
  expect_equal(formatear_indicador(3280782, "poblacion"), "3.280.782")
  expect_equal(formatear_indicador(NA, "renta_hogar"), "s/d")
  expect_error(formatear_indicador(1, "no_existe"))
})

test_that("cortes_cuantiles devuelve cortes crecientes y tolera valores repetidos o vacíos", {
  cortes <- cortes_cuantiles(c(1:100, NA), n_clases = 4)
  expect_equal(cortes, c(1, 25.75, 50.5, 75.25, 100))
  expect_true(length(cortes_cuantiles(rep(5, 10))) == 2)
  expect_null(cortes_cuantiles(c(NA, NA)))
})

test_that("observatorio_a_sf reconstruye la geometría WKB guardada en Parquet", {
  x <- observatorio_a_sf(observatorio_mock(), "geometria_baja")
  expect_s3_class(x, "sf")
  expect_equal(nrow(x), 2)
  expect_false(any(c("geometria", "geometria_baja") %in% names(x)))
  expect_equal(sf::st_crs(x)$epsg, 4326L)
})

test_that("Los nombres de municipio del INE, Catastro e IGN se normalizan a la misma clave", {
  expect_equal(claves_municipio("Acebeda, La")[[1]][1], "laacebeda")
  expect_equal(claves_municipio("Acebeda (La)")[[1]][1], "laacebeda")
  expect_equal(claves_municipio("La Acebeda")[[1]][1], "laacebeda")
  expect_true("lalfasdelpi" %in% claves_municipio("Alfàs del Pi (l')")[[1]])
  expect_true(all(c("alicante", "alacant") %in% claves_municipio("Alicante/Alacant")[[1]]))
})

test_that("emparejar_municipios cruza por nombre y descarta claves ambiguas", {
  catalogo <- data.frame(cod_ine = c("03014", "03099", "03100"),
                         nombre = c("Alicante/Alacant", "Villanueva", "Villanueva"))
  res <- emparejar_municipios(c("Alacant", "Villanueva", "Inexistente"), catalogo)
  expect_equal(res, c("03014", NA, NA))
})

test_that("emparejar_aproximado cruza renombramientos y nombres en otro idioma, sin forzar casos dudosos", {
  catalogo <- data.frame(
    cod_ine = c("43131", "17034", "46204", "46024", "46222"),
    nombre = c("Roda de Berà", "Calonge i Sant Antoni", "Puig de Santa Maria, el",
               "Alfara de la Baronia", "Sant Joanet")
  )
  res <- emparejar_aproximado(c("Roda de Barà", "Calonge", "Puig", "Alfara de Algimia", "Sant Joan de l'Ènova"), catalogo)
  expect_equal(res[1:3], c("43131", "17034", "46204"))
  # Dos renombramientos completos a la vez: no se adivina cuál es cuál
  expect_equal(res[4:5], c(NA_character_, NA_character_))

  # Si solo queda un nombre y un código sin cruzar, se emparejan entre sí
  expect_equal(emparejar_aproximado("Santa Maria de Corcó", data.frame(cod_ine = "08254", nombre = "Esquirol, L'")), "08254")
})

test_that("motivo_sin_dato explica cada dato ausente y no dice nada si el dato existe", {
  base <- data.frame(cod_ine = "28079", alquiler_m2_mediana = 12, renta_hogar = 40000,
                     inmuebles_residenciales = 100, poblacion = 1000)
  expect_null(motivo_sin_dato(base, "alquiler_m2_mediana"))

  pueblo <- transform(base, alquiler_m2_mediana = NA, renta_hogar = NA, esfuerzo_alquiler_pct = NA)
  expect_match(motivo_sin_dato(pueblo, "alquiler_m2_mediana"), "pocos contratos")
  expect_match(motivo_sin_dato(pueblo, "renta_hogar"), "secreto estadístico")
  expect_match(motivo_sin_dato(pueblo, "esfuerzo_alquiler_pct"), "pocos contratos")

  bilbao <- transform(base, cod_ine = "48020", alquiler_m2_mediana = NA, inmuebles_residenciales = NA,
                      valor_catastral_medio = NA)
  expect_match(motivo_sin_dato(bilbao, "alquiler_m2_mediana"), "foral")
  expect_match(motivo_sin_dato(bilbao, "valor_catastral_medio"), "foral")
})

test_that("numero_es interpreta el formato numérico español del INE y el Catastro", {
  expect_equal(numero_es(c("1.502.436", "12,5", "..", "")), c(1502436, 12.5, NA, NA))
})

test_that("parsear_tabla_jaxi ignora la celda de esquina vacía y lee cada municipio", {
  html <- paste0(
    '<table><tr><td class="tableCellGr"></td><td class="tableCellGr">Comercial</td>',
    '<td class="tableCellGr">Residencial</td></tr>',
    '<tr><td class="tableCellGr">Alfàs del Pi (l&#039;)</td><td class="dataCell">1.200</td>',
    '<td class="dataCell">15.300</td></tr></table>'
  )
  df <- parsear_tabla_jaxi(html)
  expect_equal(names(df), c("municipio", "Comercial", "Residencial"))
  expect_equal(df$municipio, "Alfàs del Pi (l')")
  expect_equal(df$Residencial, 15300)
})

test_that("El módulo del observatorio selecciona un municipio al hacer clic en el mapa", {
  testServer(observatorioServer, args = list(datos_observatorio = observatorio_mock()), {
    session$setInputs(indicador = "esfuerzo_alquiler_pct", ambito = TODA_ESPANA, poblacion_min = "0")
    expect_equal(nrow(datos_ambito()), 2)
    expect_null(municipio_sel())

    session$setInputs(mapa_shape_click = list(id = "28065"))
    expect_equal(municipio_sel(), "28065")

    # El ranking se ordena por el indicador elegido, de mayor a menor
    expect_equal(ranking_df()$cod_ine, c("28079", "28065"))

    # El filtro de población mínima deja fuera a Getafe
    session$setInputs(poblacion_min = "1000000")
    expect_equal(tabla_ambito()$cod_ine, "28079")

    # Cambiar de ámbito limpia la selección
    session$setInputs(ambito = "Madrid")
    expect_null(municipio_sel())
  })
})

test_that("El módulo del observatorio no rompe la app si falta el fichero de datos", {
  expect_silent(testServer(observatorioServer, args = list(datos_observatorio = NULL), {}))
})
