#' The application server-side
#' 
#' @param input,output,session Internal parameters for `{shiny}`.
#' @import shiny
#' @import ggplot2
#' @importFrom stats aggregate reorder
#' @noRd
app_server <- function(input, output, session) {
  
  # 1. Carga optimizada de datos (Soporte Parquet o RDS)
  path_datos <- app_sys("app/data/alquileres.parquet")
  
  # Fallbacks para entorno de desarrollo local sin instalar paquete
  if (path_datos == "") {
    path_datos <- "inst/app/data/alquileres.parquet"
  }
  
  if (!file.exists(path_datos)) {
    path_datos <- "data/processed/alquileres.parquet"
  }
  
  # Si no existe Parquet, intenta cargar el archivo .rds original
  if (file.exists(path_datos)) {
    datos_totales <- arrow::read_parquet(path_datos)
  } else if (file.exists("data/processed/alquileres.rds")) {
    datos_totales <- readRDS("data/processed/alquileres.rds")
  } else {
    stop("No se ha encontrado el archivo de datos ni en Parquet ni en RDS. Ejecuta tu script de generación de datos.")
  }
  
  # Estado reactivo global para guardar IDs de inmuebles favoritos
  favoritos_ids <- reactiveVal(c())
  
  # 2. Lógica reactiva de filtros y mapa
  datos_filtrados_sidebar <- filtrosServer("filtros_sidebar", datos_totales)
  datos_visibles <- mapaServer("mapa_principal", datos_filtrados_sidebar)
  
  # 3. KPIs principales
  output$kpi_precio_medio <- shinydashboard::renderValueBox({
    df <- datos_visibles()
    precio_med <- if (!is.null(df) && nrow(df) > 0) round(mean(df$precio, na.rm = TRUE)) else 0
    shinydashboard::valueBox(paste0(precio_med, " €"), "Precio Medio", icon = icon("euro-sign"), color = "purple")
  })
  
  output$kpi_superficie_media <- shinydashboard::renderValueBox({
    df <- datos_visibles()
    sup_med <- if (!is.null(df) && nrow(df) > 0) round(mean(df$superficie, na.rm = TRUE)) else 0
    shinydashboard::valueBox(paste0(sup_med, " m²"), "Superficie Media", icon = icon("home"), color = "green")
  })
  
  output$kpi_precio_m2 <- shinydashboard::renderValueBox({
    df <- datos_visibles()
    precio_m2 <- if (!is.null(df) && nrow(df) > 0) round(mean(df$precio / df$superficie, na.rm = TRUE), 1) else 0
    shinydashboard::valueBox(paste0(precio_m2, " €/m²"), "Precio/m² Medio", icon = icon("calculator"), color = "orange")
  })
  
  output$kpi_total_inmuebles <- shinydashboard::renderValueBox({
    df <- datos_visibles()
    tot <- if (!is.null(df)) nrow(df) else 0
    shinydashboard::valueBox(tot, "Inmuebles Visibles", icon = icon("building"), color = "blue")
  })
  
  # 4. Instancia de Servidores Modulares
  tablaServer("tabla_principal", datos_visibles, favoritos_ids)
  graficosServer("grafico_principal", datos_visibles)
  calculadoraServer("calc_principal", datos_visibles)
  exportarServer("exportar_datos", datos_visibles)
  reporteServer("reporte_principal", datos_visibles)
  comparadorServer("comp_principal", datos_totales)
  oportunidadesServer("oportunidades_principal", datos_visibles)
  estadisticaServer("estadistica_principal", datos_visibles)
  recomendadorServer("recomendador_principal", datos_filtrados_sidebar)
  prediccionServer("prediccion_principal", datos_totales)
  barriosServer("barrios_principal", datos_totales)
  favoritosServer("fav_principal", datos_totales, favoritos_ids)
}