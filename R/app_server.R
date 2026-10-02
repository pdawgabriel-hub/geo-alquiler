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
  
  # Observatorio del Alquiler (SERPAVI + INE + Catastro, por municipio). Es
  # opcional: si falta el fichero, solo esa pestaña muestra un aviso.
  path_observatorio <- app_sys("app/data/observatorio_municipios.parquet")
  if (path_observatorio == "") path_observatorio <- "inst/app/data/observatorio_municipios.parquet"
  # Se lee y prepara una vez por proceso, no en cada sesión (ver cargar_observatorio()).
  datos_observatorio <- cargar_observatorio(path_observatorio)

  # Estado reactivo global para guardar IDs de inmuebles favoritos
  favoritos_ids <- reactiveVal(c())
  
  # 2. Lógica reactiva de filtros y mapa
  datos_filtrados_sidebar <- filtrosServer("filtros_sidebar", datos_totales)
  datos_visibles <- mapaServer("mapa_principal", datos_filtrados_sidebar)
  
  # 3. KPIs principales (cálculo en kpis_mercado(), R/fct_calculos.R)
  kpis <- reactive(kpis_mercado(datos_visibles()))

  output$kpi_precio_medio <- shinydashboard::renderValueBox({
    shinydashboard::valueBox(paste0(kpis()$precio_medio, " €"), "Precio Medio", icon = icon("euro-sign"), color = "purple")
  })

  output$kpi_superficie_media <- shinydashboard::renderValueBox({
    shinydashboard::valueBox(paste0(kpis()$superficie_media, " m²"), "Superficie Media", icon = icon("home"), color = "green")
  })

  output$kpi_precio_m2 <- shinydashboard::renderValueBox({
    shinydashboard::valueBox(paste0(kpis()$precio_m2_medio, " €/m²"), "Precio/m² Medio", icon = icon("calculator"), color = "orange")
  })

  output$kpi_total_inmuebles <- shinydashboard::renderValueBox({
    shinydashboard::valueBox(kpis()$total, "Inmuebles Visibles", icon = icon("building"), color = "blue")
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
  observatorioServer("observatorio_principal", datos_observatorio)
}