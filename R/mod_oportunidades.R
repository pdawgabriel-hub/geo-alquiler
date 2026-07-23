# Módulo para la detección y análisis de Oportunidades Inmobiliarias

# 1. UI DEL MÓDULO
oportunidadesUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "Criterio de Identificación de Oportunidades", 
        width = 12, 
        status = "primary", 
        solidHeader = TRUE,
        fluidRow(
          column(8,
            p("Se consideran ", strong("Oportunidades Inmobiliarias"), " aquellos inmuebles cuyo precio por m² es inferior al valor medio de su mercado (ciudad y tipo).")
          ),
          column(4,
            sliderInput(
              ns("pct_descuento"), 
              "Umbral de Oportunidad (% por debajo de la media):", 
              min = 5, max = 35, value = 15, step = 5, post = "%"
            )
          )
        )
      )
    ),
    
    fluidRow(
      valueBoxOutput(ns("kpi_num_oportunidades"), width = 4),
      valueBoxOutput(ns("kpi_ahorro_medio"), width = 4),
      valueBoxOutput(ns("kpi_precio_m2_oportunidad"), width = 4)
    ),
    
    fluidRow(
      box(
        title = "Mapa de Oportunidades Identificadas", 
        width = 6, 
        status = "info", 
        solidHeader = TRUE,
        leafletOutput(ns("mapa_oportunidades"), height = 400)
      ),
      box(
        title = "Listado de Inmuebles Destacados", 
        width = 6, 
        status = "info", 
        solidHeader = TRUE,
        DTOutput(ns("tabla_oportunidades"), height = 400)
      )
    )
  )
}

# 2. SERVER DEL MÓDULO
oportunidadesServer <- function(id, datos_visibles) {
  moduleServer(id, function(input, output, session) {
    
    # Cálculo reactivo de oportunidades
    df_oportunidades <- reactive({
      df <- datos_visibles()
      if (is.null(df) || nrow(df) == 0) return(NULL)
      
      # Trabajar sobre una copia limpia
      df_calc <- df
      
      # Calcular precio por m2 individual
      df_calc$precio_m2 <- df_calc$precio / df_calc$superficie
      
      # Calcular la media por ciudad dentro de los datos visibles
      medias_ciudad <- aggregate(precio_m2 ~ ciudad, data = df_calc, FUN = mean)
      colnames(medias_ciudad)[2] <- "media_ciudad_m2"
      
      # Unir con el dataset principal
      df_calc <- merge(df_calc, medias_ciudad, by = "ciudad")
      
      # Ratio de diferencia frente a la media
      df_calc$pct_diferencia <- ((df_calc$media_ciudad_m2 - df_calc$precio_m2) / df_calc$media_ciudad_m2) * 100
      
      # Filtrar las oportunidades que superen el umbral seleccionado
      oportunidades <- df_calc[df_calc$pct_diferencia >= input$pct_descuento, ]
      
      # Ordenar por mayor porcentaje de oportunidad
      if (nrow(oportunidades) > 0) {
        oportunidades <- oportunidades[order(-oportunidades$pct_diferencia), ]
      }
      
      return(oportunidades)
    })
    
    # --- KPIs ---
    output$kpi_num_oportunidades <- renderValueBox({
      df <- df_oportunidades()
      n <- if (!is.null(df)) nrow(df) else 0
      valueBox(n, "Oportunidades Detectadas", icon = icon("star"), color = "yellow")
    })
    
    output$kpi_ahorro_medio <- renderValueBox({
      df <- df_oportunidades()
      dif_media <- if (!is.null(df) && nrow(df) > 0) round(mean(df$pct_diferencia), 1) else 0
      valueBox(paste0("-", dif_media, "%"), "Descuento Medio vs Mercado", icon = icon("arrow-down"), color = "green")
    })
    
    output$kpi_precio_m2_oportunidad <- renderValueBox({
      df <- df_oportunidades()
      pm2 <- if (!is.null(df) && nrow(df) > 0) round(mean(df$precio_m2), 1) else 0
      valueBox(paste0(pm2, " €/m²"), "Precio/m² Medio Oportunidades", icon = icon("tag"), color = "blue")
    })
    
    # --- MAPA DE OPORTUNIDADES ---
    output$mapa_oportunidades <- renderLeaflet({
      df <- df_oportunidades()
      
      m <- leaflet() %>% 
        addProviderTiles(providers$CartoDB.Positron)
      
      if (!is.null(df) && nrow(df) > 0) {
        
        # Extracción ultrasegura de coordenadas sin importar el origen
        longitudes <- NULL
        latitudes <- NULL
        
        try({
          if (inherits(df, "sf")) {
            coords <- sf::st_coordinates(df)
            longitudes <- coords[, 1]
            latitudes <- coords[, 2]
          } else if ("longitud" %in% names(df) && "latitud" %in% names(df)) {
            longitudes <- df$longitud
            latitudes <- df$latitud
          } else if ("lng" %in% names(df) && "lat" %in% names(df)) {
            longitudes <- df$lng
            latitudes <- df$lat
          } else if ("lon" %in% names(df) && "lat" %in% names(df)) {
            longitudes <- df$lon
            latitudes <- df$lat
          }
        }, silent = TRUE)
        
        # Solo pintamos si logramos extraer las coordenadas correctamente
        if (!is.null(longitudes) && !is.null(latitudes)) {
          popups <- paste0(
            "<b>Oportunidad Inmobiliaria</b><br>",
            "<b>Ciudad:</b> ", df$ciudad, "<br>",
            "<b>Precio:</b> ", df$precio, " €<br>",
            "<b>Superficie:</b> ", df$superficie, " m²<br>",
            "<b>Precio/m²:</b> ", round(df$precio_m2, 1), " €/m²<br>",
            "<b>Descuento vs. media:</b> -", round(df$pct_diferencia, 1), "%"
          )
          
          m <- m %>% addCircleMarkers(
            lng = as.numeric(longitudes),
            lat = as.numeric(latitudes),
            radius = 7,
            color = "#e67e22",
            fillOpacity = 0.8,
            popup = popups
          )
        }
      }
      
      return(m)
    })
    
    # --- TABLA DE OPORTUNIDADES ---
    output$tabla_oportunidades <- renderDT({
      df <- df_oportunidades()
      if (is.null(df) || nrow(df) == 0) return(NULL)
      
      df_sub <- df[, c("ciudad", "tipo", "precio", "superficie", "precio_m2", "pct_diferencia")]
      df_sub$precio_m2 <- round(df_sub$precio_m2, 1)
      df_sub$pct_diferencia <- round(df_sub$pct_diferencia, 1)
      
      colnames(df_sub) <- c("Ciudad", "Tipo", "Precio (€)", "Superficie (m²)", "€/m²", "Margen (%)")
      
      datatable(
        df_sub,
        options = list(pageLength = 5, dom = 'tp', language = list(url = '//cdn.datatables.net/plug-ins/1.10.11/i18n/Spanish.json')),
        rownames = FALSE
      )
    })
    
  })
}