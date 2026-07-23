# R/mod_filtros.R
# Módulo para el control de filtros globales horizontales

# 1. UI DEL MÓDULO (Barra Horizontal)
filtrosUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = tagList(icon("sliders"), " Panel de Filtros Globales"), 
    width = 12, 
    status = "primary", 
    solidHeader = TRUE, 
    collapsible = TRUE, # Permite colapsar los filtros para ganar espacio de mapa/gráficos
    
    fluidRow(
      column(3,
        selectInput(
          ns("filtro_ciudad"), 
          "Ciudad:", 
          choices = NULL, 
          multiple = TRUE
        )
      ),
      column(3,
        selectInput(
          ns("filtro_tipo"), 
          "Tipo de Inmueble:", 
          choices = NULL, 
          multiple = TRUE
        )
      ),
      column(2,
        sliderInput(
          ns("filtro_precio"), 
          "Precio (€):", 
          min = 0, max = 10000, 
          value = c(0, 10000), 
          step = 50
        )
      ),
      column(2,
        sliderInput(
          ns("filtro_superficie"), 
          "Superficie (m²):", 
          min = 0, max = 500, 
          value = c(0, 500), 
          step = 10
        )
      ),
      column(2,
        uiOutput(ns("ui_filtro_precio_m2"))
      )
    ),
    
    fluidRow(
      column(12,
        div(
          style = "text-align: right; margin-top: -10px;",
          actionButton(
            ns("btn_reset"), 
            " Restablecer Filtros", 
            icon = icon("undo"), 
            class = "btn-warning btn-sm"
          )
        )
      )
    )
  )
}

# 2. SERVER DEL MÓDULO
filtrosServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {
    
    # Inicialización de opciones
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
        "Máx €/m²:", 
        min = 1, 
        max = max_pm2, 
        value = max_pm2, 
        step = 1,
        post = " €"
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
      
      if (is.null(input$filtro_ciudad) || is.null(input$filtro_tipo)) {
        return(df[0, ])
      }
      
      df <- df[df$ciudad %in% input$filtro_ciudad, ]
      df <- df[df$tipo %in% input$filtro_tipo, ]
      
      if (!is.null(input$filtro_precio)) {
        df <- df[df$precio >= input$filtro_precio[1] & df$precio <= input$filtro_precio[2], ]
      }
      
      if (!is.null(input$filtro_superficie)) {
        df <- df[df$superficie >= input$filtro_superficie[1] & df$superficie <= input$filtro_superficie[2], ]
      }
      
      if (!is.null(input$filtro_precio_m2)) {
        precio_m2_actual <- df$precio / df$superficie
        df <- df[precio_m2_actual <= input$filtro_precio_m2, ]
      }
      
      return(df)
    })
    
    return(datos_filtrados)
  })
}