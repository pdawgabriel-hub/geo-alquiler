library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)

# 0. CARGA DE MÓDULOS Y DATOS
source("R/mod_filtros.R")
source("R/mod_mapa.R")
source("R/mod_graficos.R")
source("R/mod_exportar.R") # Carga del nuevo módulo

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
    filtrosUI("filtros_sidebar")
  ),
  
  dashboardBody(
    tabItems(
      # PESTAÑA 1: Panel Principal
      tabItem(tabName = "panel",
        fluidRow(
          valueBoxOutput("kpi_precio_medio", width = 3),
          valueBoxOutput("kpi_superficie_media", width = 3),
          valueBoxOutput("kpi_precio_m2", width = 3),
          valueBoxOutput("kpi_total_inmuebles", width = 3)
        ),
        fluidRow(
          mapaUI("mapa_principal")
        )
      ),
      
      # PESTAÑA 2: Analítica Avanzada + Exportación
      tabItem(tabName = "analitica",
        graficosUI("grafico_principal"),
        fluidRow(
          exportarUI("exportar_datos") # Añadimos el bloque de descarga aquí
        )
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
  
  output$kpi_precio_m2 <- renderValueBox({
    df <- datos_filtrados()
    precio_m2 <- ifelse(nrow(df) > 0, round(mean(df$precio / df$superficie), 1), 0)
    valueBox(paste0(precio_m2, " €/m²"), "Precio/m² Medio", icon = icon("calculator"), color = "orange")
  })
  
  output$kpi_total_inmuebles <- renderValueBox({
    df <- datos_filtrados()
    valueBox(nrow(df), "Inmuebles Encontrados", icon = icon("building"), color = "blue")
  })
  
  # Inicialización de Servidores Modulares
  mapaServer("mapa_principal", datos_filtrados)
  graficosServer("grafico_principal", datos_filtrados)
  exportarServer("exportar_datos", datos_filtrados) # Conexión del server de exportación
}

shinyApp(ui = ui, server = server)