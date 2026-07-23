library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)

# 0. CARGA DE DATOS (Se ejecuta solo 1 vez al arrancar la app)
# Leemos los datos que acabamos de generar con el script anterior
datos_totales <- readRDS("data/processed/alquileres.rds")

# 1. INTERFAZ DE USUARIO (UI / Frontend)
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "GeoAlquiler"),
  
  # Barra lateral con filtros
  dashboardSidebar(
    sidebarMenu(
      menuItem("Panel de Control", tabName = "panel", icon = icon("dashboard")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    ),
    hr(),
    # Filtro 1: Slider de rango de precios
    sliderInput("filtro_precio", "Rango de Precio (€):", 
                min = 500, max = 2800, value = c(600, 2000), step = 50),
    # Filtro 2: Selector de tipo de vivienda
    selectInput("filtro_tipo", "Tipo de Propiedad:", 
                choices = c("Todos", "Piso", "Casa", "Ático", "Estudio"))
  ),
  
  # Cuerpo principal de la aplicación
  dashboardBody(
    tabItems(
      # Pestaña Principal (Panel de Control)
      tabItem(tabName = "panel",
        fluidRow(
          # Tarjetas de indicadores (KPIs) conectadas a los datos
          valueBoxOutput("kpi_precio_medio", width = 4),
          valueBoxOutput("kpi_superficie_media", width = 4),
          valueBoxOutput("kpi_total_inmuebles", width = 4)
        ),
        fluidRow(
          # Contenedor para el Mapa
          box(title = "Mapa de Inmuebles Filtrados", width = 8, solidHeader = TRUE, status = "primary",
              leafletOutput("mapa_alquiler", height = 420)),
          # Contenedor para el Gráfico
          box(title = "Distribución por Precios", width = 4, solidHeader = TRUE, status = "warning",
              plotlyOutput("grafico_precios", height = 420))
        )
      ),
      # Pestaña de Información
      tabItem(tabName = "informacion",
        h2("Sobre este proyecto"),
        p("Dashboard interactivo desarrollado en R Shiny para visualizar el mercado del alquiler.")
      )
    )
  )
)

# 2. LÓGICA DEL SERVIDOR (Server / Backend)
server <- function(input, output, session) {
  
  # EXPRESIÓN REACTIVA
  # Este bloque 'datos_filtrados' escucha los cambios en input$filtro_precio e input$filtro_tipo.
  # Cada vez que mueves un filtro en la UI, esta tabla se recalcula automáticamente.
  datos_filtrados <- reactive({
    tabla <- datos_totales
    
    # 1. Filtramos por el rango de precio seleccionado en el slider
    tabla <- tabla[tabla$precio >= input$filtro_precio[1] & tabla$precio <= input$filtro_precio[2], ]
    
    # 2. Si se selecciona un tipo específico que no sea "Todos", filtramos por tipo
    if (input$filtro_tipo != "Todos") {
      tabla <- tabla[tabla$tipo == input$filtro_tipo, ]
    }
    
    return(tabla)
  })
  
  # INDICADORES DINÁMICOS (KPIs)
  output$kpi_precio_medio <- renderValueBox({
    df <- datos_filtrados() # Llamamos a la tabla filtrada (¡ojo a los paréntesis!)
    precio_med <- ifelse(nrow(df) > 0, round(mean(df$precio)), 0)
    
    valueBox(
      value = paste0(precio_med, " €"),
      subtitle = "Precio Medio",
      icon = icon("eur"),
      color = "purple"
    )
  })
  
  output$kpi_superficie_media <- renderValueBox({
    df <- datos_filtrados()
    sup_med <- ifelse(nrow(df) > 0, round(mean(df$superficie)), 0)
    
    valueBox(
      value = paste0(sup_med, " m²"),
      subtitle = "Superficie Media",
      icon = icon("home"),
      color = "green"
    )
  })
  
  output$kpi_total_inmuebles <- renderValueBox({
    df <- datos_filtrados()
    
    valueBox(
      value = nrow(df),
      subtitle = "Inmuebles Encontrados",
      icon = icon("building"),
      color = "blue"
    )
  })
  
  # RENDERIZADO DEL MAPA CON LEAFLET
  output$mapa_alquiler <- renderLeaflet({
    df <- datos_filtrados()
    
    leaflet(df) %>%
      addTiles() %>%  # Carga el mapa base
      setView(lng = -3.70379, lat = 40.416775, zoom = 5) %>%
      # Añade chinchetas con los pisos filtrados
      addCircleMarkers(
        lng = ~lng, lat = ~lat,
        radius = 6,
        color = "#3c8dbc",
        fillOpacity = 0.8,
        # Pop-up al hacer clic en un punto del mapa
        popup = ~paste0("<b>", tipo, " en ", ciudad, "</b><br>",
                        "Precio: ", precio, " €/mes<br>",
                        "Superficie: ", superficie, " m²")
      )
  })
  
  # RENDERIZADO DEL GRÁFICO CON PLOTLY
  output$grafico_precios <- renderPlotly({
    df <- datos_filtrados()
    
    if (nrow(df) == 0) return(NULL) # Si no hay datos, no dibujamos el gráfico
    
    p <- ggplot(df, aes(x = precio)) + 
      geom_histogram(fill = "#f0ad4e", color = "white", bins = 12) +
      theme_minimal() +
      labs(x = "Precio (€)", y = "Cantidad")
    
    ggplotly(p)
  })
}

# 3. LANZADOR DE LA APLICACIÓN
shinyApp(ui = ui, server = server)