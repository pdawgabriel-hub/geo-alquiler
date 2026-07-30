# scripts/ingesta/05_anclas_manuales.R
#
# Carga data/raw/anclas_manuales.csv: precios/m² fijados A MANO para zonas o
# municipios de MUNICIPIOS_OBJETIVO (ver 00_config.R) donde no existe ninguna
# fuente oficial automatizable. Este fichero es DATOS DEL PROYECTO, no caché
# de descarga -- se mantiene en el repositorio y se actualiza a mano cuando
# toque revisar los precios (ver columna `nota` de cada fila). Puede estar
# vacío (solo cabecera) si todos los municipios objetivo tienen fuente
# oficial -- es el caso normal cuando la app está centrada en grandes
# ciudades con SERPAVI/portales municipales.

RUTA_ANCLAS_MANUALES <- file.path(RUTA_RAW, "anclas_manuales.csv")

cargar_anclas_manuales <- function() {
  if (!file.exists(RUTA_ANCLAS_MANUALES)) {
    warning("[Anclas manuales] No existe ", RUTA_ANCLAS_MANUALES, ". Se omite esta fuente.")
    return(NULL)
  }

  df <- utils::read.csv(RUTA_ANCLAS_MANUALES, sep = ";", stringsAsFactors = FALSE, encoding = "UTF-8")

  if (nrow(df) == 0) {
    message("  [Anclas manuales] ", RUTA_ANCLAS_MANUALES, " no tiene filas todavía. Se omite esta fuente.")
    return(NULL)
  }

  df$zona <- ifelse(trimws(df$zona) == "", NA_character_, df$zona)

  if (any(grepl("(?i)pendiente de verificar", df$nota, perl = TRUE))) {
    filas_pendientes <- df[grepl("(?i)pendiente de verificar", df$nota, perl = TRUE), c("ciudad", "zona")]
    message(
      "  [Anclas manuales] Aviso: hay ", nrow(filas_pendientes), " fila(s) marcada(s) como PENDIENTE DE VERIFICAR ",
      "(", paste(paste0(filas_pendientes$ciudad, ifelse(is.na(filas_pendientes$zona), "", paste0(" / ", filas_pendientes$zona))), collapse = ", "), "). ",
      "Revisa data/raw/anclas_manuales.csv antes de presentar esos datos como definitivos."
    )
  }

  data.frame(
    ciudad    = df$ciudad,
    zona      = df$zona,
    distrito  = NA_character_,
    precio_m2 = suppressWarnings(as.numeric(df$precio_m2)),
    fuente    = df$fuente,
    fecha_dato = df$fecha_dato,
    stringsAsFactors = FALSE
  )
}
