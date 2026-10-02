# Cálculos de negocio de la app (sin dependencias de Shiny), extraídos de los
# módulos para poder probarlos directamente en tests/testthat/test_calculos.R.
# Los módulos solo leen los inputs, llaman a estas funciones y pintan el
# resultado.

# --- Panel Principal -----------------------------------------------------------

#' KPIs del mercado visible: precio medio, superficie media, precio/m² medio
#' y nº de inmuebles. Con un conjunto vacío (o NULL) devuelve ceros en vez de
#' NaN, para que las cajas del Panel Principal no muestren "NaN €".
#' @noRd
kpis_mercado <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(list(precio_medio = 0, superficie_media = 0, precio_m2_medio = 0, total = 0))
  }
  list(
    precio_medio = round(mean(df$precio, na.rm = TRUE)),
    superficie_media = round(mean(df$superficie, na.rm = TRUE)),
    precio_m2_medio = round(mean(df$precio / df$superficie, na.rm = TRUE), 1),
    total = nrow(df)
  )
}

# --- Mapa del Panel Principal ----------------------------------------------------

#' ¿Es utilizable el encuadre que reporta Leaflet?
#'
#' Al redimensionar el mapa (abrir el menú, rotar el móvil) Leaflet puede
#' reportar un instante un encuadre con valores no numéricos o sin área. Ese
#' encuadre vaciaba las siete pantallas que dependen de `datos_visibles`.
#' @noRd
encuadre_valido <- function(bounds) {
  lados <- c("north", "south", "east", "west")
  if (is.null(bounds) || !all(lados %in% names(bounds))) return(FALSE)
  numericos <- all(vapply(bounds[lados], function(x) is.numeric(x) && length(x) == 1 && is.finite(x), logical(1)))
  numericos && bounds$south < bounds$north && bounds$west < bounds$east
}

#' Inmuebles dentro del encuadre del mapa. Si el encuadre no es válido (o aún
#' no existe), devuelve todos los datos en vez de ninguno.
#' @noRd
filtrar_por_encuadre <- function(df, bounds) {
  if (!encuadre_valido(bounds) || is.null(df) || nrow(df) == 0) return(df)
  df[df$lat >= bounds$south & df$lat <= bounds$north &
     df$lng >= bounds$west & df$lng <= bounds$east, ]
}

# --- Calculadora de rentabilidad -----------------------------------------------

#' Cuota mensual de un préstamo con el sistema francés (cuota constante).
#' `tin` es el tipo de interés nominal anual en tanto por uno (0.03 = 3 %).
#' Con interés 0 la cuota es el capital entre el número de meses.
#' @noRd
cuota_hipoteca <- function(prestamo, tin, anos) {
  tasa_mensual <- tin / 12
  num_cuotas <- anos * 12
  if (tin > 0) {
    prestamo * (tasa_mensual * (1 + tasa_mensual)^num_cuotas) / (((1 + tasa_mensual)^num_cuotas) - 1)
  } else {
    prestamo / num_cuotas
  }
}

#' Rentabilidad bruta inicial (%): alquiler anual sobre precio de compra.
#' @noRd
rentabilidad_bruta <- function(precio, alquiler_mensual) {
  if (precio > 0) round(((alquiler_mensual * 12) / precio) * 100, 2) else 0
}

#' Cash flow neto mensual del primer año: alquiler menos gastos y cuota.
#' @noRd
cash_flow_mensual <- function(alquiler_mensual, gastos_anuales, cuota_mensual) {
  alquiler_mensual - gastos_anuales / 12 - cuota_mensual
}

#' Simulación de la inversión año a año.
#'
#' Los porcentajes van en tanto por uno. El año 0 es la compra (cash flow =
#' -entrada). Cada año siguiente amortiza 12 cuotas, revaloriza el inmueble y
#' actualiza alquiler y gastos con `inc_alquiler` (se asume que los gastos
#' suben al mismo ritmo que el alquiler). Las cifras de la tabla se redondean
#' a euros; los acumulados se calculan sin redondear.
#' @noRd
simular_inversion <- function(precio, alquiler_mensual, gastos_anuales, pct_entrada, tin, anos,
                              inc_alquiler, aprec_inmueble) {
  entrada <- precio * pct_entrada
  monto_prestamo <- precio - entrada
  tasa_mensual <- tin / 12
  cuota_mensual <- cuota_hipoteca(monto_prestamo, tin, anos)

  proyeccion <- data.frame(
    Ano = 0:anos,
    Valor_Inmueble = NA_real_,
    Saldo_Pendiente = NA_real_,
    Ingreso_Alquiler_Anual = NA_real_,
    Gastos_Operativos_Anuales = NA_real_,
    Pago_Hipoteca_Anual = NA_real_,
    Cash_Flow_Anual = NA_real_,
    Cash_Flow_Acumulado = NA_real_
  )
  proyeccion[1, -1] <- c(precio, monto_prestamo, 0, 0, 0, -entrada, -entrada)

  saldo_actual <- monto_prestamo
  cf_acumulado <- -entrada

  for (a in seq_len(anos)) {
    for (m in 1:12) {
      int_m <- saldo_actual * tasa_mensual
      cap_m <- cuota_mensual - int_m
      saldo_actual <- max(0, saldo_actual - cap_m)
    }
    val_inmueble <- precio * ((1 + aprec_inmueble)^a)
    ing_alq <- alquiler_mensual * 12 * ((1 + inc_alquiler)^(a - 1))
    gast_op <- gastos_anuales * ((1 + inc_alquiler)^(a - 1))
    pago_hip <- cuota_mensual * 12
    cf_anual <- ing_alq - gast_op - pago_hip
    cf_acumulado <- cf_acumulado + cf_anual

    proyeccion[a + 1, -1] <- round(c(val_inmueble, saldo_actual, ing_alq, gast_op, pago_hip, cf_anual, cf_acumulado), 0)
  }

  list(
    cuota_mensual = cuota_mensual,
    entrada = entrada,
    monto_prestamo = monto_prestamo,
    proyeccion = proyeccion
  )
}

