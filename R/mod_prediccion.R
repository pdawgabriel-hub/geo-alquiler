# Módulo de Predicción de Precios de Alquiler mediante Machine Learning (LM)

prediccionUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("sliders-h"), " Configura las características del inmueble"),
        width = 4, status = "primary", solidHeader = TRUE,
        selectInput(ns("ciudad"), "Ciudad:", choices = c("Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao")),
        uiOutput(ns("selector_barrio")),
        selectInput(ns("tipo"), "Tipo de Vivienda:", choices = c("Piso", "Apartamento", "Ático", "Estudio", "Casa / Chalet")),
        sliderInput(ns("superficie"), "Superficie (m²):", min = 30, max = 250, value = 75, step = 5),
        numericInput(ns("habitaciones"), "Habitaciones:", value = 2, min = 1, max = 6),
        numericInput(ns("banos"), "Baños:", value = 1, min = 1, max = 4),
        actionButton(ns("btn_predecir"), "Calcular Estimación ML", icon = icon("chart-line"), class = "btn-primary btn-block")
      ),
      
      box(
        title = tagList(icon("chart-line"), " Estimación de Valor de Mercado"),
        width = 8, status = "success", solidHeader = TRUE,
        uiOutput(ns("resultado_prediccion")),
        hr(),
        plotlyOutput(ns("grafico_comparativo_ml"), height = 300)
      )
    )
  )
}

prediccionServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {
    
    # Barrio dinámico según ciudad seleccionada
    output$selector_barrio <- renderUI({
      req(input$ciudad)
      df <- datos_totales
      if (!"barrio" %in% names(df)) return(NULL)
      barrios_disponibles <- sort(unique(df$barrio[df$ciudad == input$ciudad]))
      selectInput(session$ns("barrio"), "Barrio / Distrito:", choices = barrios_disponibles)
    })
    
    # Entrenamiento del Modelo ML al pulsar botón
    modelo_fit <- reactive({
      df <- datos_totales
      req(nrow(df) > 10)
      
      # Si el dataset no tiene habitaciones aún, entrena un modelo simplificado
      if ("habitaciones" %in% names(df) && "banos" %in% names(df)) {
        lm(precio ~ superficie + habitaciones + banos + factor(ciudad) + factor(tipo), data = df)
      } else {
        lm(precio ~ superficie + factor(ciudad) + factor(tipo), data = df)
      }
    })
    
    prediccion_res <- eventReactive(input$btn_predecir, {
      req(modelo_fit(), input$ciudad, input$tipo, input$superficie)
      
      fit <- modelo_fit()
      df_train <- datos_totales
      
      if ("habitaciones" %in% names(df_train) && "banos" %in% names(df_train)) {
        nueva_vivienda <- data.frame(
          superficie   = as.numeric(input$superficie),
          habitaciones = as.numeric(input$habitaciones),
          banos        = as.numeric(input$banos),
          ciudad       = input$ciudad,
          tipo         = input$tipo,
          stringsAsFactors = FALSE
        )
      } else {
        nueva_vivienda <- data.frame(
          superficie   = as.numeric(input$superficie),
          ciudad       = input$ciudad,
          tipo         = input$tipo,
          stringsAsFactors = FALSE
        )
      }
      
      pred <- predict(fit, newdata = nueva_vivienda, interval = "prediction", level = 0.90)
      
      list(
        estimado = round(pred[1]),
        min_90   = round(pmax(200, pred[2])),
        max_90   = round(pred[3])
      )
    }, ignoreNULL = FALSE)
    
    output$resultado_prediccion <- renderUI({
      res <- prediccion_res()
      if (is.null(res)) return(h4("Haz clic en 'Calcular Estimación ML' para obtener el resultado."))
      
      tagList(
        fluidRow(
          valueBox(paste0(res$estimado, " €/mes"), "Precio Estimado Justo", icon = icon("tag"), color = "green", width = 6),
          valueBox(paste0(res$min_90, " € - ", res$max_90, " €"), "Rango Esperado (90% conf.)", icon = icon("balance-scale"), color = "purple", width = 6)
        )
      )
    })
    
    output$grafico_comparativo_ml <- renderPlotly({
      res <- prediccion_res()
      req(res, input$ciudad)
      
      df_c <- datos_totales[datos_totales$ciudad == input$ciudad, ]
      
      p <- ggplot(df_c, aes(x = superficie, y = precio)) +
        geom_point(alpha = 0.3, color = "gray") +
        geom_point(data = data.frame(superficie = input$superficie, precio = res$estimado), 
           aes(x = superficie, y = precio), color = "red", size = 4) +
        geom_errorbar(aes(x = input$superficie, ymin = res$min_90, ymax = res$max_90), color = "red", width = 5) +
        theme_minimal() +
        labs(
          title = paste("Tu estimación (Punto Rojo) vs Inmuebles en", input$ciudad),
          x = "Superficie (m²)", y = "Precio (€)"
        )
      
      ggplotly(p)
    })
    
  })
}