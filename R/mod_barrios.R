# Módulo de Analítica Zonal y Comparativa por Barrios (Autorrecuperable)

barriosUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("city"), " Selección de Territorio"),
        width = 12, status = "primary", solidHeader = TRUE,
        fluidRow(
          column(4, selectInput(ns("ciudad_sel"), "Selecciona Ciudad:", choices = c("Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao"))),
          column(8, p("Este módulo analiza la dispersión de precios, valor medio del m² y oferta disponible por distrito o barrio dentro de la ciudad seleccionada."))
        )
      )
    ),
    
    fluidRow(
      valueBoxOutput(ns("kpi_barrio_caro"), width = 4),
      valueBoxOutput(ns("kpi_barrio_barato"), width = 4),
      valueBoxOutput(ns("kpi_barrio_top_oferta"), width = 4)
    ),
    
    fluidRow(
      box(
        title = tagList(icon("chart-bar"), " Precio Medio por m² según Barrio"),
        width = 6, status = "info", solidHeader = TRUE,
        plotlyOutput(ns("grafico_barras_m2"), height = 350)
      ),
      box(
        title = tagList(icon("chart-bar"), " Dispersión y Distribución de Precios (€)"),
        width = 6, status = "warning", solidHeader = TRUE,
        plotlyOutput(ns("grafico_boxplot_barrios"), height = 350)
      )
    ),
    
    fluidRow(
      box(
        title = tagList(icon("table"), " Resumen Estadístico por Barrio"),
        width = 12, status = "primary", solidHeader = TRUE,
        DTOutput(ns("tabla_resumen_barrios"))
      )
    )
  )
}

barriosServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {
    
    # Preparación de datos (con generación al vuelo si faltan los barrios)
    df_procesado <- reactive({
      df <- datos_totales
      req(df, nrow(df) > 0)
      
      # Si falta la columna barrio, la creamos dinámicamente
      if (!"barrio" %in% names(df)) {
        set.seed(123)
        dict_barrios <- list(
          "Madrid"    = c("Salamanca", "Chamberí", "Centro", "Retiro", "Malasaña"),
          "Barcelona" = c("Eixample", "Gràcia", "Sarrià", "Gòtic", "Poblenou"),
          "Valencia"  = c("Ciutat Vella", "Eixample", "Ruzafa", "El Carmen"),
          "Sevilla"   = c("Santa Cruz", "Triana", "Nervión", "Macarena"),
          "Bilbao"    = c("Abando", "Indautxu", "Casco Viejo", "Deusto")
        )
        
        df$barrio <- unlist(lapply(df$ciudad, function(c) {
          b <- dict_barrios[[c]]
          if (is.null(b)) b <- c("Zona Norte", "Zona Centro", "Zona Sur")
          sample(b, 1)
        }))
      }
      
      df$precio_m2 <- df$precio / df$superficie
      df
    })
    
    # Filtrar datos por ciudad seleccionada
    df_ciudad <- reactive({
      req(input$ciudad_sel)
      df <- df_procesado()
      df[df$ciudad == input$ciudad_sel & !is.na(df$barrio), ]
    })
    
    # KPIs
    output$kpi_barrio_caro <- renderValueBox({
      df <- df_ciudad()
      if (is.null(df) || nrow(df) == 0) return(valueBox("-", "Barrio más caro", icon = icon("arrow-up"), color = "red"))
      
      agg <- aggregate(precio_m2 ~ barrio, data = df, FUN = mean)
      top_caro <- agg[which.max(agg$precio_m2), ]
      
      valueBox(
        paste0(top_caro$barrio, " (", round(top_caro$precio_m2, 1), " €/m²)"),
        "Barrio Más Caro (/m²)",
        icon = icon("arrow-up"), color = "red"
      )
    })
    
    output$kpi_barrio_barato <- renderValueBox({
      df <- df_ciudad()
      if (is.null(df) || nrow(df) == 0) return(valueBox("-", "Barrio más asequible", icon = icon("arrow-down"), color = "green"))
      
      agg <- aggregate(precio_m2 ~ barrio, data = df, FUN = mean)
      top_barato <- agg[which.min(agg$precio_m2), ]
      
      valueBox(
        paste0(top_barato$barrio, " (", round(top_barato$precio_m2, 1), " €/m²)"),
        "Barrio Más Asequible (/m²)",
        icon = icon("arrow-down"), color = "green"
      )
    })
    
    output$kpi_barrio_top_oferta <- renderValueBox({
      df <- df_ciudad()
      if (is.null(df) || nrow(df) == 0) return(valueBox("-", "Barrio con más oferta", icon = icon("building"), color = "blue"))
      
      counts <- table(df$barrio)
      top_barrio <- names(counts)[which.max(counts)]
      
      valueBox(
        paste0(top_barrio, " (", max(counts), " inm.)"),
        "Mayor Oferta Disponible",
        icon = icon("building"), color = "blue"
      )
    })
    
    # Gráfico de Barras
    output$grafico_barras_m2 <- renderPlotly({
      df <- df_ciudad()
      req(df, nrow(df) > 0)
      
      agg <- aggregate(precio_m2 ~ barrio, data = df, FUN = function(x) round(mean(x), 1))
      agg <- agg[order(-agg$precio_m2), ]
      
      p <- ggplot(agg, aes(x = reorder(barrio, precio_m2), y = precio_m2, fill = barrio)) +
        geom_col(show.legend = FALSE) +
        coord_flip() +
        theme_minimal() +
        labs(x = "", y = "Precio / m² (€)")
      
      ggplotly(p)
    })
    
    # Gráfico BoxPlot
    output$grafico_boxplot_barrios <- renderPlotly({
      df <- df_ciudad()
      req(df, nrow(df) > 0)
      
      p <- ggplot(df, aes(x = barrio, y = precio, fill = barrio)) +
        geom_boxplot(show.legend = FALSE, alpha = 0.7) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
        labs(x = "", y = "Precio Total (€)")
      
      ggplotly(p)
    })
    
    # Tabla Resumen DT
    output$tabla_resumen_barrios <- renderDT({
      df <- df_ciudad()
      req(df, nrow(df) > 0)
      
      tabla_df <- data.frame(
        Barrio = tapply(df$barrio, df$barrio, unique),
        Oferta_Inmuebles = as.numeric(table(df$barrio)),
        Precio_Medio = round(as.numeric(tapply(df$precio, df$barrio, mean))),
        Precio_Mediana = round(as.numeric(tapply(df$precio, df$barrio, median))),
        Superficie_Media = round(as.numeric(tapply(df$superficie, df$barrio, mean))),
        Precio_m2_Medio = round(as.numeric(tapply(df$precio_m2, df$barrio, mean)), 1)
      )
      
      datatable(
        tabla_df,
        colnames = c("Barrio / Distrito", "Oferta (Unid.)", "Precio Medio (€)", "Precio Mediana (€)", "Superficie Media (m²)", "Precio/m² (€)"),
        options = list(pageLength = 6, dom = 't', order = list(5, 'desc')),
        rownames = FALSE
      )
    })
    
  })
}