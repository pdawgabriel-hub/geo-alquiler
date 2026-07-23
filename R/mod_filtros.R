# R/mod_filtros.R
# Módulo para el control de filtros globales en el panel lateral (Sidebar)

# 1. UI DEL MÓDULO
filtrosUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    h4("Filtros Globales", style = "color: white; padding-left: 15px;"),
    
    selectInput(
      ns("filtro_ciudad"), 
      "Ciudad:", 
      choices = NULL, 
      multiple = TRUE
    ),
    
    selectInput(
      ns("filtro_tipo"), 
      "Tipo de Inmueble:", 
      choices = NULL, 
      multiple = TRUE
    ),
    
    sliderInput(
      ns("filtro_precio"), 
      "Rango de Precio (€):", 
      min = 0, max = 10000, 
      value = c(0, 10000), 
      step = 50
    ),
    
    sliderInput(
      ns("filtro_superficie"), 
      "Superficie (m²):", 
      min = 0, max = 500, 
      value = c(0, 500), 
      step = 10
    ),
    
    # Filtro dinámico de Ratio Máximo (€/m²)
    uiOutput(ns("ui_filtro_precio_m2")),
    
    actionButton(
      ns("btn_reset"), 
      "Restablecer Filtros", 
      icon = icon("undo"), 
      class = "btn-warning btn-block",
      style = "margin: 15px 15px 25px 15px; width: calc(100% - 30px);"
    )
  )
}

# 2. SERVER DEL MÓDULO
filtrosServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {
    
    # Inicialización de opciones una sola vez cuando cargan los datos
    observeEvent(datos_totales, {
      req(datos_totales)
      
      ciudades_opt <- sort(unique(datos_totales$ciudad))
      tipos_opt <- sort(unique(datos_totales$tipo))
      
      updateSelectInput(
        session, "filtro_ciudad",
        choices = ciudades_opt,
        selected = ciudades_opt
      )
      
      updateSelectInput(
        session, "filtro_tipo",
        choices = tipos_opt,
        selected = tipos_opt
      )
      
      p_min <- floor(min(datos_totales$precio, na.rm = TRUE))
      p_max <- ceiling(max(datos_totales$precio, na.rm = TRUE))
      updateSliderInput(
        session, "filtro_precio",
        min = p_min, max = p_max,
        value = c(p_min, p_max)
      )
      
      s_min <- floor(min(datos_totales$superficie, na.rm = TRUE))
      s_max <- ceiling(max(datos_totales$superficie, na.rm = TRUE))
      updateSliderInput(
        session, "filtro_superficie",
        min = s_min, max = s_max,
        value = c(s_min, s_max)
      )
    }, once = TRUE)
    
    # Renderizado del slider €/m²
    output$ui_filtro_precio_m2 <- renderUI({
      ns <- session$ns
      req(datos_totales)
      
      pm2_vec <- datos_totales$precio / datos_totales$superficie
      max_pm2 <- ceiling(max(pm2_vec, na.rm = TRUE))
      
      sliderInput(
        ns("filtro_precio_m2"), 
        "Precio/m² Máximo (€/m²):", 
        min = 1, 
        max = max_pm2, 
        value = max_pm2, 
        step = 1,
        post = " €/m²"
      )
    })
    
    # Botón de reset de filtros
    observeEvent(input$btn_reset, {
      ciudades_opt <- sort(unique(datos_totales$ciudad))
      tipos_opt <- sort(unique(datos_totales$tipo))
      
      updateSelectInput(session, "filtro_ciudad", selected = ciudades_opt)
      updateSelectInput(session, "filtro_tipo", selected = tipos_opt)
      
      p_min <- floor(min(datos_totales$precio, na.rm = TRUE))
      p_max <- ceiling(max(datos_totales$precio, na.rm = TRUE))
      updateSliderInput(session, "filtro_precio", value = c(p_min, p_max))
      
      s_min <- floor(min(datos_totales$superficie, na.rm = TRUE))
      s_max <- ceiling(max(datos_totales$superficie, na.rm = TRUE))
      updateSliderInput(session, "filtro_superficie", value = c(s_min, s_max))
      
      pm2_vec <- datos_totales$precio / datos_totales$superficie
      max_pm2 <- ceiling(max(pm2_vec, na.rm = TRUE))
      updateSliderInput(session, "filtro_precio_m2", value = max_pm2)
    })
    
    # Expresión reactiva para devolver el dataset filtrado
    datos_filtrados <- reactive({
      df <- datos_totales
      
      # Si el usuario desselecciona todas las ciudades/tipos, devolver dataset vacío limpiamente
      if (is.null(input$filtro_ciudad) || is.null(input$filtro_tipo)) {
        return(df[0, ])
      }
      
      # Filtro por Ciudad
      df <- df[df$ciudad %in% input$filtro_ciudad, ]
      
      # Filtro por Tipo
      df <- df[df$tipo %in% input$filtro_tipo, ]
      
      # Filtro por Rango de Precio
      if (!is.null(input$filtro_precio)) {
        df <- df[df$precio >= input$filtro_precio[1] & df$precio <= input$filtro_precio[2], ]
      }
      
      # Filtro por Rango de Superficie
      if (!is.null(input$filtro_superficie)) {
        df <- df[df$superficie >= input$filtro_superficie[1] & df$superficie <= input$filtro_superficie[2], ]
      }
      
      # Filtro por Precio/m² Máximo
      if (!is.null(input$filtro_precio_m2)) {
        precio_m2_actual <- df$precio / df$superficie
        df <- df[precio_m2_actual <= input$filtro_precio_m2, ]
      }
      
      return(df)
    })
    
    return(datos_filtrados)
  })
}