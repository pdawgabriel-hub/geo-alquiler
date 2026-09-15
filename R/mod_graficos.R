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

      plot_ly(df, x = ~precio, type = "histogram", nbinsx = 12,
              marker = list(color = "#3c8dbc", line = list(color = "white", width = 1))) %>%
        layout(
          xaxis = list(title = "Precio (€)"),
          yaxis = list(title = "Cantidad de Inmuebles")
        )
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

      df_plot$texto <- paste0(
        "<b>", df_plot$tipo, " en ", df_plot$ciudad, "</b><br>",
        "Precio: ", df_plot$precio, " €<br>",
        "Superficie: ", df_plot$superficie, " m²"
      )

      p <- plot_ly(
        df_plot, x = ~superficie, y = ~precio, color = ~tipo,
        text = ~texto, hoverinfo = "text",
        type = "scatter", mode = "markers",
        marker = list(size = 8, opacity = 0.35)
      )

      # Línea de tendencia (regresión lineal simple) por tipo, replicando el
      # agrupamiento que heredaba geom_smooth() del aes(color = tipo) original.
      for (tp in unique(df_plot$tipo)) {
        df_tipo <- df_plot[df_plot$tipo == tp, ]
        if (nrow(df_tipo) < 2) next
        fit <- lm(precio ~ superficie, data = df_tipo)
        rango_x <- seq(min(df_tipo$superficie), max(df_tipo$superficie), length.out = 30)
        pred_y <- predict(fit, newdata = data.frame(superficie = rango_x))
        p <- p %>% add_lines(
          x = rango_x, y = pred_y, inherit = FALSE,
          line = list(color = "#e74c3c", dash = "dash"),
          showlegend = FALSE, hoverinfo = "skip"
        )
      }

      p %>% layout(
        xaxis = list(title = "Superficie (m²)"),
        yaxis = list(title = "Precio (€)"),
        legend = list(title = list(text = "Tipo")),
        title = list(
          text = if (submuestreado) {
            paste0("Muestra aleatoria de ", LIMITE_PUNTOS_DISPERSION, " de ", nrow(df), " inmuebles visibles")
          } else {
            ""
          },
          font = list(size = 12), x = 0, xanchor = "left"
        )
      )
    })
    
    # 3. PRECIO MEDIO POR CIUDAD
    output$grafico_ciudades <- renderPlotly({
      df <- datos_reactivos()
      if (nrow(df) == 0) return(NULL)

      # Agrupamos los datos usando la sintaxis nativa de R
      resumen_ciudad <- aggregate(precio ~ ciudad, data = df, FUN = mean)
      resumen_ciudad$precio <- round(resumen_ciudad$precio)
      resumen_ciudad <- resumen_ciudad[order(-resumen_ciudad$precio), ]
      resumen_ciudad$ciudad <- factor(resumen_ciudad$ciudad, levels = resumen_ciudad$ciudad)

      plot_ly(
        resumen_ciudad, x = ~ciudad, y = ~precio, type = "bar",
        color = ~ciudad, showlegend = FALSE
      ) %>%
        layout(
          xaxis = list(title = "Ciudad"),
          yaxis = list(title = "Precio Medio (€)")
        )
    })
    
  })
}