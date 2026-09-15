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

GRUPO_BARRIOS <- "Resumen por Barrio"
GRUPO_INDIVIDUALES <- "Inmuebles Individuales"
GRUPO_CALOR <- "Mapa de Calor (Densidad)"

mapaServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {

    # Datos limpios (sin coordenadas/precio ausentes), reutilizados por la
    # capa agregada y por las capas bajo demanda (individuales / calor).
    datos_limpios <- reactive({
      df <- datos_reactivos()
      if (is.null(df) || nrow(df) == 0) return(df)
      df[!is.na(df$lat) & !is.na(df$lng) & !is.na(df$precio), ]
    })

    # Agregación en servidor por barrio: en vez de mandar al navegador cada
    # inmueble (miles de puntos), se resume a un punto por barrio con su
    # centroide, precio medio y nº de inmuebles -- esta es la capa por
    # defecto del mapa, muchísimo más ligera en móvil.
    agregado_barrio <- reactive({
      df <- datos_limpios()
      req(df, nrow(df) > 0, "barrio" %in% names(df))
      df <- df[!is.na(df$barrio), ]

      agg <- aggregate(
        cbind(lat, lng, precio) ~ ciudad + barrio,
        data = df, FUN = mean
      )
      agg$n_inmuebles <- as.numeric(
        table(paste(df$ciudad, df$barrio))[paste(agg$ciudad, agg$barrio)]
      )
      names(agg)[names(agg) == "precio"] <- "precio_medio"
      agg
    })

    output$mapa_alquiler <- renderLeaflet({
      df <- datos_limpios()

      # Si no hay datos, mostramos un mapa neutro centrado en España/Europa
      if (is.null(df) || nrow(df) == 0) {
        return(
          leaflet() %>%
            addTiles() %>%
            setView(lng = -3.70379, lat = 40.416775, zoom = 5)
        )
      }

      agg <- agregado_barrio()

      paleta_colores <- colorNumeric(
        palette = c("#2ecc71", "#f39c12", "#e74c3c"),
        domain = df$precio
      )

      leaflet() %>%
        addProviderTiles(providers$CartoDB.Positron, group = "Mapa Claro") %>%
        addProviderTiles(providers$CartoDB.DarkMatter, group = "Mapa Oscuro") %>%
        addTiles(group = "OpenStreetMap") %>%
        setView(lng = -3.70379, lat = 40.416775, zoom = 5) %>%
        # Capa por defecto: un punto agregado por barrio (precio medio + oferta)
        addCircleMarkers(
          data = agg,
          lng = ~lng, lat = ~lat,
          radius = ~pmin(28, 8 + sqrt(n_inmuebles) * 2),
          color = ~paleta_colores(precio_medio),
          fillOpacity = 0.85,
          stroke = TRUE, weight = 1,
          group = GRUPO_BARRIOS,
          popup = ~paste0(
            "<div style='font-family: sans-serif; font-size: 13px;'>",
              "<h4 style='margin:0 0 5px 0; color:#2c3e50;'>", barrio, " (", ciudad, ")</h4>",
              "<b>Precio medio:</b> <span style='color:#e74c3c; font-weight:bold;'>", round(precio_medio), " €/mes</span><br>",
              "<b>Inmuebles en la zona:</b> ", n_inmuebles,
            "</div>"
          )
        ) %>%
        addLegend(
          position = "bottomright",
          pal = paleta_colores,
          values = df$precio,
          title = "Precio (€)",
          opacity = 0.9
        ) %>%
        # Selector de capas: "Inmuebles Individuales" y "Mapa de Calor" no se
        # cargan aquí -- se construyen bajo demanda (ver observer de abajo)
        # solo si el usuario las activa, para no penalizar la carga inicial.
        addLayersControl(
          baseGroups = c("Mapa Claro", "Mapa Oscuro", "OpenStreetMap"),
          overlayGroups = c(GRUPO_BARRIOS, GRUPO_INDIVIDUALES, GRUPO_CALOR),
          options = layersControlOptions(collapsed = TRUE)
        ) %>%
        # Las capas de detalle empiezan desmarcadas: al declararlas en
        # overlayGroups sin ocultarlas quedarían "activas" por defecto y el
        # observer de carga perezosa las construiría igualmente al arrancar.
        hideGroup(GRUPO_INDIVIDUALES) %>%
        hideGroup(GRUPO_CALOR)
    })

    # Carga perezosa de las capas de detalle (pines individuales y heatmap):
    # se construyen solo si su grupo está activo en el control de capas, y se
    # reconstruyen si cambian los filtros mientras están activas. Si no están
    # activas, se limpian para no dejar datos obsoletos cargados en el mapa.
    observe({
      df <- datos_limpios()
      req(df)
      grupos_activos <- input$mapa_alquiler_groups
      proxy <- leafletProxy("mapa_alquiler")

      proxy %>% clearGroup(GRUPO_INDIVIDUALES)
      if (GRUPO_INDIVIDUALES %in% grupos_activos && nrow(df) > 0) {
        paleta_colores <- colorNumeric(
          palette = c("#2ecc71", "#f39c12", "#e74c3c"),
          domain = df$precio
        )
        proxy %>% addCircleMarkers(
          data = df,
          lng = ~lng, lat = ~lat,
          radius = 7,
          color = ~paleta_colores(precio),
          fillOpacity = 0.85,
          stroke = TRUE, weight = 1,
          group = GRUPO_INDIVIDUALES,
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
        )
      }

      proxy %>% clearGroup(GRUPO_CALOR)
      if (GRUPO_CALOR %in% grupos_activos && nrow(df) > 0) {
        proxy %>% addHeatmap(
          data = df,
          lng = ~lng, lat = ~lat,
          intensity = ~precio,
          blur = 20, max = max(df$precio, na.rm = TRUE), radius = 15,
          group = GRUPO_CALOR
        )
      }
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