favoritosUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("star"), " Mi Lista de Inmuebles Guardados"),
        width = 12, status = "warning", solidHeader = TRUE,
        p("Consulta y gestiona los inmuebles que has marcado como favoritos durante tu sesión.")
      )
    ),
    
    fluidRow(
      valueBoxOutput(ns("kpi_fav_total"), width = 3),
      valueBoxOutput(ns("kpi_fav_precio_medio"), width = 3),
      valueBoxOutput(ns("kpi_fav_m2_medio"), width = 3),
      valueBoxOutput(ns("kpi_fav_ratio_medio"), width = 3)
    ),
    
    fluidRow(
      box(
        title = tagList(icon("list"), " Detalle de Favoritos Guardados"),
        width = 12, status = "primary", solidHeader = TRUE,
        fluidRow(
          column(12,
            div(style = "margin-bottom: 15px;",
              downloadButton(ns("descargar_favs_csv"), "Exportar Favoritos a CSV", class = "btn-success"),
              actionButton(ns("vaciar_favs"), "Vaciar Favoritos", icon = icon("trash"), class = "btn-danger pull-right")
            )
          )
        ),
        DTOutput(ns("tabla_favoritos"))
      )
    )
  )
}

favoritosServer <- function(id, datos_totales, fav_reactive = NULL) {
  moduleServer(id, function(input, output, session) {
    
    # Vaciar favoritos
    observeEvent(input$vaciar_favs, {
      if (!is.null(fav_reactive) && (is.reactive(fav_reactive) || is.function(fav_reactive))) {
        fav_reactive(c())
        showNotification("Se han vaciado los favoritos.", type = "warning")
      }
    })
    
    # Filtrado seguro de favoritos
    df_favs <- reactive({
      ids_guardados <- if (!is.null(fav_reactive) && (is.reactive(fav_reactive) || is.function(fav_reactive))) fav_reactive() else c()
      df <- if (is.reactive(datos_totales)) datos_totales() else datos_totales
      
      if (is.null(df) || nrow(df) == 0 || length(ids_guardados) == 0) {
        return(data.frame())
      }
      
      if ("id" %in% names(df)) {
        df[as.character(df$id) %in% as.character(ids_guardados), , drop = FALSE]
      } else {
        indices_validos <- intersect(as.numeric(ids_guardados), seq_len(nrow(df)))
        df[indices_validos, , drop = FALSE]
      }
    })
    
    # KPIs
    output$kpi_fav_total <- renderValueBox({
      df <- df_favs()
      tot <- if (!is.null(df)) nrow(df) else 0
      valueBox(tot, "Inmuebles Guardados", icon = icon("heart"), color = "yellow")
    })
    
    output$kpi_fav_precio_medio <- renderValueBox({
      df <- df_favs()
      val <- if (!is.null(df) && nrow(df) > 0 && "precio" %in% names(df)) {
        round(mean(df$precio, na.rm = TRUE), 0)
      } else { 0 }
      valueBox(paste0(val, " €"), "Precio Medio Guardados", icon = icon("tag"), color = "purple")
    })
    
    output$kpi_fav_m2_medio <- renderValueBox({
      df <- df_favs()
      val <- if (!is.null(df) && nrow(df) > 0 && "superficie" %in% names(df)) {
        round(mean(df$superficie, na.rm = TRUE), 0)
      } else { 0 }
      valueBox(paste0(val, " m²"), "Superficie Media", icon = icon("ruler-combined"), color = "blue")
    })
    
    output$kpi_fav_ratio_medio <- renderValueBox({
      df <- df_favs()
      val <- if (!is.null(df) && nrow(df) > 0 && all(c("precio", "superficie") %in% names(df))) {
        round(mean(df$precio / df$superficie, na.rm = TRUE), 1)
      } else { 0 }
      valueBox(paste0(val, " €/m²"), "Ratio Medio €/m²", icon = icon("calculator"), color = "green")
    })
    
    # Tabla DT de Favoritos
    output$tabla_favoritos <- renderDT({
      df <- df_favs()
      
      if (is.null(df) || nrow(df) == 0) {
        return(datatable(
          data.frame(Mensaje = "No has marcado ningún inmueble como favorito aún."),
          options = list(dom = 't'),
          rownames = FALSE
        ))
      }
      
      datatable(
        df,
        options = list(pageLength = 10, dom = 'tip', scrollX = TRUE),
        rownames = FALSE
      )
    })
    
    # Exportación
    output$descargar_favs_csv <- downloadHandler(
      filename = function() {
        paste0("GeoAlquiler_Favoritos_", format(Sys.Date(), "%Y%m%d"), ".csv")
      },
      content = function(file) {
        write.csv(df_favs(), file, row.names = FALSE)
      }
    )
    
  })
}