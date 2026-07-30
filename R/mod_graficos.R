# Módulo dedicado a la analítica visual con Plotly (histograma, dispersión y comparativas)

# 1. UI DEL MÓDULO
graficosUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      # Gráfico 1: Relación Precio vs Superficie
      box(
        title = "Relación Precio vs Superficie (m²)", 
        width = 7, 
        solidHeader = TRUE, 
        status = "warning",
        plotlyOutput(ns("grafico_dispersion"), height = 380)
      ),
      # Gráfico 2: Histograma de Distribución
      box(
        title = "Distribución por Rangos de Precio", 
        width = 5, 
        solidHeader = TRUE, 
        status = "primary",
        plotlyOutput(ns("grafico_precios"), height = 380)
      )
    ),
    fluidRow(
      # Gráfico 3: Comparativa Precio Medio por Ciudad
      box(
        title = "Precio Medio por Ciudad", 
        width = 12, 
        solidHeader = TRUE, 
        status = "info",
        plotlyOutput(ns("grafico_ciudades"), height = 320)
      )
    )
  )
}

# 2. SERVER DEL MÓDULO
graficosServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    # 1. HISTOGRAMA DE PRECIOS
    output$grafico_precios <- renderPlotly({
      df <- datos_reactivos()
      if (nrow(df) == 0) return(NULL)
      
      p <- ggplot(df, aes(x = precio)) + 
        geom_histogram(fill = "#3c8dbc", color = "white", bins = 12) +
        theme_minimal() +
        labs(x = "Precio (€)", y = "Cantidad de Inmuebles")
      
      ggplotly(p)
    })
    
    # 2. DISPERSIÓN: PRECIO VS SUPERFICIE
    # Con datasets grandes (miles de inmuebles) un scatter "normal" satura el
    # gráfico de puntos solapados. Se reduce tamaño/opacidad para que se
    # aprecie la densidad en vez de una mancha sólida, y si hay muchísimos
    # puntos se muestra una muestra aleatoria (mismo patrón visual, más ligero
    # y legible) dejando claro en el título cuántos se están representando.
    LIMITE_PUNTOS_DISPERSION <- 800

    output$grafico_dispersion <- renderPlotly({
      df <- datos_reactivos()
      if (nrow(df) == 0) return(NULL)

      df_plot <- df
      submuestreado <- nrow(df) > LIMITE_PUNTOS_DISPERSION
      if (submuestreado) {
        set.seed(1)
        df_plot <- df[sample(nrow(df), LIMITE_PUNTOS_DISPERSION), ]
      }

      p <- ggplot(df_plot, aes(x = superficie, y = precio, color = tipo, text = paste0(
        "<b>", tipo, " en ", ciudad, "</b><br>",
        "Precio: ", precio, " €<br>",
        "Superficie: ", superficie, " m²"
      ))) +
        geom_point(size = 1.6, alpha = 0.35) +
        geom_smooth(method = "lm", se = FALSE, color = "#e74c3c", linetype = "dashed") +
        theme_minimal() +
        labs(
          x = "Superficie (m²)", y = "Precio (€)", color = "Tipo",
          subtitle = if (submuestreado) {
            paste0("Muestra aleatoria de ", LIMITE_PUNTOS_DISPERSION, " de ", nrow(df), " inmuebles visibles")
          } else {
            NULL
          }
        )

      ggplotly(p, tooltip = "text")
    })
    
    # 3. PRECIO MEDIO POR CIUDAD
    output$grafico_ciudades <- renderPlotly({
      df <- datos_reactivos()
      if (nrow(df) == 0) return(NULL)
      
      # Agrupamos los datos usando la sintaxis nativa de R
      resumen_ciudad <- aggregate(precio ~ ciudad, data = df, FUN = mean)
      resumen_ciudad$precio <- round(resumen_ciudad$precio)
      
      p <- ggplot(resumen_ciudad, aes(x = reorder(ciudad, -precio), y = precio, fill = ciudad)) +
        geom_bar(stat = "identity", width = 0.6) +
        theme_minimal() +
        labs(x = "Ciudad", y = "Precio Medio (€)") +
        theme(legend.position = "none")
      
      ggplotly(p)
    })
    
  })
}