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
    
    # 4. Cálculo de Similitud (Ultrarrobusto)
    similares <- reactive({
      ref <- inmueble_ref()
      df <- datos()
      if (is.null(ref) || is.null(df) || nrow(df) < 2) return(NULL)
      
      # Excluir el inmueble seleccionado
      cand <- df[df$id != ref$id[1], , drop = FALSE]
      if (nrow(cand) == 0) return(NULL)
      
      # Detectar nombres de columnas disponibles
      col_pre <- if ("precio" %in% names(cand)) "precio" else NULL
      col_sup <- if ("superficie" %in% names(cand)) "superficie" else NULL
      col_lat <- intersect(c("latitud", "lat", "latitude"), names(cand))[1]
      col_lng <- intersect(c("longitud", "lng", "lon", "longitude"), names(cand))[1]
      
      if (is.null(col_pre) || is.null(col_sup)) return(NULL)
      
      # Distancia matemática
      d_pre <- abs(cand[[col_pre]] - ref[[col_pre]][1]) / (max(df[[col_pre]], na.rm=T) - min(df[[col_pre]], na.rm=T) + 1e-5)
      d_sup <- abs(cand[[col_sup]] - ref[[col_sup]][1]) / (max(df[[col_sup]], na.rm=T) - min(df[[col_sup]], na.rm=T) + 1e-5)
      
      if (!is.na(col_lat) && !is.na(col_lng)) {
        d_lat <- abs(cand[[col_lat]] - ref[[col_lat]][1]) / (max(df[[col_lat]], na.rm=T) - min(df[[col_lat]], na.rm=T) + 1e-5)
        d_lng <- abs(cand[[col_lng]] - ref[[col_lng]][1]) / (max(df[[col_lng]], na.rm=T) - min(df[[col_lng]], na.rm=T) + 1e-5)
        dist_total <- sqrt(0.3 * d_lat^2 + 0.3 * d_lng^2 + 0.25 * d_pre^2 + 0.15 * d_sup^2)
      } else {
        dist_total <- sqrt(0.6 * d_pre^2 + 0.4 * d_sup^2)
      }
      
      cand$score <- dist_total
      cand$similitud <- paste0(round(pmax(0, (1 - dist_total)) * 100, 1), "%")
      cand$precio_m2 <- round(cand[[col_pre]] / cand[[col_sup]], 1)
      
      cand <- cand[order(cand$score), ]
      head(cand, input$top_n)
    })
    
    # 5. Renderizar Tabla final mostrando solo columnas existentes
    output$tabla_similares <- renderDataTable({
      df_sim <- similares()
      req(df_sim)
      
      cols_deseadas <- c("titulo", "ciudad", "precio", "superficie", "precio_m2", "similitud")
      cols_existentes <- intersect(cols_deseadas, names(df_sim))
      
      datatable(
        df_sim[, cols_existentes, drop = FALSE],
        options = list(dom = 't', pageLength = input$top_n),
        rownames = FALSE
      )
    })
  })
}