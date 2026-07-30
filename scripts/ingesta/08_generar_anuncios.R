# scripts/ingesta/08_generar_anuncios.R
#
# Última etapa: convierte la tabla de precios/m² reales por zona (con
# lat/lon ya geocodificados) en filas individuales de "anuncio", con el
# mismo esquema que ya usa toda la app (id, titulo, ciudad, barrio, tipo,
# precio, superficie, habitaciones, banos, lat, lon, lng), más tres columnas
# nuevas para dejar trazabilidad del origen del dato:
#
#   fuente_dato  -> de dónde sale el precio/m² de esa zona
#   es_estimado  -> TRUE si esa zona no tiene fuente oficial (ancla manual)
#   nivel_geo    -> granularidad real del dato ("barrio", "distrito",
#                   "seccion_censal", "municipio", "zona_sin_fuente_oficial")
#
# A diferencia de generar_datos_simulados.R (que inventaba el precio entero a
# partir de multiplicadores arbitrarios), aquí el precio de cada anuncio se
# genera SIEMPRE a partir del precio/m² real de su zona -- lo que varía de un
# anuncio a otro dentro de la misma zona es solo la superficie, tipología y
# un margen de ruido (+-15%) que imita la dispersión normal de un mercado
# real alrededor de su media.

generar_anuncios <- function(precios_zona, semilla = SEMILLA_GENERACION) {
  set.seed(semilla)

  precios_zona <- precios_zona[!is.na(precios_zona$precio_m2) & !is.na(precios_zona$lat) & !is.na(precios_zona$lon), ]
  if (nrow(precios_zona) == 0) {
    stop("[generar_anuncios] La tabla de precios por zona está vacía tras filtrar NAs. Revisa las etapas anteriores del pipeline.")
  }

  lista_anuncios <- vector("list", nrow(precios_zona))
  id_actual <- 1000

  for (i in seq_len(nrow(precios_zona))) {
    fila <- precios_zona[i, ]
    n <- sample(N_ANUNCIOS_POR_ZONA_MIN:N_ANUNCIOS_POR_ZONA_MAX, 1)

    tipos_sample <- sample(TIPOS_INMUEBLE, n, replace = TRUE, prob = PROB_TIPOS)
    superficie   <- round(pmax(30, stats::rnorm(n, mean = 80, sd = 25)))
    habitaciones <- pmax(1, round(superficie / 30) + sample(-1:1, n, replace = TRUE))
    banos        <- pmax(1, round(habitaciones * 0.6))

    mult_tipo <- ifelse(tipos_sample == "Ático", 1.15,
                  ifelse(tipos_sample == "Estudio", 0.90, 1.0))

    # El precio SIEMPRE parte del precio/m² real de la zona: esto es lo que
    # convierte los anuncios en una ilustración de un dato real, en vez de un
    # número inventado desde cero.
    precio <- round(superficie * fila$precio_m2 * mult_tipo * stats::runif(n, 0.85, 1.15))

    # Dispersión geográfica pequeña alrededor del punto geocodificado de la
    # zona (mucho más ajustada que el jitter a nivel de ciudad que usaba
    # generar_datos_simulados.R, porque ahora el centro ya es del barrio/
    # distrito real, no de toda la ciudad).
    lat <- fila$lat + stats::rnorm(n, mean = 0, sd = 0.0035)
    lon <- fila$lon + stats::rnorm(n, mean = 0, sd = 0.0035)

    nombre_zona <- if (is.na(fila$zona)) fila$ciudad else fila$zona

    lista_anuncios[[i]] <- data.frame(
      id           = as.character(id_actual:(id_actual + n - 1)),
      titulo       = paste(tipos_sample, "en", nombre_zona, "(", fila$ciudad, ")"),
      ciudad       = fila$ciudad,
      barrio       = nombre_zona,
      tipo         = tipos_sample,
      precio       = precio,
      superficie   = superficie,
      habitaciones = habitaciones,
      banos        = banos,
      lat          = lat,
      lon          = lon,
      lng          = lon,
      fuente_dato  = fila$fuente,
      es_estimado  = isTRUE(fila$es_estimado),
      nivel_geo    = fila$nivel_geo,
      stringsAsFactors = FALSE
    )

    id_actual <- id_actual + n
  }

  do.call(rbind, lista_anuncios)
}
