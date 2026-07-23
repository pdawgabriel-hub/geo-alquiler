# Módulo dedicado al renderizado del gráfico de distribución de precios

# 1. UI del Módulo
graficosUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = "Distribución por Precios", 
    width = 4, 
    solidHeader = TRUE, 
    status = "warning",
    plotlyOutput(ns("grafico_precios"), height = 420)
  )
}

# 2. Server del Módulo
graficosServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    output$grafico_precios <- renderPlotly({
      df <- datos_reactivos()
      
      if (nrow(df) == 0) return(NULL)
      
      p <- ggplot(df, aes(x = precio)) + 
        geom_histogram(fill = "#f0ad4e", color = "white", bins = 12) +
        theme_minimal() +
        labs(x = "Precio (€)", y = "Cantidad")
      
      ggplotly(p)
    })
    
  })
}