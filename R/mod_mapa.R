# Módulo de mapa interactivo con captura de encuadre (bounds) y capa de calor (Heatmap)

mapaUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = tagList(icon("map-marked-alt"), " Distribución Geográfica y Capa de Calor"), 
    width = 12, 
    solidHeader = TRUE, 
    status = "primary",
    leafletOutput(ns("mapa_alquiler"), height = 520)
  )
}

mapaServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    output$mapa_alquiler <- renderLeaflet({
      df <- datos_reactivos()
      
      # Si no hay datos, mostramos un mapa neutro centrado en España/Europa
      if (is.null(df) || nrow(df) == 0) {
        return(
          leaflet() %>% 
            addTiles() %>% 
            setView(lng = -3.70379, lat = 40.416775, zoom = 5)
        )
      }
      
      # Limpieza de registros sin coordenadas para no romper Leaflet / Heatmap
      df <- df[!is.na(df$lat) & !is.na(df$lng) & !is.na(df$precio), ]
      
      paleta_colores <- colorNumeric(
        palette = c("#2ecc71", "#f39c12", "#e74c3c"),
        domain = df$precio
      )
      
      mapa <- leaflet(df) %>%
        addProviderTiles(providers$CartoDB.Positron, group = "Mapa Claro") %>%
        addProviderTiles(providers$CartoDB.DarkMatter, group = "Mapa Oscuro") %>%
        addTiles(group = "OpenStreetMap") %>%
        setView(lng = -3.70379, lat = 40.416775, zoom = 5) %>%
        # Capa 1: Puntos agrupados (Clusters)
        addCircleMarkers(
          lng = ~lng, lat = ~lat,
          radius = 7,
          color = ~paleta_colores(precio),
          fillOpacity = 0.85,
          stroke = TRUE, weight = 1,
          group = "Inmuebles (Puntos)",
          clusterOptions = markerClusterOptions(
            showCoverageOnHover = FALSE,
            zoomToBoundsOnClick = TRUE
          ),
          popup = ~paste0(
            "<div style='font-family: sans-serif; font-size: 13px;'>",
              "<h4 style='margin:0 0 5px 0; color:#2c3e50;'>", tipo, " en ", ciudad, "</h4>",
              "<b>Precio:</b> <span style='color:#e74c3c; font-weight:bold;'>", precio, " €/mes</span><br>",
              "<b>Superficie:</b> ", superficie, " m²<br>",
              "<b>Precio/m²:</b> ", round(precio / superficie, 1), " €/m²",
            "</div>"
          )
        ) %>%
        # Capa 2: Mapa de Calor (Heatmap)
        addHeatmap(
          lng = ~lng, lat = ~lat,
          intensity = ~precio,
          blur = 20, max = max(df$precio, na.rm = TRUE), radius = 15,
          group = "Mapa de Calor (Densidad)"
        ) %>%
        addLegend(
          position = "bottomright",
          pal = paleta_colores,
          values = ~precio,
          title = "Precio (€)",
          opacity = 0.9
        ) %>%
        # Selector de Capas para activar/desactivar Puntos o Mapa de Calor
        addLayersControl(
          baseGroups = c("Mapa Claro", "Mapa Oscuro", "OpenStreetMap"),
          overlayGroups = c("Inmuebles (Puntos)", "Mapa de Calor (Densidad)"),
          options = layersControlOptions(collapsed = FALSE)
        ) %>%
        # Ocultamos por defecto la capa de calor para no saturar la vista inicial
        hideGroup("Mapa de Calor (Densidad)")
      
      mapa
    })
    
    # Devolvemos los datos delimitados espacialmente por el recuadro del mapa
    datos_en_pantalla <- reactive({
      df <- datos_reactivos()
      bounds <- input$mapa_alquiler_bounds
      
      # Si el usuario aún no ha movido o cargado los límites, mostramos todos los datos
      if (is.null(bounds) || is.null(df) || nrow(df) == 0) return(df)
      
      # Filtramos los inmuebles cuyas lat/lng están dentro de la ventana visible
      df[df$lat >= bounds$south & df$lat <= bounds$north &
         df$lng >= bounds$west & df$lng <= bounds$east, ]
    })
    
    return(datos_en_pantalla)
  })
}