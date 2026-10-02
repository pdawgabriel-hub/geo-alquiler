# scripts/ingesta/09_observatorio.R
#
# Observatorio del Alquiler en España: tabla municipal que cruza cuatro
# fuentes oficiales, todas referidas al MISMO año (ANIO_OBSERVATORIO en
# 00_config.R) para que los ratios entre ellas tengan sentido:
#
#   - SERPAVI (Ministerio de Vivienda y Agenda Urbana): mediana de alquiler
#     €/m² y €/mes, superficie mediana y nº de viviendas en alquiler por
#     municipio, a partir de los datos fiscales (IRPF) de arrendamientos.
#     La web de SERPAVI es una calculadora con reCAPTCHA (por eso se descartó
#     en su día como fuente de los anuncios), pero el CDN del Ministerio
#     publica las capas cartográficas completas (shapefile con los datos ya
#     agregados por municipio), que es lo que se usa aquí. La geometría
#     municipal del mapa coroplético sale también de este shapefile (IGN).
#   - INE, Atlas de Distribución de Renta de los Hogares (ADRH, tabla
#     nacional 30824): renta neta media por hogar y por persona.
#   - INE, Cifras oficiales del Padrón (tabla 29005): población del año de
#     referencia y del último año publicado (para el crecimiento reciente).
#   - Dirección General del Catastro, estadísticas del Catastro Inmobiliario
#     Urbano: nº de inmuebles de uso residencial y valor catastral
#     residencial, por municipio (una tabla JAXI por provincia).
#
# País Vasco y Navarra no aparecen en SERPAVI ni en el Catastro estatal
# (tienen Hacienda y Catastro forales propios); el INE sí los cubre, así que
# esos municipios quedan con renta/población pero sin datos de alquiler.
#
# Salidas (en RUTA_PROCESADOS y copiadas a RUTA_APP_DATOS):
#   - observatorio_municipios.parquet: una fila por municipio, con la
#     geometría simplificada en WKB (columna `geometria`) para que la app no
#     tenga que cargar el shapefile original de ~80 MB.

# Tablas JAXI del Catastro por provincia (URAO = nº de bienes inmuebles por
# uso; URBO = valor catastral por uso, en miles de €). Faltan 01, 20, 31 y 48
# (régimen foral).
PROVINCIAS_CATASTRO <- sprintf("%02d", setdiff(1:52, c(1, 20, 31, 48)))

URL_SERPAVI_MUNICIPIOS <- "https://cdn.mivau.gob.es/portal-web-mivau/vivienda/serpavi/ALQ_Municipios_2022_Web.zip"
URL_INE_ADRH_NACIONAL  <- "https://www.ine.es/jaxiT3/files/t/es/csv_bdsc/30824.csv"
URL_INE_PADRON         <- "https://www.ine.es/jaxiT3/files/t/es/csv_bdsc/29005.csv"
URL_CATASTRO_JAXI      <- "https://www.catastro.hacienda.gob.es/jaxi/tabla.do"


# Tolerancias (en metros, sobre EPSG:3857) al simplificar los polígonos
# municipales. Se guardan dos niveles de detalle: el fino para cuando la app
# muestra una sola provincia, y el grueso para la vista de toda España, donde
# a zoom 5-6 un píxel ya son ~2 km y el detalle extra solo engordaría lo que
# viaja al navegador (~260.000 vértices frente a ~90.000).
TOLERANCIA_SIMPLIFICACION_M <- 250
TOLERANCIA_SIMPLIFICACION_BAJA_M <- 1500

# --- Utilidades ---------------------------------------------------------------

# Caché de descargas del observatorio: data/raw/observatorio/ (no se versiona)
.ruta_obs <- function(...) {
  dir_obs <- file.path(RUTA_RAW, "observatorio")
  if (!dir.exists(dir_obs)) dir.create(dir_obs, recursive = TRUE)
  file.path(dir_obs, ...)
}

.cache_fresca <- function(ruta, dias_cache = 90) {
  file.exists(ruta) &&
    as.numeric(difftime(Sys.time(), file.info(ruta)$mtime, units = "days")) <= dias_cache
}

