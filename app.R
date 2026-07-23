library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)

# 0. CARGA DE MÓDULOS Y DATOS
# Al poner los scripts en la carpeta R/, los cargamos limpiamente con source:
source("R/mod_mapa.R")
source("R/mod_graficos.R")

datos_totales <- readRDS("data/processed/alquileres.rds")

# 1. INTERFAZ DE USUARIO (UI / Frontend)
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "GeoAlquiler"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Panel de Control", tabName = "panel", icon = icon("dashboard")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    ),
    hr(),
    sliderInput("filtro_precio", "Rango de Precio (€):", 
                min = 500, max = 2800, value = c(600, 2000), step = 50),
    selectInput("filtro_tipo", "Tipo de Propiedad:", 
                choices = c("Todos", "Piso", "Casa", "Ático", "Estudio"))
  ),
  
  dashboardBody(
    tabItems(
      tabItem(tabName = "panel",
        fluidRow(
          valueBoxOutput("kpi_precio_medio", width = 4),
          valueBoxOutput("kpi_superficie_media", width = 4),
          valueBoxOutput("kpi_total_inmuebles", width = 4)
        ),
        fluidRow(
          # LLAMADA A LA UI DE LOS MÓDULOS
          mapaUI("mapa_principal"),
          graficosUI("grafico_principal")
        )
      ),
      tabItem(tabName = "informacion",
        h2("Proyecto para portfolio"),
        p("Dashboard interactivo desarrollado en R Shiny para visualizar el mercado del alquiler.")
      )
    )
  )
)

# 2. LÓGICA DEL SERVIDOR (Server / Backend)
server <- function(input, output, session) {
  
  # Filtro reactivo principal
  datos_filtrados <- reactive({
    tabla <- datos_totales
    tabla <- tabla[tabla$precio >= input$filtro_precio[1] & tabla$precio <= input$filtro_precio[2], ]
    if (input$filtro_tipo != "Todos") {
      tabla <- tabla[tabla$tipo == input$filtro_tipo, ]
    }
    return(tabla)
  })
  
  # KPIs simples del Dashboard
  output$kpi_precio_medio <- renderValueBox({
    df <- datos_filtrados()
    precio_med <- ifelse(nrow(df) > 0, round(mean(df$precio)), 0)
    valueBox(paste0(precio_med, " €"), "Precio Medio", icon = icon("eur"), color = "purple")
  })
  
  output$kpi_superficie_media <- renderValueBox({
    df <- datos_filtrados()
    sup_med <- ifelse(nrow(df) > 0, round(mean(df$superficie)), 0)
    valueBox(paste0(sup_med, " m²"), "Superficie Media", icon = icon("home"), color = "green")
  })
  
  output$kpi_total_inmuebles <- renderValueBox({
    df <- datos_filtrados()
    valueBox(nrow(df), "Inmuebles Encontrados", icon = icon("building"), color = "blue")
  })
  
  # LLAMADA AL SERVER DE LOS MÓDULOS
  # Les pasamos la misma tabla reactiva 'datos_filtrados'
  mapaServer("mapa_principal", datos_filtrados)
  graficosServer("grafico_principal", datos_filtrados)
}

shinyApp(ui = ui, server = server)