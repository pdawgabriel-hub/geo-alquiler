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

# --- SERVER DEL MÓDULO DE GRÁFICOS (con ggplot2 explícito) ---
graficosServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    # 1. HISTOGRAMA DE PRECIOS
    output$grafico_precios <- plotly::renderPlotly({
      df <- datos_reactivos()
      if (is.null(df) || nrow(df) == 0) return(NULL)
      
      p <- ggplot2::ggplot(df, ggplot2::aes(x = precio)) + 
        ggplot2::geom_histogram(fill = "#3c8dbc", color = "white", bins = 12) +
        ggplot2::theme_minimal() +
        ggplot2::labs(x = "Precio (€)", y = "Cantidad de Inmuebles")
      
      plotly::ggplotly(p)
    })
    
    # 2. DISPERSIÓN: PRECIO VS SUPERFICIE
    output$grafico_dispersion <- plotly::renderPlotly({
      df <- datos_reactivos()
      if (is.null(df) || nrow(df) == 0) return(NULL)
      
      p <- ggplot2::ggplot(df, ggplot2::aes(x = superficie, y = precio, color = tipo, text = paste0(
        "<b>", tipo, " en ", ciudad, "</b><br>",
        "Precio: ", precio, " €<br>",
        "Superficie: ", superficie, " m²"
      ))) +
        ggplot2::geom_point(size = 3, alpha = 0.7) +
        ggplot2::geom_smooth(method = "lm", se = FALSE, color = "#e74c3c", linetype = "dashed") +
        ggplot2::theme_minimal() +
        ggplot2::labs(x = "Superficie (m²)", y = "Precio (€)", color = "Tipo")
      
      plotly::ggplotly(p, tooltip = "text")
    })
    
    # 3. PRECIO MEDIO POR CIUDAD
    output$grafico_ciudades <- plotly::renderPlotly({
      df <- datos_reactivos()
      if (is.null(df) || nrow(df) == 0) return(NULL)
      
      resumen_ciudad <- stats::aggregate(precio ~ ciudad, data = df, FUN = mean)
      resumen_ciudad$precio <- round(resumen_ciudad$precio)
      
      p <- ggplot2::ggplot(resumen_ciudad, ggplot2::aes(x = stats::reorder(ciudad, -precio), y = precio, fill = ciudad)) +
        ggplot2::geom_bar(stat = "identity", width = 0.6) +
        ggplot2::theme_minimal() +
        ggplot2::labs(x = "Ciudad", y = "Precio Medio (€)") +
        ggplot2::theme(legend.position = "none")
      
      plotly::ggplotly(p)
    })
    
  })
}