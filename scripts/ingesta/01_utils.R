# scripts/ingesta/01_utils.R
#
# Utilidades comunes para todo el pipeline de ingesta:
#   - descargar_con_cache(): descarga un fichero solo si no existe ya (o si ha
#     caducado), para no golpear las fuentes externas en cada ejecución.
#   - geocodificar_zona(): convierte "Malasaña, Madrid" en lat/lon reales
#     usando el geocodificador gratuito de OpenStreetMap (Nominatim), con
#     caché en disco y respetando su política de uso (1 petición/segundo,
#     User-Agent identificable). Esto sustituye a las coordenadas aleatorias
#     que usaba generar_datos_simulados.R.
#
# Requiere los paquetes httr y jsonlite (declarados en Suggests en DESCRIPTION,
# ya que solo se usan para regenerar los datos, no en la app en producción).

if (!requireNamespace("httr", quietly = TRUE)) {
  stop("Falta el paquete 'httr'. Instálalo con install.packages('httr') antes de ejecutar el pipeline.")
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Falta el paquete 'jsonlite'. Instálalo con install.packages('jsonlite') antes de ejecutar el pipeline.")
}

#' Descarga un fichero a RUTA_RAW solo si no existe o si han pasado más de
#' `dias_cache` días desde la última descarga. Devuelve la ruta local.
#'
#' @param url URL del fichero a descargar.
#' @param nombre_fichero Nombre con el que se guarda en RUTA_RAW (incluye extensión).
#' @param dias_cache Nº de días que se considera "fresco" el fichero cacheado.
#' @param binario TRUE para Excel/zip, FALSE para texto/JSON/CSV.
descargar_con_cache <- function(url, nombre_fichero, dias_cache = 30, binario = TRUE) {
  ruta_local <- file.path(RUTA_RAW, nombre_fichero)

  necesita_descarga <- !file.exists(ruta_local) ||
    (as.numeric(difftime(Sys.time(), file.info(ruta_local)$mtime, units = "days")) > dias_cache)

  if (!necesita_descarga) {
    message("  [cache] ", nombre_fichero, " ya descargado (< ", dias_cache, " días). Se reutiliza.")
    return(ruta_local)
  }

  message("  [descarga] ", url)
  respuesta <- tryCatch(
    httr::GET(url, httr::timeout(60), httr::write_disk(ruta_local, overwrite = TRUE),
              httr::user_agent("GeoAlquiler-pipeline/1.0 (uso interno, contacto: pdawgabriel@gmail.com)")),
    error = function(e) e
  )

  if (inherits(respuesta, "error") || httr::http_error(respuesta)) {
    if (file.exists(ruta_local)) file.remove(ruta_local)
    warning("No se ha podido descargar ", url, " -- ",
            if (inherits(respuesta, "error")) conditionMessage(respuesta) else httr::status_code(respuesta))
    return(NA_character_)
  }

  # Algunos proxys/portales devuelven un HTTP 200 con una página HTML de
  # error (login, mantenimiento, dominio bloqueado) en vez del fichero real.
  # Para un .xlsx eso rompe readxl con un error de bajo nivel poco claro, así
  # que comprobamos aquí la firma ZIP ("PK") que tiene todo .xlsx válido.
  if (binario && grepl("\\.xlsx?$", nombre_fichero, ignore.case = TRUE)) {
    primeros_bytes <- readBin(ruta_local, what = "raw", n = 2)
    es_zip_valido <- length(primeros_bytes) == 2 && identical(as.integer(primeros_bytes), c(0x50L, 0x4BL))
    if (!es_zip_valido) {
      file.remove(ruta_local)
      warning(
        "La descarga de ", url, " no es un Excel válido (probablemente la fuente devolvió una página de ",
        "error/mantenimiento con estado 200 en vez del fichero). Se descarta y se omite esta fuente."
      )
      return(NA_character_)
    }
  }

  ruta_local
}

# --- Geocodificación de zonas (Nominatim / OpenStreetMap) ------------------
#
# Nominatim es gratuito para volúmenes bajos (uso: https://operations.osmfoundation.org/policies/nominatim/):
# máx. 1 petición/segundo, User-Agent identificable, y no se puede usar para
# geocodificar en tiempo real cada visita de un usuario final -- aquí se usa
# SOLO en este pipeline de construcción de datos (se ejecuta puntualmente,
# no en cada sesión de la app), y el resultado se cachea en disco para no
# tener que repetir las llamadas en próximas ejecuciones.

RUTA_CACHE_GEOCODING <- file.path(RUTA_RAW, "geocache_zonas.csv")

