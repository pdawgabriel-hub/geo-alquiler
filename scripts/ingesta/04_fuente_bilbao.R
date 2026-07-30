# scripts/ingesta/04_fuente_bilbao.R
#
# Bilbao: "Informe EMAL" (Encuesta del Mercado de Alquiler), publicado
# trimestralmente por Etxebide (Gobierno Vasco) a partir de las FIANZAS DE
# ALQUILER depositadas -- dato real de contratos vigentes, con desglose
# real por BARRIO y una columna de "Renta por m² construido" ya calculada
# por la propia fuente (a diferencia de Barcelona/Valencia, aquí NO hace
# falta aproximar €/m² a partir de una renta total: el dato ya viene en €/m²).
#
# El informe se publica como PDF (no hay CSV/XLSX a nivel de barrio), así
# que este script lo descarga y extrae el texto con `pdftotext` (paquete
# del sistema `poppler-utils`) para parsear la tabla "Información por
# barrios y distritos". Verificado a mano con el informe de 2025T2 real.
#
# LIMITACIÓN CONOCIDA: la URL del PDF incluye el trimestre en el propio
# nombre de fichero (ej. ".../122417_informe_emal_2025t2/..."), así que se
# quedará desactualizada cuando Etxebide publique el siguiente trimestre.
# Igual que con SERPAVI, si esta URL deja de funcionar, descarga el informe
# trimestral más reciente a mano desde etxebide.euskadi.eus y guárdalo como
# 'data/raw/bilbao_manual.pdf' antes de repetir.

URL_PDF_BILBAO <- paste0(
  "https://www.etxebide.euskadi.eus/contenidos/documentacion/",
  "122417_informe_emal_2025t2/es_def/Informe-EMAL-trimestral-062025.pdf"
)

descargar_bilbao <- function() {
  ruta_manual <- file.path(RUTA_RAW, "bilbao_manual.pdf")
  if (file.exists(ruta_manual)) {
    message("  [Bilbao] Usando fichero descargado manualmente: ", ruta_manual)
    return(ruta_manual)
  }
  descargar_con_cache(URL_PDF_BILBAO, "bilbao_emal_etxebide.pdf", dias_cache = 90)
}

# Una fila de barrio en el PDF (extraído con `pdftotext -layout`) tiene esta
# forma real (código, nombre, nº fianzas, % sobre Bilbao, renta media €,
# diferencial %, renta media €/m², diferencial %):
#   "   101                      San Ignacio        505          3,18             870,4           0,55             11,4             -5,78"
# Los barrios con muy pocos contratos no publican precio (solo 2 números) y
# se descartan automáticamente porque no coinciden con el patrón de 6 cifras.
PATRON_FILA_BARRIO <- paste0(
  "^\\s*(\\d{3})\\s+(.+?)\\s{2,}",   # código + nombre
  "([\\d.]+)\\s+",                   # nº de fianzas
  "(-?[\\d,]+)\\s+",                 # % sobre el total de Bilbao
  "([\\d.,]+)\\s+",                  # renta media (€/mes)
  "(-?[\\d,]+)\\s+",                 # diferencial renta media (%)
  "([\\d.,]+)\\s+",                  # renta media por m² (€/m²) <- el dato que usamos
  "(-?[\\d,]+)\\s*$"                 # diferencial €/m² (%)
)


# Números en formato español: "." separa miles, "," separa decimales (ej.
# "1.126,1" = 1126.1). Hay que quitar primero los puntos de millar y SOLO
# DESPUÉS convertir la coma decimal en punto -- al revés, "11,4" se
# convertiría primero en "11.4" y luego, al quitar el punto, en "114".
.coma_a_numero <- function(x) suppressWarnings(as.numeric(gsub(",", ".", gsub("\\.", "", x))))

