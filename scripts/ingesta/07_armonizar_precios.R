# scripts/ingesta/07_armonizar_precios.R
#
# Combina las distintas fuentes ya parseadas (Barcelona, Valencia, Bilbao,
# anclas manuales) en una única tabla "precios_zona" con el mismo esquema de
# columnas, sea cual sea el origen de cada fila:
#
#   ciudad | zona | nivel_geo | precio_m2 | n_muestras | fuente | fecha_dato | es_estimado
#
# A diferencia de una versión anterior de este pipeline, ya NO hay que
# resolver conflictos de prioridad entre fuentes: cada ciudad objetivo tiene
# exactamente UNA fuente dedicada (ver 00_config.R), así que cada parser solo
# aporta filas de su propia ciudad. Las anclas manuales se usan únicamente
# para rellenar los municipios que se han quedado sin ninguna fila (porque no
# existe fuente oficial automatizable, ej. Madrid/Sevilla) o para zonas
# concretas listadas en ZONAS_SIN_FUENTE_OFICIAL.
#
# `es_estimado = TRUE` marca las filas que NO vienen de una fuente oficial
# (es decir, las de anclas_manuales.csv) -- la app debe dejar claro al
# usuario cuáles son estas, en vez de presentarlas con la misma confianza
# que un dato oficial.

.normalizar_municipal <- function(df_municipal, ciudad, nivel_geo) {
  if (is.null(df_municipal) || nrow(df_municipal) == 0) return(NULL)

  data.frame(
    ciudad     = ciudad,
    zona       = df_municipal$zona,
    nivel_geo  = nivel_geo,
    precio_m2  = df_municipal$precio_m2,
    n_muestras = NA_real_,
    fuente     = df_municipal$fuente,
    fecha_dato = NA_character_,
    es_estimado = FALSE,
    stringsAsFactors = FALSE
  )
}

.normalizar_anclas <- function(df_anclas) {
  if (is.null(df_anclas) || nrow(df_anclas) == 0) return(NULL)

  data.frame(
    ciudad     = df_anclas$ciudad,
    zona       = df_anclas$zona,
    nivel_geo  = ifelse(is.na(df_anclas$zona), "municipio", "zona_sin_fuente_oficial"),
    precio_m2  = df_anclas$precio_m2,
    n_muestras = NA_real_,
    fuente     = df_anclas$fuente,
    fecha_dato = df_anclas$fecha_dato,
    es_estimado = TRUE,
    stringsAsFactors = FALSE
  )
}

#' Combina todas las fuentes ya parseadas en la tabla final de precios/m² por
#' zona: cada ciudad aporta sus propias filas desde su fuente dedicada, y las
#' anclas manuales solo rellenan huecos (municipios sin fuente oficial, o
#' zonas listadas en ZONAS_SIN_FUENTE_OFICIAL).
#'
#' @param barcelona_df resultado de parsear_barcelona() (o NULL).
#' @param valencia_df resultado de parsear_valencia() (o NULL).
#' @param bilbao_df resultado de parsear_bilbao() (o NULL).
#' @param anclas_df resultado de cargar_anclas_manuales() (o NULL).
armonizar_precios <- function(barcelona_df, valencia_df, bilbao_df, anclas_df) {
  piezas <- list()

  if (!is.null(barcelona_df)) piezas[["barcelona"]] <- .normalizar_municipal(barcelona_df, "Barcelona", "barrio")
  if (!is.null(valencia_df)) piezas[["valencia"]] <- .normalizar_municipal(valencia_df, "Valencia", "municipio")
  if (!is.null(bilbao_df)) piezas[["bilbao"]] <- .normalizar_municipal(bilbao_df, "Bilbao", "barrio")

  anclas_norm <- .normalizar_anclas(anclas_df)

  # Esqueleto de 0 filas con las columnas correctas: garantiza que esta
  # función SIEMPRE devuelve un data.frame (nunca NULL), incluso si todas las
  # fuentes fallan a la vez. Los pasos siguientes (geocodificación, etc.)
  # dependen de poder hacer precios_zona$columna sin comprobar is.null antes.
  esqueleto_vacio <- data.frame(
    ciudad = character(0), zona = character(0), nivel_geo = character(0),
    precio_m2 = numeric(0), n_muestras = numeric(0), fuente = character(0),
    fecha_dato = character(0), es_estimado = logical(0), stringsAsFactors = FALSE
  )

  precios_zona <- do.call(rbind, c(list(esqueleto_vacio), piezas))

  # Municipios objetivo que se han quedado sin ninguna fila (porque no tienen
  # fuente oficial automatizable, ej. Madrid/Sevilla, o porque su fuente
  # dedicada falló en esta ejecución): recurren a su ancla manual a nivel de
  # municipio si existe una.
  municipios_objetivo <- vapply(MUNICIPIOS_OBJETIVO, function(m) m$ciudad, character(1))
  municipios_sin_dato <- setdiff(municipios_objetivo, unique(precios_zona$ciudad))

  if (length(municipios_sin_dato) > 0 && !is.null(anclas_norm)) {
    relleno <- anclas_norm[anclas_norm$ciudad %in% municipios_sin_dato & is.na(anclas_norm$zona), ]
    if (nrow(relleno) > 0) precios_zona <- rbind(precios_zona, relleno)
    municipios_sin_dato <- setdiff(municipios_sin_dato, relleno$ciudad)
  }

  if (length(municipios_sin_dato) > 0) {
    warning(
      "[armonizar_precios] Sin NINGÚN dato (ni de su fuente dedicada ni de ancla manual) para: ",
      paste(municipios_sin_dato, collapse = ", "),
      ". Añade una fila en data/raw/anclas_manuales.csv o revisa por qué falló la fuente oficial."
    )
  }

  # Zonas señaladas en ZONAS_SIN_FUENTE_OFICIAL: se añaden siempre, aunque su
  # municipio ya tenga dato propio, porque representan un nivel de detalle
  # que ninguna fuente oficial ofrece.
  if (!is.null(anclas_norm)) {
    for (z in ZONAS_SIN_FUENTE_OFICIAL) {
      fila <- anclas_norm[anclas_norm$ciudad == z$ciudad & !is.na(anclas_norm$zona) & anclas_norm$zona == z$zona, ]
      if (nrow(fila) > 0) precios_zona <- rbind(precios_zona, fila)
    }
  }

  rownames(precios_zona) <- NULL
  precios_zona
}
