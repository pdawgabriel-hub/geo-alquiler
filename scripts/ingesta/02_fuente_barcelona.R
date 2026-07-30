# scripts/ingesta/02_fuente_barcelona.R
#
# Barcelona: renta mitjana contractual de lloguer per barri, publicada per la
# Generalitat de Catalunya a partir de les FIANCES DE LLOGUER dipositades a
# l'INCASÒL (dato real de contratos, no encuesta ni índice de portal).
#
# URL y estructura verificadas DE VERDAD (descarga real + inspección con
# readxl, no solo un enlace citado): es un Excel "pivotado", no una tabla
# tidy. Estructura real del fichero (hoja única "Lloguer_BCN"):
#   fila 5: cabecera con años en columnas (col 3 = año más reciente)
#   fila 6: total Barcelona ciudad
#   fila 8: cabecera "Districtes municipals"
#   filas 9-18: un districte por fila (código, nombre, renta por año)
#   fila 20: cabecera "Barris"
#   filas 21-93: un barri por fila (código, nombre, renta por año)
#   filas siguientes: notas al pie (empiezan por "(" o están vacías)
#
# El valor publicado es "lloguer mitjà contractual (EUROS/mes)" -- renta
# MEDIA MENSUAL TOTAL, no €/m². Como el resto del pipeline trabaja en €/m²
# (ver 08_generar_anuncios.R), se deriva un €/m² aproximado dividiendo por
# una superficie media de referencia documentada abajo. Es una aproximación
# real pero no exacta: la fuente no publica superficie media por barrio.

URL_EXCEL_BARCELONA <- paste0(
  "https://habitatge.gencat.cat/web/.content/home/dades/estadistiques/",
  "01_Estadistiques_de_construccio_i_mercat_immobiliari/03_Mercat_de_lloguer/",
  "03_Lloguers_Barcelona_per_districtes_i_barris/anual_bcn_lloguer.xlsx"
)

# Superficie media de referencia para derivar €/m² a partir de una renta
# media total (mismo valor medio que usa 08_generar_anuncios.R al generar la
# superficie de cada anuncio, para que ambos lados sean coherentes entre sí).
SUPERFICIE_MEDIA_REFERENCIA <- 80

descargar_barcelona <- function() {
  descargar_con_cache(URL_EXCEL_BARCELONA, "barcelona_lloguer_incasol.xlsx", dias_cache = 90)
}

parsear_barcelona <- function(ruta_excel) {
  if (is.null(ruta_excel) || length(ruta_excel) == 0 || is.na(ruta_excel) || !file.exists(ruta_excel)) {
    warning("[Barcelona] No hay fichero que parsear. Se omite esta fuente.")
    return(NULL)
  }

  hojas <- readxl::excel_sheets(ruta_excel)
  if (length(hojas) == 0) {
    warning("[Barcelona] El Excel no tiene hojas. Se omite esta fuente.")
    return(NULL)
  }

  df <- suppressMessages(as.data.frame(
    readxl::read_excel(ruta_excel, sheet = hojas[1], col_names = FALSE)
  ))

  fila_barris <- which(grepl("(?i)^barris", trimws(df[[2]]), perl = TRUE))
  if (length(fila_barris) == 0) {
    stop(
      "[Barcelona] No se ha encontrado la sección 'Barris' en '", ruta_excel, "'.\n",
      "  Puede que la Generalitat haya cambiado el formato del fichero -- ábrelo a mano y ",
      "ajusta scripts/ingesta/02_fuente_barcelona.R."
    )
  }

  inicio <- fila_barris[1] + 1
  # La sección de barrios termina en la primera fila sin nombre de barrio
  # (columna 2 vacía) o que empiece por "(" (nota al pie / fuente).
  fin <- inicio
  while (fin <= nrow(df) &&
         !is.na(df[[2]][fin]) &&
         nzchar(trimws(df[[2]][fin])) &&
         !grepl("^\\(", trimws(df[[2]][fin]))) {
    fin <- fin + 1
  }
  fin <- fin - 1

  if (fin < inicio) {
    warning("[Barcelona] La sección 'Barris' aparece vacía. Se omite esta fuente.")
    return(NULL)
  }

  barris <- trimws(df[[2]][inicio:fin])
  precio_mensual <- suppressWarnings(as.numeric(df[[3]][inicio:fin]))

  valido <- !is.na(barris) & nzchar(barris) & !is.na(precio_mensual)

  data.frame(
    zona      = barris[valido],
    precio_m2 = round(precio_mensual[valido] / SUPERFICIE_MEDIA_REFERENCIA, 2),
    fuente    = paste0(
      "Generalitat de Catalunya (INCASÒL) -- fiances de lloguer, ",
      "€/m² estimado a partir de la renta media (", SUPERFICIE_MEDIA_REFERENCIA, " m² de referencia)"
    ),
    stringsAsFactors = FALSE
  )
}
