# Módulo del mapa interactivo con marcadores, clustering y mapa de calor (Heatmap)

# 1. UI DEL MÓDULO
mapaUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = "Distribución Geográfica y Capa de Calor", 
    width = 12, 
    solidHeader = TRUE, 
    status = "primary",
    leafletOutput(ns("mapa_alquiler"), height = 480)
  )
}

# 2. SERVER DEL MÓDULO
mapaServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    output$mapa_alquiler <- renderLeaflet({
      df <- datos_reactivos()
      
      if (nrow(df) == 0) {
        return(
          leaflet() %>% 
            addTiles() %>% 
            setView(lng = -3.70379, lat = 40.416775, zoom = 5)
        )
      }
      
      paleta_colores <- colorNumeric(
        palette = c("#2ecc71", "#f39c12", "#e74c3c"),
        domain = df$precio
      )
      
      leaflet(df) %>%
        addProviderTiles(providers$CartoDB.Positron, group = "Mapa Claro") %>%
        addProviderTiles(providers$CartoDB.DarkMatter, group = "Mapa Oscuro") %>%
        addTiles(group = "OpenStreetMap") %>%
        
        setView(lng = -3.70379, lat = 40.416775, zoom = 5) %>%
        
        # CAPA 1: Marcadores individuales con clustering
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
        
        # LEYENDA
        addLegend(
          position = "bottomright",
          pal = paleta_colores,
          values = ~precio,
          title = "Precio (€)",
          opacity = 0.9
        ) %>%
        
        # CONTROLLER DE CAPAS (Base y Calidad)
        addLayersControl(
          baseGroups = c("Mapa Claro", "Mapa Oscuro", "OpenStreetMap"),
          overlayGroups = c("Inmuebles (Puntos)"),
          options = layersControlOptions(collapsed = FALSE)
        )
    })
    
  })
}