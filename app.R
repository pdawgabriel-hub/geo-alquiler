library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)

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
    # Filtros interactivos
    sliderInput("precio", "Rango de Precio (€):", 
                min = 400, max = 3000, value = c(600, 1500)),
    selectInput("tipo", "Tipo de Propiedad:", 
                choices = c("Todos", "Piso", "Casa", "Ático", "Estudio"))
  ),
  
  # Cuerpo principal de la aplicación
  dashboardBody(
    tabItems(
      # Pestaña Principal (Panel de Control)
      tabItem(tabName = "panel",
        fluidRow(
          # Tarjetas de indicadores (KPIs)
          valueBox("1.250 €", "Precio Medio", icon = icon("eur"), color = "purple"),
          valueBox("85 m²", "Superficie Media", icon = icon("home"), color = "green"),
          valueBox("4,2", "Ratio de Demanda", icon = icon("users"), color = "yellow")
        ),
        fluidRow(
          # Contenedor para el Mapa de Leaflet
          box(title = "Distribución Geográfica de Alquileres", width = 8, solidHeader = TRUE, status = "primary",
              leafletOutput("mapa_alquiler", height = 400)),
          # Contenedor para Gráficos Interactivos
          box(title = "Distribución por Precios", width = 4, solidHeader = TRUE, status = "warning",
              plotlyOutput("grafico_precios", height = 400))
        )
      ),
      # Pestaña de Información
      tabItem(tabName = "informacion",
        h2("Sobre este proyecto"),
        p("Dashboard interactivo para el análisis del mercado del alquiler en tiempo real en España.")
      )
    )
  )
)

# 2. LÓGICA DEL SERVIDOR (Server / Backend)
server <- function(input, output, session) {
  
  # Renderizado del Mapa con Leaflet
  output$mapa_alquiler <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%  # Carga el mapa base de OpenStreetMap
      setView(lng = -3.70379, lat = 40.416775, zoom = 6) # Centrado en España
  })
  
  # Renderizado del gráfico de barras/histograma con Plotly
  output$grafico_precios <- renderPlotly({
    # Generamos datos de prueba
    datos_simulados <- data.frame(
      Precio = rnorm(100, mean = 1000, sd = 250)
    )
    p <- ggplot(datos_simulados, aes(x = Precio)) + 
      geom_histogram(fill = "#f0ad4e", color = "white", bins = 15) +
      theme_minimal() +
      labs(x = "Precio (€)", y = "Cantidad")
    
    ggplotly(p) # Convierte el gráfico a interactivo
  })
}

# 3. LANZADOR DE LA APLICACIÓN
shinyApp(ui = ui, server = server)