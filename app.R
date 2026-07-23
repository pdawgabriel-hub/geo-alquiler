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
source("R/mod_comparador.R")
source("R/mod_oportunidades.R")

datos_totales <- readRDS("data/processed/alquileres.rds")

# 1. INTERFAZ DE USUARIO (UI)
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "GeoAlquiler"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Panel Principal", tabName = "panel", icon = icon("dashboard")),
      menuItem("Comparador A/B", tabName = "comparador", icon = icon("balance-scale")),
      menuItem("Oportunidades", tabName = "oportunidades", icon = icon("award")), # 👈 Pestaña Oportunidades
      menuItem("Explorador de Datos", tabName = "tabla", icon = icon("table")),
      menuItem("Analítica Avanzada", tabName = "analitica", icon = icon("chart-line")),
      menuItem("Calculadora Inversión", tabName = "calculadora", icon = icon("calculator")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    ),
    hr(),
    filtrosUI("filtros_sidebar")
  ),
  
  dashboardBody(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "css/custom.css")
    ),
    
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
      
      # 2. Comparador A/B
      tabItem(tabName = "comparador",
        comparadorUI("comp_principal")
      ),
      
      # 3. Oportunidades Inmobiliarias (NUEVA PESTAÑA)
      tabItem(tabName = "oportunidades",
        oportunidadesUI("oportunidades_principal")
      ),
      
      # 4. Explorador de Datos (DT)
      tabItem(tabName = "tabla",
        tablaUI("tabla_principal")
      ),
      
      # 5. Analítica Avanzada + Exportación
      tabItem(tabName = "analitica",
        graficosUI("grafico_principal"),
        fluidRow(
          exportarUI("exportar_datos")
        )
      ),
      
      # 6. Calculadora Inmobiliaria
      tabItem(tabName = "calculadora",
        calculadoraUI("calc_principal")
      ),
      
      # 7. Información
      tabItem(tabName = "informacion",
        fluidRow(
          box(
            title = "Sobre el Proyecto GeoAlquiler", 
            width = 12, status = "primary", solidHeader = TRUE,
            h3("Inteligencia Inmobiliaria y Análisis Espacial"),
            p("GeoAlquiler es una solución analítica integral desarrollada en R y Shiny.")
          )
        )
      )
    )
  )
)

# 2. SERVIDOR (Server)
server <- function(input, output, session) {
  
  datos_filtrados_sidebar <- filtrosServer("filtros_sidebar", datos_totales)
  datos_visibles <- mapaServer("mapa_principal", datos_filtrados_sidebar)
  
  # KPIs principales
  output$kpi_precio_medio <- renderValueBox({
    df <- datos_visibles()
    precio_med <- ifelse(nrow(df) > 0, round(mean(df$precio)), 0)
    valueBox(paste0(precio_med, " €"), "Precio Medio", icon = icon("eur"), color = "purple")
  })
  
  output$kpi_superficie_media <- renderValueBox({
    df <- datos_visibles()
    sup_med <- ifelse(nrow(df) > 0, round(mean(df$superficie)), 0)
    valueBox(paste0(sup_med, " m²"), "Superficie Media", icon = icon("home"), color = "green")
  })
  
  output$kpi_precio_m2 <- renderValueBox({
    df <- datos_visibles()
    precio_m2 <- ifelse(nrow(df) > 0, round(mean(df$precio / df$superficie), 1), 0)
    valueBox(paste0(precio_m2, " €/m²"), "Precio/m² Medio", icon = icon("calculator"), color = "orange")
  })
  
  output$kpi_total_inmuebles <- renderValueBox({
    df <- datos_visibles()
    valueBox(nrow(df), "Inmuebles Visibles", icon = icon("building"), color = "blue")
  })
  
  # Servidores Modulares
  tablaServer("tabla_principal", datos_visibles)
  graficosServer("grafico_principal", datos_visibles)
  calculadoraServer("calc_principal", datos_visibles)
  exportarServer("exportar_datos", datos_visibles)
  comparadorServer("comp_principal", datos_totales)
  oportunidadesServer("oportunidades_principal", datos_visibles)
}

shinyApp(ui = ui, server = server)