# --- Detector de oportunidades -------------------------------------------------

#' Inmuebles cuyo precio/m² está al menos `pct_umbral` % por debajo de la
#' media de su ciudad (calculada sobre los propios datos recibidos), ordenados
#' de mayor a menor descuento. Devuelve NULL si no hay datos.
#' @noRd
detectar_oportunidades <- function(df, pct_umbral) {
  if (is.null(df) || nrow(df) == 0) return(NULL)

  df$precio_m2 <- df$precio / df$superficie
  medias <- stats::aggregate(precio_m2 ~ ciudad, data = df, FUN = mean)
  names(medias)[2] <- "media_ciudad_m2"
  df <- merge(df, medias, by = "ciudad")
  df$pct_diferencia <- ((df$media_ciudad_m2 - df$precio_m2) / df$media_ciudad_m2) * 100

  oportunidades <- df[df$pct_diferencia >= pct_umbral, ]
  if (nrow(oportunidades) > 0) oportunidades <- oportunidades[order(-oportunidades$pct_diferencia), ]
  oportunidades
}

# --- Recomendador KNN --------------------------------------------------------------

#' Los `top_n` inmuebles más parecidos a `ref` (una fila), excluyéndolo a él.
#'
#' La distancia combina precio, superficie y, si existen, latitud y longitud,
#' cada una normalizada por su rango en `df` para que ninguna domine por
#' escala. Pesos: ubicación 30 % + 30 %, precio 25 %, superficie 15 % (sin
#' coordenadas: precio 60 %, superficie 40 %). `similitud` es 1 - distancia,
#' en porcentaje. Devuelve NULL si no hay candidatos o faltan precio/superficie.
#' @noRd
inmuebles_similares <- function(ref, df, top_n) {
  if (is.null(ref) || is.null(df) || nrow(df) < 2) return(NULL)
  cand <- df[df$id != ref$id[1], , drop = FALSE]
  if (nrow(cand) == 0 || !all(c("precio", "superficie") %in% names(cand))) return(NULL)

  col_lat <- intersect(c("latitud", "lat", "latitude"), names(cand))[1]
  col_lng <- intersect(c("longitud", "lng", "lon", "longitude"), names(cand))[1]
  distancia <- function(col) {
    abs(cand[[col]] - ref[[col]][1]) / (max(df[[col]], na.rm = TRUE) - min(df[[col]], na.rm = TRUE) + 1e-5)
  }

  d_pre <- distancia("precio")
  d_sup <- distancia("superficie")
  dist_total <- if (!is.na(col_lat) && !is.na(col_lng)) {
    sqrt(0.3 * distancia(col_lat)^2 + 0.3 * distancia(col_lng)^2 + 0.25 * d_pre^2 + 0.15 * d_sup^2)
  } else {
    sqrt(0.6 * d_pre^2 + 0.4 * d_sup^2)
  }

  cand$score <- dist_total
  cand$similitud <- paste0(round(pmax(0, (1 - dist_total)) * 100, 1), "%")
  cand$precio_m2 <- round(cand$precio / cand$superficie, 1)
  utils::head(cand[order(cand$score), ], top_n)
}

# --- Predicción de precios -------------------------------------------------------

#' Fórmula del modelo de regresión de precios según las columnas disponibles.
#'
#' lm() falla con un factor de un solo nivel ("contrasts can be applied only
#' to factors with 2 or more levels"), lo que pasa por ejemplo si el dataset
#' solo tiene una ciudad. Por eso los predictores categóricos solo entran si
#' tienen al menos dos valores distintos.
#' @noRd
formula_prediccion <- function(df) {
  terminos <- "superficie"
  if ("habitaciones" %in% names(df)) terminos <- c(terminos, "habitaciones")
  if ("banos" %in% names(df)) terminos <- c(terminos, "banos")
  if ("ciudad" %in% names(df) && length(unique(df$ciudad)) >= 2) terminos <- c(terminos, "factor(ciudad)")
  if ("tipo" %in% names(df) && length(unique(df$tipo)) >= 2) terminos <- c(terminos, "factor(tipo)")
  stats::as.formula(paste("precio ~", paste(terminos, collapse = " + ")))
}
