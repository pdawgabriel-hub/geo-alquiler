library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)
library(DT)

# 0. CARGA DE MÓDULOS Y DATOS
source("R/mod_filtros.R")
source("R/mod_mapa.R")
source("R/mod_graficos.R")
source("R/mod_tabla.R")
source("R/mod_calculadora.R")
source("R/mod_exportar.R")

datos_totales <- readRDS("data/processed/alquileres.rds")

# 1. INTERFAZ DE USUARIO (UI)
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "GeoAlquiler"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Panel Principal", tabName = "panel", icon = icon("dashboard")),
      menuItem("Explorador de Datos", tabName = "tabla", icon = icon("table")),
      menuItem("Analítica Avanzada", tabName = "analitica", icon = icon("chart-line")),
      menuItem("Calculadora Inversión", tabName = "calculadora", icon = icon("calculator")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    ),
    hr(),
    filtrosUI("filtros_sidebar")
  ),
  
  dashboardBody(
    tabItems(
      # 1. Panel Principal
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
      
      # 2. Explorador de Datos (DT)
      tabItem(tabName = "tabla",
        tablaUI("tabla_principal")
      ),
      
      # 3. Analítica Avanzada + Exportación
      tabItem(tabName = "analitica",
        graficosUI("grafico_principal"),
        fluidRow(
          exportarUI("exportar_datos")
        )
      ),
      
      # 4. Calculadora Inmobiliaria
      tabItem(tabName = "calculadora",
        calculadoraUI("calc_principal")
      ),
      
      # 5. Información
      tabItem(tabName = "informacion",
        h2("Sobre GeoAlquiler"),
        p("Plataforma interactiva de inteligencia inmobiliaria desarrollada en R Shiny.")
      )
    )
  )
)

# 2. SERVIDOR (Server)
server <- function(input, output, session) {
  
  # 1. Filtros del menú lateral
  datos_filtrados_sidebar <- filtrosServer("filtros_sidebar", datos_totales)
  
  # 2. El mapa recibe los datos del sidebar y DEVUELVE solo lo que se ve en la pantalla del mapa
  datos_visibles <- mapaServer("mapa_principal", datos_filtrados_sidebar)
  
  # 3. KPIs del Panel Principal conectados a lo visible en pantalla
  output$kpi_precio_medio <- renderValueBox({
    df <- datos_visibles()
    precio_med <- ifelse(nrow(df) > 0, round(mean(df$precio)), 0)
    valueBox(paste0(precio_med, " €"), "Precio Medio (Visible)", icon = icon("eur"), color = "purple")
  })
  
  output$kpi_superficie_media <- renderValueBox({
    df <- datos_visibles()
    sup_med <- ifelse(nrow(df) > 0, round(mean(df$superficie)), 0)
    valueBox(paste0(sup_med, " m²"), "Superficie Media (Visible)", icon = icon("home"), color = "green")
  })
  
  output$kpi_precio_m2 <- renderValueBox({
    df <- datos_visibles()
    precio_m2 <- ifelse(nrow(df) > 0, round(mean(df$precio / df$superficie), 1), 0)
    valueBox(paste0(precio_m2, " €/m²"), "Precio/m² Medio (Visible)", icon = icon("calculator"), color = "orange")
  })
  
  output$kpi_total_inmuebles <- renderValueBox({
    df <- datos_visibles()
    valueBox(nrow(df), "Inmuebles Visibles", icon = icon("building"), color = "blue")
  })
  
  # 4. Conectamos el resto de los módulos a los datos reactivos visibles
  tablaServer("tabla_principal", datos_visibles)
  graficosServer("grafico_principal", datos_visibles)
  calculadoraServer("calc_principal", datos_visibles)
  exportarServer("exportar_datos", datos_visibles)
}

shinyApp(ui = ui, server = server)