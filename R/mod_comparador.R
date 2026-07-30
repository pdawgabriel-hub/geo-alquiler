# Módulo para comparar 2 ciudades o tipologías cara a cara (A/B)

# 1. UI DEL MÓDULO
comparadorUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "Configuración de la Comparativa A/B", 
        width = 12, 
        status = "primary", 
        solidHeader = TRUE,
        fluidRow(
          column(6,
            selectInput(ns("ciudad_a"), "Selecciona Ciudad / Opción A:", choices = NULL)
          ),
          column(6,
            selectInput(ns("ciudad_b"), "Selecciona Ciudad / Opción B:", choices = NULL)
          )
        )
      )
    ),
    
    fluidRow(
      # COLUMNA OPCIÓN A
      column(width = 6,
        box(
          title = uiOutput(ns("titulo_a")), 
          width = 12, 
          status = "info", 
          solidHeader = TRUE,
          valueBoxOutput(ns("kpi_precio_a"), width = 6),
          valueBoxOutput(ns("kpi_m2_a"), width = 6),
          plotlyOutput(ns("hist_a"), height = 280)
        )
      ),
      
      # COLUMNA OPCIÓN B
      column(width = 6,
        box(
          title = uiOutput(ns("titulo_b")), 
          width = 12, 
          status = "success", 
          solidHeader = TRUE,
          valueBoxOutput(ns("kpi_precio_b"), width = 6),
          valueBoxOutput(ns("kpi_m2_b"), width = 6),
          plotlyOutput(ns("hist_b"), height = 280)
        )
      )
    )
  )
}

# 2. SERVER DEL MÓDULO
comparadorServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {

    # Ciudades disponibles según el dataset cargado (no hardcodeadas).
    observeEvent(datos_totales, {
      req(datos_totales)
      ciudades_opt <- sort(unique(datos_totales$ciudad))
      updateSelectInput(session, "ciudad_a", choices = ciudades_opt, selected = ciudades_opt[1])
      updateSelectInput(session, "ciudad_b", choices = ciudades_opt, selected = ciudades_opt[min(2, length(ciudades_opt))])
    }, once = TRUE)

    # Titulos dinámicos
    output$titulo_a <- renderUI({ HTML(paste0("<b>Análisis: ", input$ciudad_a, "</b>")) })
    output$titulo_b <- renderUI({ HTML(paste0("<b>Análisis: ", input$ciudad_b, "</b>")) })
    
    # Datos filtrados A
    datos_a <- reactive({
      datos_totales[datos_totales$ciudad == input$ciudad_a, ]
    })
    
    # Datos filtrados B
    datos_b <- reactive({
      datos_totales[datos_totales$ciudad == input$ciudad_b, ]
    })
    
    # --- MÉTRICAS Y GRÁFICOS OPCIÓN A ---
    output$kpi_precio_a <- renderValueBox({
      df <- datos_a()
      p_med <- ifelse(nrow(df) > 0, round(mean(df$precio)), 0)
      valueBox(paste0(p_med, " €"), "Precio Medio A", icon = icon("euro-sign"), color = "blue")
    })
    
    output$kpi_m2_a <- renderValueBox({
      df <- datos_a()
      pm2 <- ifelse(nrow(df) > 0, round(mean(df$precio / df$superficie), 1), 0)
      valueBox(paste0(pm2, " €/m²"), "Precio/m² A", icon = icon("calculator"), color = "light-blue")
    })
    
    output$hist_a <- renderPlotly({
      df <- datos_a()
      if (nrow(df) == 0) return(NULL)
      p <- ggplot(df, aes(x = precio)) + 
        geom_histogram(fill = "#3c8dbc", color = "white", bins = 10) +
        theme_minimal() + labs(x = "Precio (€)", y = "Inmuebles")
      ggplotly(p)
    })
    
    # --- MÉTRICAS Y GRÁFICOS OPCIÓN B ---
    output$kpi_precio_b <- renderValueBox({
      df <- datos_b()
      p_med <- ifelse(nrow(df) > 0, round(mean(df$precio)), 0)
      valueBox(paste0(p_med, " €"), "Precio Medio B", icon = icon("euro-sign"), color = "green")
    })
    
    output$kpi_m2_b <- renderValueBox({
      df <- datos_b()
      pm2 <- ifelse(nrow(df) > 0, round(mean(df$precio / df$superficie), 1), 0)
      valueBox(paste0(pm2, " €/m²"), "Precio/m² B", icon = icon("calculator"), color = "teal")
    })
    
    output$hist_b <- renderPlotly({
      df <- datos_b()
      if (nrow(df) == 0) return(NULL)
      p <- ggplot(df, aes(x = precio)) + 
        geom_histogram(fill = "#00a65a", color = "white", bins = 10) +
        theme_minimal() + labs(x = "Precio (€)", y = "Inmuebles")
      ggplotly(p)
    })
    
  })
}