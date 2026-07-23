# Módulo para el análisis estadístico avanzado, percentiles y boxplots

# 1. UI DEL MÓDULO
estadisticaUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "Resumen Estadístico del Mercado Visible", 
        width = 12, 
        status = "primary", 
        solidHeader = TRUE,
        fluidRow(
          valueBoxOutput(ns("kpi_mediana"), width = 3),
          valueBoxOutput(ns("kpi_p25"), width = 3),
          valueBoxOutput(ns("kpi_p75"), width = 3),
          valueBoxOutput(ns("kpi_iqr"), width = 3)
        )
      )
    ),
    
    fluidRow(
      box(
        title = "Distribución de Precios por Ciudad (Boxplot Interactivo)", 
        width = 6, 
        status = "info", 
        solidHeader = TRUE,
        plotlyOutput(ns("boxplot_ciudad"), height = 380)
      ),
      box(
        title = "Distribución de Precios por Tipo de Propiedad", 
        width = 6, 
        status = "info", 
        solidHeader = TRUE,
        plotlyOutput(ns("boxplot_tipo"), height = 380)
      )
    ),
    
    fluidRow(
      box(
        title = "Tabla Detallada de Percentiles por Ciudad", 
        width = 12, 
        status = "primary", 
        solidHeader = TRUE,
        DTOutput(ns("tabla_percentiles"))
      )
    )
  )
}

# 2. SERVER DEL MÓDULO
estadisticaServer <- function(id, datos_visibles) {
  moduleServer(id, function(input, output, session) {
    
    # --- KPIs DE PERCENTILES ---
    output$kpi_mediana <- renderValueBox({
      df <- datos_visibles()
      val <- if (nrow(df) > 0) round(median(df$precio)) else 0
      valueBox(paste0(val, " €"), "Mediana (P50)", icon = icon("calculator"), color = "purple")
    })
    
    output$kpi_p25 <- renderValueBox({
      df <- datos_visibles()
      val <- if (nrow(df) > 0) round(quantile(df$precio, 0.25)) else 0
      valueBox(paste0(val, " €"), "Percentil 25 (P25)", icon = icon("arrow-down-short-wide"), color = "blue")
    })
    
    output$kpi_p75 <- renderValueBox({
      df <- datos_visibles()
      val <- if (nrow(df) > 0) round(quantile(df$precio, 0.75)) else 0
      valueBox(paste0(val, " €"), "Percentil 75 (P75)", icon = icon("arrow-up-wide-short"), color = "teal")
    })
    
    output$kpi_iqr <- renderValueBox({
      df <- datos_visibles()
      val <- if (nrow(df) > 0) round(IQR(df$precio)) else 0
      valueBox(paste0(val, " €"), "Rango Intercuartílico (IQR)", icon = icon("arrows-left-right"), color = "orange")
    })
    
    # --- BOXPLOT POR CIUDAD ---
    output$boxplot_ciudad <- renderPlotly({
      df <- datos_visibles()
      if (nrow(df) == 0) return(NULL)
      
      p <- ggplot(df, aes(x = ciudad, y = precio, fill = ciudad)) +
        geom_boxplot(alpha = 0.7, outlier.color = "red", outlier.shape = 16) +
        theme_minimal() +
        theme(legend.position = "none") +
        labs(x = "", y = "Precio (€)")
      
      ggplotly(p)
    })
    
    # --- BOXPLOT POR TIPO ---
    output$boxplot_tipo <- renderPlotly({
      df <- datos_visibles()
      if (nrow(df) == 0) return(NULL)
      
      p <- ggplot(df, aes(x = tipo, y = precio, fill = tipo)) +
        geom_boxplot(alpha = 0.7, outlier.color = "red", outlier.shape = 16) +
        theme_minimal() +
        theme(legend.position = "none") +
        labs(x = "", y = "Precio (€)")
      
      ggplotly(p)
    })
    
    # --- TABLA DE PERCENTILES ---
    output$tabla_percentiles <- renderDT({
      df <- datos_visibles()
      if (nrow(df) == 0) return(NULL)
      
      # Agrupar estadísticas por ciudad
      resumen <- aggregate(precio ~ ciudad, data = df, FUN = function(x) {
        c(
          Min = min(x),
          P25 = quantile(x, 0.25),
          Mediana = median(x),
          Media = round(mean(x)),
          P75 = quantile(x, 0.75),
          Max = max(x)
        )
      })
      
      resumen_df <- data.frame(
        Ciudad = resumen$ciudad,
        Mínimo = resumen$precio[, "Min"],
        P25 = resumen$precio[, "P25.25%"],
        Mediana = resumen$precio[, "Mediana"],
        Media = resumen$precio[, "Media"],
        P75 = resumen$precio[, "P75.75%"],
        Máximo = resumen$precio[, "Max"]
      )
      
      datatable(
        resumen_df,
        options = list(dom = 't', pageLength = 10),
        rownames = FALSE
      )
    })
    
  })
}