.cargar_geocache <- function() {
  cache_df <- if (file.exists(RUTA_CACHE_GEOCODING)) {
    utils::read.csv(RUTA_CACHE_GEOCODING, stringsAsFactors = FALSE, encoding = "UTF-8")
  } else {
    data.frame(consulta = character(0), lat = numeric(0), lon = numeric(0), stringsAsFactors = FALSE)
  }
  # Compatibilidad con cachés generadas antes de añadir barrio_resuelto
  if (!"barrio_resuelto" %in% names(cache_df)) cache_df$barrio_resuelto <- NA_character_
  cache_df
}

.guardar_geocache <- function(cache_df) {
  utils::write.csv(cache_df, RUTA_CACHE_GEOCODING, row.names = FALSE, fileEncoding = "UTF-8")
}

#' Geocodifica una zona (barrio/pedanía + ciudad) a lat/lon usando Nominatim.
#' Devuelve list(lat=, lon=, barrio_resuelto=) o NULL si no se ha podido
#' geocodificar. `barrio_resuelto` es el nombre de barrio/distrito real que
#' devuelve Nominatim en su desglose de dirección (solo relevante cuando se
#' busca por código postal, ver `codigo_postal`) -- NA si no aplica o si
#' Nominatim no lo ha podido resolver.
#' Usa un fichero de caché en disco (data/raw/geocache_zonas.csv) para no
#' repetir peticiones a la misma consulta en ejecuciones futuras del pipeline.
#'
#' @param zona nombre del barrio/distrito, o NULL si se geocodifica por
#'   código postal (ver `codigo_postal`).
#' @param codigo_postal si se indica, se geocodifica por código postal
#'   (parámetro `postalcode` de Nominatim) en vez de por texto libre --
#'   necesario porque prefijos como "CP 46001" no los resuelve la búsqueda
#'   de texto libre, mientras que el código postal solo sí. Además, al pedir
#'   `addressdetails=1`, Nominatim devuelve el barrio/distrito real al que
#'   pertenece ese código postal (campo `address$suburb` o `address$city_district`),
#'   que se usa para sustituir el "CP 46001" por un nombre de barrio real.
geocodificar_zona <- function(zona, ciudad, pais = "España", codigo_postal = NULL) {
  consulta <- if (!is.null(codigo_postal)) {
    paste("CP", codigo_postal, ciudad, pais, sep = ", ")
  } else {
    paste(c(zona, ciudad, pais), collapse = ", ")
  }

  cache_df <- .cargar_geocache()
  fila_cache <- cache_df[cache_df$consulta == consulta, ]
  if (nrow(fila_cache) > 0) {
    return(list(lat = fila_cache$lat[1], lon = fila_cache$lon[1], barrio_resuelto = fila_cache$barrio_resuelto[1]))
  }

  query_nominatim <- if (!is.null(codigo_postal)) {
    list(postalcode = codigo_postal, country = pais, format = "json", addressdetails = 1, limit = 1, countrycodes = "es")
  } else {
    list(q = consulta, format = "json", addressdetails = 1, limit = 1, countrycodes = "es")
  }

  url <- httr::modify_url("https://nominatim.openstreetmap.org/search", query = query_nominatim)

  # Respeta el límite de 1 petición/segundo de la política de uso de Nominatim
  Sys.sleep(1)

  # (ver nota sobre return() dentro de tryCatch en 02_fuente_serpavi.R)
  resultado <- tryCatch({
    resp <- httr::GET(url, httr::user_agent("GeoAlquiler-pipeline/1.0 (uso interno, contacto: pdawgabriel@gmail.com)"),
                       httr::timeout(15))
    if (httr::http_error(resp)) {
      NULL
    } else {
      jsonlite::fromJSON(httr::content(resp, as = "text", encoding = "UTF-8"))
    }
  }, error = function(e) NULL)

  if (is.null(resultado) || length(resultado) == 0 || nrow(resultado) == 0) {
    message("  [geocoding] Sin resultado para: ", consulta)
    return(NULL)
  }

  lat <- as.numeric(resultado$lat[1])
  lon <- as.numeric(resultado$lon[1])

  barrio_resuelto <- NA_character_
  if (!is.null(codigo_postal) && "address" %in% names(resultado) && !is.null(resultado$address)) {
    direccion <- resultado$address[1, ]
    barrio_resuelto <- if ("suburb" %in% names(direccion) && !is.na(direccion$suburb)) {
      direccion$suburb
    } else if ("city_district" %in% names(direccion) && !is.na(direccion$city_district)) {
      direccion$city_district
    } else {
      NA_character_
    }
  }

  cache_df <- rbind(cache_df, data.frame(
    consulta = consulta, lat = lat, lon = lon, barrio_resuelto = barrio_resuelto, stringsAsFactors = FALSE
  ))
  .guardar_geocache(cache_df)

  list(lat = lat, lon = lon, barrio_resuelto = barrio_resuelto)
}
