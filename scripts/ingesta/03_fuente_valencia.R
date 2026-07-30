# scripts/ingesta/03_fuente_valencia.R
#
# Valencia: registro real de FIANZAS DE ALQUILER depositadas, publicado por
# la Generalitat Valenciana en su portal de datos abiertos (dadesobertes.gva.es).
# Es un registro de depósitos individuales (una fila = una fianza), no un
# índice de portal inmobiliario -- dato real y verificado por descarga.
#
# URL y estructura verificadas DE VERDAD (descarga real, no un enlace citado):
# CSV con separador ';' y columnas
#   anyo_datos; cod_provincia; provincia; cod_municipio; municipio; cp; importe_fianza; devuelta
# `provincia` es la PROVINCIA (ej. "VALENCIA" para toda la provincia), NO el
# municipio -- hay que filtrar por la columna `municipio`, no por `provincia`.
#
# En España la fianza legal de un alquiler de vivienda sin amueblar equivale
# a UNA mensualidad de renta (LAU art. 36), así que `importe_fianza` es un
# proxy real y directo de la renta mensual -- no absoluto, no €/m² (la fuente
# no publica superficie), así que se deriva €/m² igual que en Barcelona,
# dividiendo por una superficie de referencia.
#
# El CSV trae `cp` (código postal) por depósito, con volumen real de muestra
# por CP dentro de Valencia capital (150-350+ depósitos por CP, verificado).
# Se usa como "barrio" -- Valencia no tiene un desglose por barrio con nombre
# en ninguna fuente oficial, pero el código postal SÍ da dispersión real
# dentro de la ciudad (equivalente a lo que aportan barrio/districte en
# Barcelona/Bilbao), en vez de un único número para todo el municipio.
MIN_MUESTRAS_POR_CP <- 30

URL_CSV_VALENCIA <- paste0(
  "https://dadesobertes.gva.es/dataset/616eec66-ccd8-493c-bcaf-1e6a51717903/",
  "resource/b7253c3d-2c7e-47df-b701-d663d2363902/download/fianzas-depositadas-por-municipio.csv"
)

# Mismo valor de referencia que usa 02_fuente_barcelona.R (y que usa
# 08_generar_anuncios.R al generar la superficie de cada anuncio), para
# derivar €/m² de forma coherente con el resto del pipeline.
SUPERFICIE_MEDIA_REFERENCIA_VLC <- 80

descargar_valencia <- function() {
  descargar_con_cache(URL_CSV_VALENCIA, "valencia_fianzas_gva.csv", dias_cache = 30, binario = FALSE)
}

parsear_valencia <- function(ruta_csv) {
  if (is.null(ruta_csv) || length(ruta_csv) == 0 || is.na(ruta_csv) || !file.exists(ruta_csv)) {
    warning("[Valencia] No hay fichero que parsear. Se omite esta fuente.")
    return(NULL)
  }

  df <- utils::read.csv(ruta_csv, sep = ";", stringsAsFactors = FALSE, encoding = "UTF-8")

  columnas_esperadas <- c("municipio", "importe_fianza")
  if (!all(columnas_esperadas %in% names(df))) {
    stop(
      "[Valencia] El CSV de fianzas no tiene las columnas esperadas (", paste(columnas_esperadas, collapse = ", "), ").\n",
      "  Columnas encontradas: ", paste(names(df), collapse = " | "), "\n",
      "  Puede que la GVA haya cambiado el formato -- ajusta scripts/ingesta/03_fuente_valencia.R."
    )
  }

  # Filtro robusto ante mayúsculas/acentos/espacios en el nombre de municipio
  es_valencia_capital <- toupper(trimws(df$municipio)) == "VALENCIA"
  df_vlc <- df[es_valencia_capital, ]

  if (nrow(df_vlc) == 0) {
    warning(
      "[Valencia] Ninguna fila con municipio == 'VALENCIA' en '", ruta_csv, "'. ",
      "Ejemplos de municipios encontrados: ", paste(utils::head(unique(df$municipio), 5), collapse = ", ")
    )
    return(NULL)
  }

  df_vlc$importe_fianza <- suppressWarnings(as.numeric(df_vlc$importe_fianza))
  df_vlc$cp <- trimws(df_vlc$cp)

  agg <- stats::aggregate(
    importe_fianza ~ cp, data = df_vlc,
    FUN = function(x) c(media = mean(x, na.rm = TRUE), n = length(x))
  )
  n_por_cp <- vapply(agg$importe_fianza[, "n"], identity, numeric(1))
  agg <- agg[n_por_cp >= MIN_MUESTRAS_POR_CP, ]

  if (nrow(agg) == 0) {
    warning("[Valencia] Ningún código postal alcanza el mínimo de ", MIN_MUESTRAS_POR_CP, " depósitos. Se omite esta fuente.")
    return(NULL)
  }

  data.frame(
    zona      = paste("CP", agg$cp),
    precio_m2 = round(agg$importe_fianza[, "media"] / SUPERFICIE_MEDIA_REFERENCIA_VLC, 2),
    fuente    = paste0(
      "Generalitat Valenciana -- fianzas de alquiler depositadas (n=", round(agg$importe_fianza[, "n"]), " por CP), ",
      "€/m² estimado a partir de la fianza media (", SUPERFICIE_MEDIA_REFERENCIA_VLC, " m² de referencia)"
    ),
    stringsAsFactors = FALSE
  )
}
