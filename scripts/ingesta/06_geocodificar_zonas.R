# scripts/ingesta/06_geocodificar_zonas.R
#
# Toma la tabla de precios por zona ya armonizada (ver 07_armonizar_precios.R)
# y añade lat/lon reales a cada fila, geocodificando "zona, ciudad, España"
# con Nominatim (ver geocodificar_zona() en 01_utils.R). Sustituye a las
# coordenadas aleatorias (rnorm alrededor del centro de la ciudad) que usaba
# generar_datos_simulados.R.
#
# Si una zona no se puede geocodificar (nombre no reconocido por OSM, o sin
# conexión), se cae de vuelta al centro del municipio (columna `ciudad`) y se
# avisa por consola -- así el pipeline nunca se detiene por una única zona
# rara, pero queda constancia de qué filas usan esa aproximación.

# Centros de municipio de respaldo (fallback), solo para el caso de que una
# zona/barrio concreto no se pueda geocodificar. No se usan para nada más.
CENTROS_MUNICIPIO_FALLBACK <- list(
  "Madrid"        = c(lat = 40.4168, lon = -3.7038),
  "Barcelona"     = c(lat = 41.3851, lon = 2.1734),
  "Valencia"      = c(lat = 39.4699, lon = -0.3763),
  "Sevilla"       = c(lat = 37.3891, lon = -5.9845),
  "Bilbao"        = c(lat = 43.2630, lon = -2.9350)
)

#' @param precios_zona data.frame con columnas ciudad, zona (puede tener NA).
#' Devuelve el mismo data.frame con columnas lat, lon añadidas.
geocodificar_precios_zona <- function(precios_zona) {
  precios_zona$lat <- rep(NA_real_, nrow(precios_zona))
  precios_zona$lon <- rep(NA_real_, nrow(precios_zona))

  if (nrow(precios_zona) == 0) return(precios_zona)

  # Cacheamos por (ciudad, zona) única para no geocodificar la misma zona
  # varias veces si aparece repetida (p.ej. distintos tipos de inmueble).
  combinaciones <- unique(precios_zona[, c("ciudad", "zona")])

  for (i in seq_len(nrow(combinaciones))) {
    ciudad_i <- combinaciones$ciudad[i]
    zona_i   <- combinaciones$zona[i]

    consulta_zona <- if (is.na(zona_i)) ciudad_i else zona_i
    # Los códigos postales se guardan como "CP 46001" para mostrarlos en la
    # UI, pero ese prefijo confunde la búsqueda de texto libre de Nominatim
    # (no encuentra nada) -- para geocodificar se usa solo el código postal
    # con el parámetro `postalcode`, que Nominatim sí resuelve bien.
    es_codigo_postal <- grepl("^CP \\d+$", consulta_zona)
    coords <- if (es_codigo_postal) {
      geocodificar_zona(NULL, ciudad_i, codigo_postal = sub("^CP ", "", consulta_zona))
    } else {
      geocodificar_zona(consulta_zona, ciudad_i)
    }

    if (is.null(coords)) {
      fallback <- CENTROS_MUNICIPIO_FALLBACK[[ciudad_i]]
      if (is.null(fallback)) {
        warning("  [geocoding] Sin coordenadas ni fallback para '", consulta_zona, "' (", ciudad_i, "). Se descarta esa zona.")
        next
      }
      message("  [geocoding] Usando centro de '", ciudad_i, "' como aproximación para '", consulta_zona, "'.")
      coords <- list(lat = fallback["lat"], lon = fallback["lon"], barrio_resuelto = NA_character_)
    }

    idx <- which(
      precios_zona$ciudad == ciudad_i &
        (is.na(precios_zona$zona) & is.na(zona_i) | precios_zona$zona == zona_i)
    )
    precios_zona$lat[idx] <- coords$lat
    precios_zona$lon[idx] <- coords$lon

    # Si geocodificamos por código postal y Nominatim ha devuelto el barrio
    # real al que pertenece, sustituimos "CP 46001" por ese nombre -- mucho
    # más legible en la app que un código postal desnudo.
    if (es_codigo_postal && !is.null(coords$barrio_resuelto) && !is.na(coords$barrio_resuelto)) {
      message("  [geocoding] '", consulta_zona, "' -> barrio real: '", coords$barrio_resuelto, "'")
      precios_zona$zona[idx] <- coords$barrio_resuelto
    }
  }

  precios_zona
}
