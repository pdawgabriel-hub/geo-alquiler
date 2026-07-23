# Módulo avanzado para el mapa Leaflet con clustering, capas y paleta de colores

# 1. UI DEL MÓDULO
mapaUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = "Mapa de Inmuebles Filtrados", 
    width = 8, 
    solidHeader = TRUE, 
    status = "primary",
    leafletOutput(ns("mapa_alquiler"), height = 450)
  )
}

# 2. SERVER DEL MÓDULO
mapaServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    output$mapa_alquiler <- renderLeaflet({
      df <- datos_reactivos()
      
      # Si la tabla filtrada no tiene filas, renderizamos un mapa vacío centrado
      if (nrow(df) == 0) {
        return(
          leaflet() %>% 
            addTiles() %>% 
            setView(lng = -3.70379, lat = 40.416775, zoom = 5)
        )
      }
      
      # PALETA DE COLORES SEGÚN PRECIO
      # Creamos una función de color dinámica: Verde (< 1000€), Naranja (1000-1800€), Rojo (> 1800€)
      paleta_colores <- colorNumeric(
        palette = c("#2ecc71", "#f39c12", "#e74c3c"),
        domain = df$precio
      )
      
      leaflet(df) %>%
        # CAPAS DE MAPA BASE
        addProviderTiles(providers$CartoDB.Positron, group = "Mapa Claro (Por defecto)") %>%
        addProviderTiles(providers$CartoDB.DarkMatter, group = "Mapa Oscuro") %>%
        addTiles(group = "OpenStreetMap") %>%
        
        setView(lng = -3.70379, lat = 40.416775, zoom = 5) %>%
        
        # MARCADORES CON CLUSTERING Y COLORES DINÁMICOS
        addCircleMarkers(
          lng = ~lng, 
          lat = ~lat,
          radius = 7,
          color = ~paleta_colores(precio), # Aplicamos el color según precio
          fillOpacity = 0.85,
          stroke = TRUE,
          weight = 1,
          
          # CLUSTERING INTERACTIVO
          clusterOptions = markerClusterOptions(
            showCoverageOnHover = FALSE,
            zoomToBoundsOnClick = TRUE
          ),
          
          # POPUP CON ESTILO HTML
          popup = ~paste0(
            "<div style='font-family: sans-serif; font-size: 13px;'>",
              "<h4 style='margin:0 0 5px 0; color:#2c3e50;'>", tipo, " en ", ciudad, "</h4>",
              "<b>Precio:</b> <span style='color:#e74c3c; font-size:14px; font-weight:bold;'>", precio, " €/mes</span><br>",
              "<b>Superficie:</b> ", superficie, " m²<br>",
              "<b>Precio/m²:</b> ", round(precio / superficie, 1), " €/m²",
            "</div>"
          )
        ) %>%
        
        # LEYENDA EN LA ESQUINA INFERIOR DERECHA
        addLegend(
          position = "bottomright",
          pal = paleta_colores,
          values = ~precio,
          title = "Precio (€)",
          opacity = 0.9
        ) %>%
        
        # CONTROLADOR PARA CAMBIAR EL ESTILO DEL MAPA
        addLayersControl(
          baseGroups = c("Mapa Claro (Por defecto)", "Mapa Oscuro", "OpenStreetMap"),
          options = layersControlOptions(collapsed = TRUE)
        )
    })
    
  })
}