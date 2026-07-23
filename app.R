library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)

# 0. CARGA DE MÓDULOS Y DATOS
source("R/mod_filtros.R")
source("R/mod_mapa.R")
source("R/mod_graficos.R")

datos_totales <- readRDS("data/processed/alquileres.rds")

# 1. INTERFAZ DE USUARIO (UI / Frontend)
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "GeoAlquiler"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Panel Principal", tabName = "panel", icon = icon("dashboard")),
      menuItem("Analítica Avanzada", tabName = "analitica", icon = icon("chart-line")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    ),
    hr(),
    # Módulo de Filtros
    filtrosUI("filtros_sidebar")
  ),
  
  dashboardBody(
    tabItems(
      # PESTAÑA 1: Panel Principal (Mapa y KPIs)
      tabItem(tabName = "panel",
        fluidRow(
          valueBoxOutput("kpi_precio_medio", width = 4),
          valueBoxOutput("kpi_superficie_media", width = 4),
          valueBoxOutput("kpi_total_inmuebles", width = 4)
        ),
        fluidRow(
          mapaUI("mapa_principal")
        )
      ),
      
      # PESTAÑA 2: Analítica Avanzada (Módulo de Gráficos completo)
      tabItem(tabName = "analitica",
        graficosUI("grafico_principal")
      ),
      
      # PESTAÑA 3: Información
      tabItem(tabName = "informacion",
        h2("Sobre GeoAlquiler"),
        p("Dashboard analítico desarrollado en R Shiny para la exploración interactiva del mercado inmobiliario.")
      )
    )
  )
)

# 2. LÓGICA DEL SERVIDOR (Server / Backend)
server <- function(input, output, session) {
  
  # Filtros globales
  datos_filtrados <- filtrosServer("filtros_sidebar", datos_totales)
  
  # KPIs de la portada
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
  
  # Inicialización de Servidores Modulares
  mapaServer("mapa_principal", datos_filtrados)
  graficosServer("grafico_principal", datos_filtrados)
}

shinyApp(ui = ui, server = server)