# Lógica de negocio del Observatorio del Alquiler (sin dependencias de Shiny).
# La usan tanto el módulo mod_observatorio.R como el pipeline de ingesta
# (scripts/ingesta/09_observatorio.R), y se prueba en
# tests/testthat/test_observatorio.R.

#' Indicadores derivados del cruce SERPAVI + INE + Catastro
#'
#' Recibe una tabla municipal con las columnas de origen y devuelve la misma
#' tabla con los indicadores calculados. Cualquier división entre un dato
#' ausente o nulo devuelve NA (nunca Inf ni 0), para que el mapa lo pinte
#' como "sin dato" en vez de como un extremo de la escala.
#' @noRd
calcular_indicadores_observatorio <- function(df) {
  div <- function(a, b) ifelse(!is.na(a) & !is.na(b) & b > 0, a / b, NA_real_)

  # % de la renta neta anual de un hogar medio que se iría en pagar el
  # alquiler mediano del municipio (12 mensualidades).
  df$esfuerzo_alquiler_pct <- round(100 * div(12 * df$alquiler_mes_mediana, df$renta_hogar), 1)

  df$crecimiento_poblacion_pct <- round(100 * (div(df$poblacion_ultima, df$poblacion) - 1), 2)

  # Viviendas con alquiler declarado (IRPF) sobre el parque residencial del
  # Catastro. Es una aproximación al peso del alquiler: SERPAVI no incluye
  # alquileres no declarados.
  df$pct_viviendas_alquiler <- round(100 * div(df$viviendas_alquiler, df$inmuebles_residenciales), 1)

  df$valor_catastral_medio <- round(div(1000 * df$valor_catastral_residencial_miles, df$inmuebles_residenciales))

  df$viviendas_por_1000_hab <- round(1000 * div(df$inmuebles_residenciales, df$poblacion), 1)

  df
}

#' Catálogo de indicadores que se pueden representar en el mapa
#'
#' `sentido` indica qué extremo de la escala es "peor" para quien busca
#' alquiler: 1 = cuanto más alto, más tensión (rojo); 0 = neutro.
#' @noRd
indicadores_observatorio <- function() {
  data.frame(
    id = c("alquiler_m2_mediana", "alquiler_mes_mediana", "esfuerzo_alquiler_pct", "renta_hogar",
           "pct_viviendas_alquiler", "valor_catastral_medio", "poblacion", "crecimiento_poblacion_pct"),
    etiqueta = c("Alquiler mediano (€/m²)", "Alquiler mediano (€/mes)", "Esfuerzo de alquiler (% renta)",
                 "Renta neta media por hogar (€)", "Viviendas en alquiler (% del parque)",
                 "Valor catastral medio por inmueble residencial (€)", "Población",
                 "Crecimiento de población (%)"),
    fuente = c("SERPAVI", "SERPAVI", "SERPAVI + INE", "INE (ADRH)", "SERPAVI + Catastro",
               "Catastro", "INE (Padrón)", "INE (Padrón)"),
    sufijo = c(" €/m²", " €", " %", " €", " %", " €", "", " %"),
    decimales = c(2, 0, 1, 0, 1, 0, 0, 2),
    sentido = c(1, 1, 1, 0, 0, 0, 0, 0),
    stringsAsFactors = FALSE
  )
}

#' Formatea un valor de un indicador con su unidad (formato español)
#' @noRd
formatear_indicador <- function(valor, id) {
  cat_ind <- indicadores_observatorio()
  fila <- cat_ind[cat_ind$id == id, ]
  if (nrow(fila) != 1) stop("Indicador desconocido: ", id)
  ifelse(
    is.na(valor),
    "s/d",
    paste0(
      formatC(valor, format = "f", digits = fila$decimales, big.mark = ".", decimal.mark = ","),
      fila$sufijo
    )
  )
}

#' Por qué un municipio no tiene dato en un indicador
#'
#' En el observatorio un dato ausente casi nunca es un error: cada fuente
#' deja fuera municipios por motivos distintos. La ficha muestra este texto
#' junto al "s/d" para que no parezca un fallo de la app. Devuelve NULL si
#' el valor no falta.
#' @noRd
motivo_sin_dato <- function(fila, id) {
  if (!is.na(fila[[id]])) return(NULL)

  foral <- substr(fila$cod_ine, 1, 2) %in% c("01", "20", "31", "48")
  sin_alquiler <- is.na(fila$alquiler_m2_mediana)
  sin_renta <- is.na(fila$renta_hogar)
  sin_catastro <- is.na(fila$inmuebles_residenciales)

  motivo_foral <- "País Vasco y Navarra no están en SERPAVI ni en el Catastro estatal (régimen foral)"
  motivo_alquiler <- "SERPAVI no publica la mediana: muy pocos contratos de alquiler declarados"
  motivo_renta <- "el INE no publica la renta de municipios tan pequeños (secreto estadístico)"
  motivo_catastro <- "sin estadística del Catastro para este municipio"

  switch(
    id,
    alquiler_m2_mediana = ,
    alquiler_mes_mediana = if (foral) motivo_foral else motivo_alquiler,
    esfuerzo_alquiler_pct = if (foral) motivo_foral else if (sin_alquiler) motivo_alquiler else motivo_renta,
    renta_hogar = motivo_renta,
    pct_viviendas_alquiler = ,
    valor_catastral_medio = if (foral) motivo_foral else if (sin_catastro) motivo_catastro else "sin dato",
    poblacion = ,
    crecimiento_poblacion_pct = "sin cifra oficial del padrón para este municipio",
    "sin dato"
  )
}