.user_agent_pipeline <- function() {
  httr::user_agent("GeoAlquiler-pipeline/1.0 (uso interno, contacto: pdawgabriel@gmail.com)")
}

#' Convierte un número con formato español ("1.502.436", "12,5") a numérico.
#' Los símbolos de dato no disponible ("..", "-", "") quedan como NA.
numero_es <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "..", "-", ".", "--")] <- NA_character_
  suppressWarnings(as.numeric(gsub(",", ".", gsub(".", "", x, fixed = TRUE), fixed = TRUE)))
}

#' Decodifica las entidades HTML que deja JAXI en los nombres ("l&#039;").
decodificar_html <- function(x) {
  x <- gsub("&#0*39;|&apos;", "'", x)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x
}

#' Normaliza un nombre de municipio para poder cruzar fuentes que lo escriben
#' distinto: el INE pone el artículo detrás con coma ("Acebeda, La"), el
#' Catastro entre paréntesis ("Acebeda (La)") y el IGN delante ("La
#' Acebeda"); además hay tildes, apóstrofos y nombres bilingües
#' ("Alicante/Alacant"). Devuelve una clave por cada variante del nombre (una
#' por idioma), así que el resultado es una lista de vectores.
claves_municipio <- function(nombre) {
  lapply(as.character(nombre), function(n) {
    if (is.na(n) || !nzchar(n)) return(character(0))
    variantes <- trimws(unlist(strsplit(n, "/", fixed = TRUE)))
    variantes <- c(variantes, n)
    vapply(variantes, function(v) {
      # "Acebeda (La)" / "Acebeda, La" -> "La Acebeda"
      v <- sub("^(.*?)\\s*\\(([^)]+)\\)$", "\\2 \\1", v, perl = TRUE)
      v <- sub("^(.*?),\\s*([^,]+)$", "\\2 \\1", v, perl = TRUE)
      v <- iconv(v, from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
      v <- tolower(v)
      v <- gsub("[^a-z0-9]+", "", v)
      v
    }, character(1), USE.NAMES = FALSE) |> unique()
  })
}

#' Cruza `nombres` (de una sola provincia) contra un catálogo de municipios
#' (data.frame con `cod_ine` y `nombre`) de esa misma provincia. Devuelve el
#' cod_ine de cada nombre, o NA si no hay coincidencia única.
emparejar_municipios <- function(nombres, catalogo) {
  claves_cat <- claves_municipio(catalogo$nombre)
  indice <- data.frame(
    clave = unlist(claves_cat),
    cod_ine = rep(catalogo$cod_ine, lengths(claves_cat)),
    stringsAsFactors = FALSE
  )
  indice <- unique(indice)
  # Una clave que apunta a varios municipios distintos no sirve para cruzar
  ambiguas <- indice$clave[duplicated(indice$clave)]
  indice <- indice[!indice$clave %in% ambiguas, ]

  vapply(claves_municipio(nombres), function(claves) {
    cod <- unique(indice$cod_ine[indice$clave %in% claves])
    if (length(cod) == 1) cod else NA_character_
  }, character(1))
}

# --- 1. SERPAVI (Ministerio de Vivienda) --------------------------------------

descargar_serpavi <- function() {
  ruta_zip <- .ruta_obs("serpavi_municipios.zip")
  if (!.cache_fresca(ruta_zip, dias_cache = 365)) {
    message("  [descarga] ", URL_SERPAVI_MUNICIPIOS)
    resp <- httr::GET(URL_SERPAVI_MUNICIPIOS, httr::timeout(600), .user_agent_pipeline(),
                      httr::write_disk(ruta_zip, overwrite = TRUE))
    if (httr::http_error(resp)) {
      file.remove(ruta_zip)
      stop("[SERPAVI] No se ha podido descargar ", URL_SERPAVI_MUNICIPIOS, " (HTTP ", httr::status_code(resp), ")")
    }
  } else {
    message("  [cache] serpavi_municipios.zip")
  }
  dir_shp <- .ruta_obs("serpavi_municipios")
  utils::unzip(ruta_zip, exdir = dir_shp)
  shp <- list.files(dir_shp, pattern = "\\.shp$", full.names = TRUE)
  if (length(shp) != 1) stop("[SERPAVI] El zip no contiene exactamente un .shp: ", paste(basename(shp), collapse = ", "))
  shp
}

#' Lee el shapefile municipal de SERPAVI. Los nombres de columna vienen
#' truncados a 10 caracteres por el formato DBF; aquí se traducen a nombres
#' legibles. VC = vivienda colectiva (pisos), VU = vivienda unifamiliar.
parsear_serpavi <- function(ruta_shp) {
  x <- sf::st_read(ruta_shp, quiet = TRUE)

  esperadas <- c("CodINE", "CPRO", "LITPRO", "NAMEUNIT", "Num_VC", "Renta_Medi", "Renta_Perc",
                 "Renta_Pe_1", "Cuantia_me", "Superficie", "Num_VU")
  faltan <- setdiff(esperadas, names(x))
  if (length(faltan) > 0) {
    stop("[SERPAVI] Faltan columnas esperadas en el shapefile: ", paste(faltan, collapse = ", "),
         ". Columnas encontradas: ", paste(names(x), collapse = ", "))
  }

  x <- x[!is.na(x$CodINE), ]
  # El campo de mediana de la cuantía mensual es "Cuantía_m" (con tilde); se
  # localiza por posición relativa para no depender de la codificación.
  col_cuantia_med <- grep("^Cuant.a_m$", names(x), value = TRUE)
  if (length(col_cuantia_med) != 1) stop("[SERPAVI] No se encuentra la columna de mediana de cuantía mensual (Cuantía_m)")

  cero_a_na <- function(v) ifelse(is.na(v) | v <= 0, NA_real_, v)

  sf::st_sf(
    cod_ine = x$CodINE,
    cod_provincia = x$CPRO,
    provincia = x$LITPRO,
    municipio = x$NAMEUNIT,
    alquiler_m2_mediana = cero_a_na(x$Renta_Medi),
    alquiler_m2_p25 = cero_a_na(x$Renta_Perc),
    alquiler_m2_p75 = cero_a_na(x$Renta_Pe_1),
    alquiler_mes_mediana = cero_a_na(x[[col_cuantia_med]]),
    superficie_mediana = cero_a_na(x$Superficie),
    viviendas_alquiler = x$Num_VC + x$Num_VU,
    geometry = sf::st_geometry(x)
  )
}

# --- 2. INE: renta (ADRH) ------------------------------------------------------

#' La tabla nacional del ADRH pesa ~350 MB descomprimida (incluye todas las
#' secciones censales de España). Se descarga comprimida, se filtra en
#' streaming a las filas de nivel municipio del año de referencia y se
#' cachea solo ese extracto (~1 MB).
descargar_ine_renta <- function(anio = ANIO_OBSERVATORIO) {
  ruta_cache <- .ruta_obs(paste0("ine_adrh_municipios_", anio, ".csv"))
  if (.cache_fresca(ruta_cache)) {
    message("  [cache] ", basename(ruta_cache))
    return(ruta_cache)
  }

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  message("  [descarga] ", URL_INE_ADRH_NACIONAL, " (~27 MB comprimido)")
  resp <- httr::GET(URL_INE_ADRH_NACIONAL, httr::timeout(900), .user_agent_pipeline(),
                    httr::add_headers(`Accept-Encoding` = "gzip"),
                    httr::write_disk(tmp, overwrite = TRUE))
  if (httr::http_error(resp)) stop("[INE ADRH] HTTP ", httr::status_code(resp), " al descargar ", URL_INE_ADRH_NACIONAL)

  # Fila de municipio: "28079 Madrid;;;Renta neta media por hogar;2022;46.651"
  patron <- paste0("^[0-9]{5} [^;]*;;;[^;]*;", anio, ";")
  con <- file(tmp, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE, after = FALSE)
  cabecera <- sub("^﻿", "", readLines(con, n = 1, warn = FALSE))
  if (!grepl("^Municipios;Distritos;Secciones;", cabecera)) {
    stop("[INE ADRH] Cabecera inesperada en la tabla 30824: '", cabecera, "'")
  }
  filas <- character(0)
  repeat {
    bloque <- readLines(con, n = 500000, warn = FALSE)
    if (length(bloque) == 0) break
    filas <- c(filas, bloque[grepl(patron, bloque)])
  }
  if (length(filas) == 0) stop("[INE ADRH] No hay filas de municipio para el año ", anio)

  writeLines(c(cabecera, filas), ruta_cache, useBytes = TRUE)
  ruta_cache
}

parsear_ine_renta <- function(ruta) {
  df <- utils::read.csv(ruta, sep = ";", stringsAsFactors = FALSE, encoding = "UTF-8",
                        colClasses = "character", check.names = FALSE)
  names(df)[c(1, 4, 6)] <- c("municipio", "indicador", "valor")
  df$cod_ine <- substr(df$municipio, 1, 5)
  df$valor <- numero_es(df$valor)

  ancho <- function(ind) {
    s <- df[df$indicador == ind, c("cod_ine", "valor")]
    stats::setNames(s$valor, s$cod_ine)
  }
  hogar <- ancho("Renta neta media por hogar")
  persona <- ancho("Renta neta media por persona")
  if (length(hogar) == 0) stop("[INE ADRH] No aparece el indicador 'Renta neta media por hogar'")

  codigos <- union(names(hogar), names(persona))
  data.frame(
    cod_ine = codigos,
    renta_hogar = unname(hogar[codigos]),
    renta_persona = unname(persona[codigos]),
    stringsAsFactors = FALSE
  )
}

# --- 3. INE: población (Padrón) -----------------------------------------------

descargar_ine_poblacion <- function() {
  ruta <- .ruta_obs("ine_padron_29005.csv")
  if (.cache_fresca(ruta)) {
    message("  [cache] ", basename(ruta))
    return(ruta)
  }
  message("  [descarga] ", URL_INE_PADRON)
  resp <- httr::GET(URL_INE_PADRON, httr::timeout(600), .user_agent_pipeline(),
                    httr::add_headers(`Accept-Encoding` = "gzip"),
                    httr::write_disk(ruta, overwrite = TRUE))
  if (httr::http_error(resp)) {
    file.remove(ruta)
    stop("[INE Padrón] HTTP ", httr::status_code(resp), " al descargar ", URL_INE_PADRON)
  }
  ruta
}

#' Devuelve población del año de referencia y del último año disponible,
#' además del nombre oficial del INE (que se usa como catálogo para cruzar
#' los nombres del Catastro).
parsear_ine_poblacion <- function(ruta, anio = ANIO_OBSERVATORIO) {
  df <- utils::read.csv(ruta, sep = ";", stringsAsFactors = FALSE, encoding = "UTF-8",
                        colClasses = "character", check.names = FALSE)
  names(df)[1] <- sub("^﻿", "", names(df)[1])
  if (!all(c("Municipios", "Sexo", "Periodo", "Total") %in% names(df))) {
    stop("[INE Padrón] Columnas inesperadas: ", paste(names(df), collapse = ", "))
  }
  df <- df[df$Sexo == "Total" & grepl("^[0-9]{5} ", df$Municipios), ]
  df$cod_ine <- substr(df$Municipios, 1, 5)
  df$nombre_ine <- sub("^[0-9]{5} ", "", df$Municipios)
  df$Periodo <- as.integer(df$Periodo)
  df$Total <- numero_es(df$Total)

  anio_ultimo <- max(df$Periodo, na.rm = TRUE)
  ref <- df[df$Periodo == anio, c("cod_ine", "nombre_ine", "Total")]
  ult <- df[df$Periodo == anio_ultimo, c("cod_ine", "Total")]
  names(ref)[3] <- "poblacion"
  names(ult)[2] <- "poblacion_ultima"

  out <- merge(ref, ult, by = "cod_ine", all = TRUE)
  out$anio_poblacion_ultima <- anio_ultimo
  out
}

# --- 4. Catastro --------------------------------------------------------------

#' Pide a la interfaz JAXI del Catastro una tabla municipal completa (todas
#' las filas y columnas) y devuelve el HTML. La interfaz no ofrece descarga
#' directa del .px, así que se reproduce el envío del formulario "Consultar
#' todo" con todos los valores de cada variable seleccionados.
.consultar_jaxi_catastro <- function(fichero_px, anio) {
  ruta_tabla <- paste0("/est", anio, "/catastro/urbano/")
  url_form <- paste0(URL_CATASTRO_JAXI, "?path=", ruta_tabla, "&file=", fichero_px, "&type=pcaxis&L=0")

  form <- httr::GET(url_form, httr::timeout(60), .user_agent_pipeline())
  if (httr::http_error(form)) stop("HTTP ", httr::status_code(form), " en ", url_form)
  html_form <- httr::content(form, as = "text", encoding = "ISO-8859-1")

  valores_criterio <- function(nombre) {
    bloque <- regmatches(html_form, regexpr(paste0('name="', nombre, '"[\\s\\S]*?</select>'), html_form, perl = TRUE))
    if (length(bloque) == 0) return(character(0))
    m <- regmatches(bloque, gregexpr('value="([^"]*)"', bloque))[[1]]
    sub('value="([^"]*)"', "\\1", m)
  }
  cri1 <- valores_criterio("cri1")
  cri2 <- valores_criterio("cri2")
  filas <- valores_criterio("rows")
  columnas <- valores_criterio("columns")
  if (length(cri1) == 0 || length(cri2) == 0) {
    stop("formulario JAXI sin variables seleccionables en ", url_form)
  }

  cuerpo <- c(
    stats::setNames(as.list(cri1), rep("cri1", length(cri1))),
    stats::setNames(as.list(cri2), rep("cri2", length(cri2))),
    stats::setNames(as.list(filas), rep("rows", length(filas))),
    stats::setNames(as.list(columnas), rep("columns", length(columnas))),
    list(numCri = "2", type = "pcaxis", path = ruta_tabla, file = fichero_px, accion = "html")
  )
  resp <- httr::POST(URL_CATASTRO_JAXI, body = cuerpo, encode = "form", httr::timeout(120),
                     .user_agent_pipeline(), httr::set_cookies(.cookies = httr::cookies(form)$value |>
                       stats::setNames(httr::cookies(form)$name)))
  if (httr::http_error(resp)) stop("HTTP ", httr::status_code(resp), " al consultar ", fichero_px)
  httr::content(resp, as = "text", encoding = "ISO-8859-1")
}

#' Extrae de la tabla HTML de JAXI un data.frame (municipio + una columna
#' por uso). Cada fila de datos es <td class="tableCellGr">Nombre</td>
#' seguida de N celdas <td class="dataCell">.
parsear_tabla_jaxi <- function(html) {
  limpiar <- function(s) decodificar_html(trimws(gsub("\\s+", " ", gsub("<[^>]*>", " ", s))))
  trs <- strsplit(html, "<tr[ >]", perl = TRUE)[[1]]

  cabecera <- NULL
  filas <- list()
  for (tr in trs) {
    gr <- regmatches(tr, gregexpr('<td[^>]*class="tableCellGr"[^>]*>[\\s\\S]*?</td>', tr, perl = TRUE))[[1]]
    datos <- regmatches(tr, gregexpr('<td[^>]*class="dataCell"[^>]*>[\\s\\S]*?</td>', tr, perl = TRUE))[[1]]
    if (length(datos) == 0 && length(gr) > 1 && is.null(cabecera)) {
      # La primera celda de la cabecera es la esquina vacía sobre la columna
      # de nombres de municipio
      cabecera <- limpiar(gr)
      cabecera <- cabecera[nzchar(cabecera)]
    } else if (length(datos) > 0 && length(gr) == 1) {
      filas[[length(filas) + 1]] <- c(limpiar(gr), limpiar(datos))
    }
  }
  if (is.null(cabecera) || length(filas) == 0) stop("tabla JAXI vacía o con formato inesperado")

  m <- do.call(rbind, filas)
  if (ncol(m) != length(cabecera) + 1) {
    stop("tabla JAXI con ", ncol(m) - 1, " columnas de datos pero ", length(cabecera), " cabeceras")
  }
  df <- data.frame(municipio = m[, 1], stringsAsFactors = FALSE)
  for (j in seq_along(cabecera)) df[[cabecera[j]]] <- numero_es(m[, j + 1])
  df
}

descargar_catastro <- function(anio = ANIO_OBSERVATORIO) {
  ruta_cache <- .ruta_obs(paste0("catastro_residencial_", anio, ".csv"))
  if (.cache_fresca(ruta_cache, dias_cache = 365)) {
    message("  [cache] ", basename(ruta_cache))
    return(ruta_cache)
  }

  resultado <- list()
  for (prov in PROVINCIAS_CATASTRO) {
    res <- tryCatch({
      bienes <- parsear_tabla_jaxi(.consultar_jaxi_catastro(paste0("URAO42", prov, ".px"), anio))
      valor <- parsear_tabla_jaxi(.consultar_jaxi_catastro(paste0("URBO42", prov, ".px"), anio))
      col_res <- function(df) {
        col <- grep("^Residencial$", names(df), value = TRUE)
        if (length(col) != 1) stop("sin columna 'Residencial' (columnas: ", paste(names(df), collapse = ", "), ")")
        col
      }
      b <- data.frame(municipio = bienes$municipio, inmuebles_residenciales = bienes[[col_res(bienes)]])
      v <- data.frame(municipio = valor$municipio, valor_catastral_residencial_miles = valor[[col_res(valor)]])
      out <- merge(b, v, by = "municipio", all = TRUE)
      out$cod_provincia <- prov
      out
    }, error = function(e) {
      warning("[Catastro] Provincia ", prov, ": ", conditionMessage(e))
      NULL
    })
    if (!is.null(res)) {
      message("  [Catastro] Provincia ", prov, ": ", nrow(res), " municipios")
      resultado[[prov]] <- res
    }
    Sys.sleep(0.5)  # no saturar el servidor JAXI
  }
  if (length(resultado) == 0) stop("[Catastro] No se ha podido descargar ninguna provincia")

  df <- do.call(rbind, resultado)
  utils::write.csv(df, ruta_cache, row.names = FALSE, fileEncoding = "UTF-8")
  ruta_cache
}

#' Asigna código INE a las filas del Catastro cruzando por nombre dentro de
#' cada provincia (el Catastro no publica el código INE en estas tablas).
parsear_catastro <- function(ruta, catalogo_ine) {
  df <- utils::read.csv(ruta, stringsAsFactors = FALSE, encoding = "UTF-8",
                        colClasses = c(cod_provincia = "character"))
  df$cod_provincia <- sprintf("%02d", as.integer(df$cod_provincia))
  df$municipio <- decodificar_html(df$municipio)
  df$cod_ine <- NA_character_
  for (prov in unique(df$cod_provincia)) {
    i <- df$cod_provincia == prov
    cat_prov <- catalogo_ine[substr(catalogo_ine$cod_ine, 1, 2) == prov, ]
    df$cod_ine[i] <- emparejar_municipios(df$municipio[i], cat_prov)
  }
  sin_cruce <- df[is.na(df$cod_ine), ]
  # El Catastro incluye una fila "Total" por provincia que no es un municipio
  sin_cruce <- sin_cruce[!grepl("^Total", sin_cruce$municipio), ]
  message("  [Catastro] Municipios cruzados con código INE: ", sum(!is.na(df$cod_ine)), "/",
          sum(!grepl("^Total", df$municipio)))
  if (nrow(sin_cruce) > 0) {
    message("  [Catastro] Sin cruce (", nrow(sin_cruce), "), p. ej.: ",
            paste(utils::head(paste0(sin_cruce$municipio, " (", sin_cruce$cod_provincia, ")"), 8), collapse = "; "))
  }
  df <- df[!is.na(df$cod_ine), c("cod_ine", "inmuebles_residenciales", "valor_catastral_residencial_miles")]
  df[!duplicated(df$cod_ine), ]
}

# --- 5. Cruce final ------------------------------------------------------------

#' Une las cuatro fuentes por código INE y calcula los indicadores derivados.
#' `serpavi` es un objeto sf; el resto, data.frames con `cod_ine`.
construir_observatorio <- function(serpavi, renta, poblacion, catastro) {
  base <- serpavi
  base <- merge(base, renta, by = "cod_ine", all.x = TRUE)
  base <- merge(base, poblacion[, c("cod_ine", "poblacion", "poblacion_ultima", "anio_poblacion_ultima")],
                by = "cod_ine", all.x = TRUE)
  base <- merge(base, catastro, by = "cod_ine", all.x = TRUE)

  ind <- calcular_indicadores_observatorio(sf::st_drop_geometry(base))
  for (col in setdiff(names(ind), names(base))) base[[col]] <- ind[[col]]
  base$anio_referencia <- ANIO_OBSERVATORIO
  base
}

#' Simplifica la geometría y la pasa a WGS84 + WKB, listo para guardarse en
#' Parquet y leerse en la app con observatorio_a_sf() (R/fct_observatorio.R).
#' Genera dos columnas: `geometria` (detalle) y `geometria_baja` (vista
#' nacional).
preparar_geometria <- function(obs_sf) {
  g_orig <- sf::st_transform(sf::st_geometry(obs_sf), 3857)

  simplificar <- function(tolerancia_m) {
    g <- sf::st_simplify(g_orig, preserveTopology = TRUE, dTolerance = tolerancia_m)
    g <- sf::st_make_valid(sf::st_transform(g, 4326))
    sf::st_cast(g, "MULTIPOLYGON")
  }
  g <- simplificar(TOLERANCIA_SIMPLIFICACION_M)
  g_baja <- simplificar(TOLERANCIA_SIMPLIFICACION_BAJA_M)

  # Punto interior para centrar el mapa al seleccionar un municipio
  # (calculado una vez aquí, no en cada sesión de la app)
  centro <- suppressWarnings(sf::st_coordinates(sf::st_point_on_surface(g)))

  df <- sf::st_drop_geometry(obs_sf)
  df$lng_centro <- round(centro[, "X"], 5)
  df$lat_centro <- round(centro[, "Y"], 5)
  df$geometria <- lapply(sf::st_as_binary(g, precision = 1e5), as.raw)
  df$geometria_baja <- lapply(sf::st_as_binary(g_baja, precision = 1e4), as.raw)
  df
}

generar_observatorio <- function() {
  message("== Observatorio 1/4: SERPAVI por municipio (Ministerio de Vivienda) ==")
  serpavi <- parsear_serpavi(descargar_serpavi())
  message("  Municipios en SERPAVI: ", nrow(serpavi), " (con mediana de alquiler: ",
          sum(!is.na(serpavi$alquiler_m2_mediana)), ")")

  message("== Observatorio 2/4: renta media por hogar (INE, ADRH ", ANIO_OBSERVATORIO, ") ==")
  renta <- parsear_ine_renta(descargar_ine_renta())
  message("  Municipios con renta: ", sum(!is.na(renta$renta_hogar)))

  message("== Observatorio 3/4: población (INE, Padrón) ==")
  poblacion <- parsear_ine_poblacion(descargar_ine_poblacion())
  message("  Municipios con población ", ANIO_OBSERVATORIO, ": ", sum(!is.na(poblacion$poblacion)))

  message("== Observatorio 4/4: parque residencial (Catastro ", ANIO_OBSERVATORIO, ") ==")
  # Catálogo de nombres para cruzar el Catastro: el nombre oficial del INE y,
  # como alternativa, el del IGN que trae SERPAVI (a veces uno usa la forma
  # castellana y otro la valenciana/catalana/gallega, p. ej. Adsubia/Atzúbia).
  catalogo <- rbind(
    data.frame(cod_ine = poblacion$cod_ine, nombre = poblacion$nombre_ine),
    data.frame(cod_ine = serpavi$cod_ine, nombre = serpavi$municipio)
  )
  catalogo <- unique(catalogo[!is.na(catalogo$nombre), ])
  catastro <- parsear_catastro(descargar_catastro(), catalogo)

  message("== Cruzando fuentes y simplificando geometría ==")
  obs <- construir_observatorio(serpavi, renta, poblacion, catastro)
  obs <- preparar_geometria(obs)

  message("  Municipios en el observatorio: ", nrow(obs))
  message("    con alquiler (SERPAVI): ", sum(!is.na(obs$alquiler_m2_mediana)))
  message("    con renta (INE):        ", sum(!is.na(obs$renta_hogar)))
  message("    con población (INE):    ", sum(!is.na(obs$poblacion)))
  message("    con Catastro:           ", sum(!is.na(obs$inmuebles_residenciales)))
  obs
}
