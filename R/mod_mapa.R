# Módulo dedicado exclusivamente al renderizado y gestión del mapa Leaflet

# 1. UI del Módulo
mapaUI <- function(id) {
  ns <- NS(id) # Creamos el Namespace para aislar las IDs
  
  box(
    title = "Mapa de Inmuebles Filtrados", 
    width = 8, 
    solidHeader = TRUE, 
    status = "primary",
    leafletOutput(ns("mapa_alquiler"), height = 420) # ¡Atención al ns()!
  )
}

# 2. Server del Módulo
mapaServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    output$mapa_alquiler <- renderLeaflet({
      df <- datos_reactivos() # Leemos los datos reactivos que nos pasan
      
      leaflet(df) %>%
        addTiles() %>%
        setView(lng = -3.70379, lat = 40.416775, zoom = 5) %>%
        addCircleMarkers(
          lng = ~lng, lat = ~lat,
          radius = 6,
          color = "#3c8dbc",
          fillOpacity = 0.8,
          popup = ~paste0("<b>", tipo, " en ", ciudad, "</b><br>",
                          "Precio: ", precio, " €/mes<br>",
                          "Superficie: ", superficie, " m²")
        )
    })
    
  })
}