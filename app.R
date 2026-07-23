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
      menuItem("Panel de Control", tabName = "panel", icon = icon("dashboard")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    ),
    hr(),
    # LLAMADA AL MÓDULO DE FILTROS EN EL SIDEBAR
    filtrosUI("filtros_sidebar")
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
          mapaUI("mapa_principal"),
          graficosUI("grafico_principal")
        )
      ),
      tabItem(tabName = "informacion",
        h2("Sobre este proyecto"),
        p("Dashboard interactivo desarrollado en R Shiny para visualizar el mercado del alquiler.")
      )
    )
  )
)

# 2. LÓGICA DEL SERVIDOR (Server / Backend)
server <- function(input, output, session) {
  
  # 1. Conectamos el módulo de Filtros y recibimos la tabla reactiva
  datos_filtrados <- filtrosServer("filtros_sidebar", datos_totales)
  
  # KPIs dinámicos principales
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
  
  # 2. Pasamos la tabla reactiva a los módulos de visualización
  mapaServer("mapa_principal", datos_filtrados)
  graficosServer("grafico_principal", datos_filtrados)
}

shinyApp(ui = ui, server = server)