#' Cortes por cuantiles para la escala de color del mapa
#'
#' Una escala lineal se "comería" casi todo el mapa con el mismo color, porque
#' unos pocos municipios (Madrid, Barcelona, costa balear) tiran del máximo.
#' Con cuantiles cada color agrupa un número parecido de municipios. Si hay
#' muchos valores repetidos los cortes se deduplican, así que puede haber
#' menos clases de las pedidas.
#' @noRd
cortes_cuantiles <- function(x, n_clases = 7) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NULL)
  cortes <- unique(stats::quantile(x, probs = seq(0, 1, length.out = n_clases + 1), names = FALSE, type = 7))
  if (length(cortes) < 2) cortes <- c(min(x) - 0.5, max(x) + 0.5)
  cortes
}

#' Reconstruye un objeto sf a partir de la tabla del observatorio guardada
#' en Parquet. La geometría viene en WKB en dos niveles de detalle
#' (`geometria` y `geometria_baja`, ver scripts/ingesta/09_observatorio.R);
#' `columna` elige cuál usar y el resto de columnas WKB se descartan.
#' @noRd
observatorio_a_sf <- function(df, columna = "geometria") {
  wkb <- df[[columna]]
  if (is.null(wkb)) stop("La tabla del observatorio no tiene la columna de geometría '", columna, "'")
  geom <- sf::st_as_sfc(structure(lapply(as.list(wkb), as.raw), class = "WKB"), crs = 4326)
  df <- as.data.frame(df)
  df[intersect(c("geometria", "geometria_baja"), names(df))] <- NULL
  sf::st_sf(df, geometry = geom)
}

#' Geometría (MULTIPOLYGON) a JSON en el formato que espera addPolygons() de
#' leaflet: un elemento por municipio, con sus polígonos y, en cada uno, sus
#' anillos como {"lng": [...], "lat": [...]}.
#'
#' Es el mismo JSON que saldría de leaflet() %>% addPolygons(data = g) y
#' jsonlite::toJSON(), pero generado directamente desde st_coordinates() con
#' operaciones vectorizadas: para los ~8.000 municipios de España tarda
#' menos de 1 s, frente a ~6 s por el camino estándar (que construye y
#' serializa cientos de miles de listas anidadas). Devuelve un objeto de
#' clase "json", que shiny inserta tal cual en el mensaje.
#' @noRd
geometria_a_json_leaflet <- function(g, decimales = 5) {
  g <- sf::st_cast(sf::st_geometry(g), "MULTIPOLYGON")
  co <- sf::st_coordinates(g)
  # L1 = anillo dentro del polígono, L2 = polígono dentro del multipolígono,
  # L3 = municipio. st_coordinates() los devuelve ya ordenados.
  num <- function(x) as.character(round(x, decimales))
  anillo <- paste(co[, "L3"], co[, "L2"], co[, "L1"], sep = "_")
  anillo <- factor(anillo, levels = unique(anillo))
  lng <- vapply(split(num(co[, "X"]), anillo), paste, character(1), collapse = ",")
  lat <- vapply(split(num(co[, "Y"]), anillo), paste, character(1), collapse = ",")
  json_anillo <- paste0('{"lng":[', lng, '],"lat":[', lat, ']}')

  primera <- !duplicated(anillo)
  poligono <- paste(co[primera, "L3"], co[primera, "L2"], sep = "_")
  poligono <- factor(poligono, levels = unique(poligono))
  json_poligono <- vapply(split(json_anillo, poligono), function(x) paste0("[", paste(x, collapse = ","), "]"), character(1))

  municipio <- factor(co[primera, "L3"][!duplicated(poligono)], levels = seq_along(g))
  json_municipio <- vapply(split(json_poligono, municipio), function(x) paste0("[", paste(x, collapse = ","), "]"), character(1))

  structure(paste0("[", paste(json_municipio, collapse = ","), "]"), class = "json")
}

#' Prepara la tabla del observatorio para la app: la convierte a sf en sus
#' dos niveles de detalle y crea la caché de geometría serializada por ámbito.
#' Se hace una vez por proceso (ver cargar_observatorio()), no en cada sesión.
#' @noRd
preparar_observatorio <- function(df) {
  detalle <- observatorio_a_sf(df, "geometria")
  structure(
    list(
      detalle = detalle,
      nacional = observatorio_a_sf(df, "geometria_baja"),
      tabla = sf::st_drop_geometry(detalle),
      json = new.env(parent = emptyenv())
    ),
    class = "observatorio_preparado"
  )
}

#' Geometría de un ámbito en JSON para leaflet, cacheada en el objeto
#' preparado: solo la primera sesión que abre cada ámbito la genera.
#' @noRd
geometria_ambito_json <- function(obs, ambito, poligonos_sf) {
  if (is.null(obs$json[[ambito]])) obs$json[[ambito]] <- geometria_a_json_leaflet(poligonos_sf)
  obs$json[[ambito]]
}

.observatorios_cargados <- new.env(parent = emptyenv())

#' Lee y prepara observatorio_municipios.parquet una sola vez por proceso
#' (en shinyapps.io, un proceso atiende muchas sesiones). Devuelve NULL si
#' el fichero no existe.
#' @noRd
cargar_observatorio <- function(ruta) {
  if (!file.exists(ruta)) return(NULL)
  if (is.null(.observatorios_cargados[[ruta]])) {
    .observatorios_cargados[[ruta]] <- preparar_observatorio(arrow::read_parquet(ruta))
  }
  .observatorios_cargados[[ruta]]
}