parsear_bilbao <- function(ruta_pdf) {
  if (is.null(ruta_pdf) || length(ruta_pdf) == 0 || is.na(ruta_pdf) || !file.exists(ruta_pdf)) {
    warning("[Bilbao] No hay fichero que parsear. Se omite esta fuente.")
    return(NULL)
  }

  if (Sys.which("pdftotext") == "") {
    warning(
      "[Bilbao] No se ha encontrado 'pdftotext' en el sistema (paquete poppler-utils). ",
      "Instálalo (Linux: sudo apt install poppler-utils) para poder leer el informe EMAL. Se omite esta fuente."
    )
    return(NULL)
  }

  lineas <- tryCatch(
    system2("pdftotext", args = c("-layout", shQuote(ruta_pdf), "-"), stdout = TRUE, stderr = FALSE),
    error = function(e) NULL
  )

  if (is.null(lineas) || length(lineas) == 0) {
    warning("[Bilbao] pdftotext no ha devuelto texto para '", ruta_pdf, "'. Se omite esta fuente.")
    return(NULL)
  }

  # El informe repite la misma sección "Información por barrios y distritos"
  # una vez por cada capital vasca (Vitoria-Gasteiz, Bilbao, Donostia/San
  # Sebastián). Para saber cuál de las repeticiones es la de Bilbao, no basta
  # con la posición -- se busca la que menciona "Bilbao" explícitamente en
  # las 10 líneas siguientes (la cabecera de la tabla repite el nombre de la
  # ciudad varias veces: "Fianzas Bilbao", "precio medio Bilbao", etc.).
  secciones <- which(grepl("Información por barrios y distritos", lineas))
  if (length(secciones) == 0) {
    stop(
      "[Bilbao] No se ha encontrado ninguna sección 'Información por barrios y distritos' en el PDF.\n",
      "  Puede que Etxebide haya cambiado el formato del informe -- revisa el PDF a mano y ",
      "ajusta scripts/ingesta/04_fuente_bilbao.R."
    )
  }

  es_seccion_bilbao <- vapply(secciones, function(i) {
    ventana <- lineas[i:min(i + 10, length(lineas))]
    any(grepl("Bilbao", ventana))
  }, logical(1))

  if (!any(es_seccion_bilbao)) {
    stop(
      "[Bilbao] Ninguna de las secciones 'Información por barrios y distritos' menciona 'Bilbao' ",
      "en su cabecera. Puede que Etxebide haya cambiado el formato del informe -- revisa el PDF a mano."
    )
  }

  seccion_bilbao <- secciones[which(es_seccion_bilbao)[1]]
  siguiente_seccion <- secciones[secciones > seccion_bilbao][1]
  if (is.na(siguiente_seccion)) siguiente_seccion <- length(lineas)

  fila_inicio <- which(grepl("^\\s*Barrio\\s*$", lineas[seccion_bilbao:siguiente_seccion]))
  if (length(fila_inicio) == 0) {
    stop(
      "[Bilbao] No se ha encontrado la sub-sección 'Barrio' dentro del bloque de Bilbao.\n",
      "  Puede que Etxebide haya cambiado el formato del informe -- revisa el PDF a mano y ",
      "ajusta scripts/ingesta/04_fuente_bilbao.R."
    )
  }
  fila_inicio <- seccion_bilbao + fila_inicio[1] - 1

  fila_fin <- which(grepl("^\\s*x:\\s*No disponible", lineas))
  fila_fin <- fila_fin[fila_fin > fila_inicio][1]
  if (is.na(fila_fin) || fila_fin > siguiente_seccion) fila_fin <- siguiente_seccion

  bloque <- lineas[(fila_inicio + 1):(fila_fin - 1)]
  coincidencias <- regmatches(bloque, regexec(PATRON_FILA_BARRIO, bloque, perl = TRUE))
  coincidencias <- coincidencias[lengths(coincidencias) > 0]

  if (length(coincidencias) == 0) {
    warning("[Bilbao] No se ha podido extraer ningún barrio del PDF con el patrón esperado. Se omite esta fuente.")
    return(NULL)
  }

  # regexec numera: m[1]=match completo, m[2]=código, m[3]=nombre,
  # m[4]=nº fianzas, m[5]=% sobre Bilbao, m[6]=renta media €,
  # m[7]=diferencial renta media, m[8]=renta media €/m² (el que usamos),
  # m[9]=diferencial €/m².
  barrios     <- vapply(coincidencias, function(m) trimws(m[3]), character(1))
  precio_m2   <- vapply(coincidencias, function(m) .coma_a_numero(m[8]), numeric(1))

  valido <- nzchar(barrios) & !is.na(precio_m2)

  data.frame(
    zona      = barrios[valido],
    precio_m2 = precio_m2[valido],
    fuente    = "Gobierno Vasco (Etxebide) -- Informe EMAL trimestral, fianzas de alquiler vigentes",
    stringsAsFactors = FALSE
  )
}
