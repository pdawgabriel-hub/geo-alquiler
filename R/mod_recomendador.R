# Módulo Recomendador de Inmuebles Similares (Versión Tolerante a Nombres de Columna)

recomendadorUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("search-location"), " Seleccionar Inmueble de Referencia"),
        width = 12, status = "primary", solidHeader = TRUE, collapsible = TRUE,
        fluidRow(
          column(8,
                 selectizeInput(
                   ns("inmueble_id"),
                   "Busca o selecciona un inmueble por título/ciudad:",
                   choices = NULL,
                   options = list(placeholder = "Escribe para buscar un inmueble...")
                 )
          ),
          column(4,
                 sliderInput(
                   ns("top_n"), "Número de recomendados:",
                   min = 2, max = 8, value = 4, step = 1
                 )
          )
        )
      )
    ),
    
    fluidRow(
      box(
        title = tagList(icon("home"), " Inmueble Seleccionado"),
        width = 12, status = "info", solidHeader = TRUE,
        uiOutput(ns("detalle_seleccionado"))
      )
    ),
    
    fluidRow(
      box(
        title = tagList(icon("magic"), " Inmuebles Más Similares Encontrados"),
        width = 12, status = "success", solidHeader = TRUE,
        DTOutput(ns("tabla_similares"))
      )
    )
  )
}

recomendadorServer <- function(id, datos) {
  moduleServer(id, function(input, output, session) {
    
    # 1. Actualizar el selector de inmuebles
    observeEvent(datos(), {
      df <- datos()
      if (!is.null(df) && nrow(df) > 0 && "id" %in% names(df)) {
        col_tit <- if ("titulo" %in% names(df)) "titulo" else names(df)[1]
        col_ciu <- if ("ciudad" %in% names(df)) "ciudad" else col_tit
        col_pre <- if ("precio" %in% names(df)) "precio" else names(df)[2]
        
        etiquetas <- paste0(df[[col_ciu]], " - ", df[[col_tit]], " (", df[[col_pre]], " €)")
        opciones <- setNames(df$id, etiquetas)
        
        updateSelectizeInput(session, "inmueble_id", choices = opciones, selected = df$id[1], server = TRUE)
      } else {
        updateSelectizeInput(session, "inmueble_id", choices = character(0), server = TRUE)
      }
    }, ignoreNULL = TRUE)
    
    # 2. Fila del inmueble seleccionado
    inmueble_ref <- reactive({
      req(input$inmueble_id)
      df <- datos()
      if (is.null(df) || nrow(df) == 0 || !"id" %in% names(df)) return(NULL)
      
      sub_df <- df[df$id == input$inmueble_id, , drop = FALSE]
      if (nrow(sub_df) == 0) return(NULL)
      sub_df[1, , drop = FALSE]
    })
    
    # 3. Detalle visual superior
    output$detalle_seleccionado <- renderUI({
      ref <- inmueble_ref()
      if (is.null(ref)) return(h5("Selecciona un inmueble válido de la lista."))
      
      tit <- if ("titulo" %in% names(ref)) ref$titulo[1] else "-"
      ciu <- if ("ciudad" %in% names(ref)) ref$ciudad[1] else "-"
      pre <- if ("precio" %in% names(ref)) ref$precio[1] else 0
      sup <- if ("superficie" %in% names(ref)) ref$superficie[1] else 1
      pm2 <- round(pre / sup, 1)
      
      fluidRow(
        column(3, strong("Título: "), tit),
        column(3, strong("Ciudad: "), ciu),
        column(2, strong("Precio: "), paste0(pre, " €/mes")),
        column(2, strong("Superficie: "), paste0(sup, " m²")),
        column(2, strong("Ratio: "), paste0(pm2, " €/m²"))
      )
    })
    
    # 4. Similitud (distancia ponderada en inmuebles_similares(), R/fct_calculos.R)
    similares <- reactive({
      inmuebles_similares(inmueble_ref(), datos(), input$top_n)
    })
    
    # 5. Renderizar Tabla final mostrando solo columnas existentes
    output$tabla_similares <- renderDT({
      df_sim <- similares()
      req(df_sim)
      
      cols_deseadas <- c("titulo", "ciudad", "precio", "superficie", "precio_m2", "similitud")
      cols_existentes <- intersect(cols_deseadas, names(df_sim))
      
      datatable(
        df_sim[, cols_existentes, drop = FALSE],
        options = list(dom = 't', pageLength = input$top_n, scrollX = TRUE),
        rownames = FALSE
      )
    })
  })
}