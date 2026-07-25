library(shiny)
library(shinydashboard)
library(leaflet)
library(leaflet.extras)
library(plotly)
library(DT)

# 0. CARGA DE MÓDULOS Y DATOS
source("R/mod_filtros.R")
source("R/mod_mapa.R")
source("R/mod_graficos.R")
source("R/mod_tabla.R")
source("R/mod_calculadora.R")
source("R/mod_exportar.R")
source("R/mod_reporte.R")
source("R/mod_comparador.R")
source("R/mod_oportunidades.R")
source("R/mod_estadistica.R")
source("R/mod_recomendador.R")
source("R/mod_prediccion.R")
source("R/mod_barrios.R") # <- Nuevo Módulo Zonal/Barrios

datos_totales <- readRDS("data/processed/alquileres.rds")

# 1. INTERFAZ DE USUARIO (UI)
ui <- dashboardPage(
  skin = "blue",
  title = "GeoAlquiler",
  
  dashboardHeader(title = "GeoAlquiler"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Panel Principal", tabName = "panel", icon = icon("dashboard")),
      menuItem("Análisis por Barrios", tabName = "barrios", icon = icon("city")), # <- Opción del menú
      menuItem("Predicción ML", tabName = "prediccion", icon = icon("chart-line")),
      menuItem("Comparador A/B", tabName = "comparador", icon = icon("balance-scale")),
      menuItem("Oportunidades", tabName = "oportunidades", icon = icon("award")),
      menuItem("Recomendador KNN", tabName = "recomendador", icon = icon("magic")),
      menuItem("Explorador de Datos", tabName = "tabla", icon = icon("table")),
      menuItem("Analítica Avanzada", tabName = "analitica", icon = icon("chart-line")),
      menuItem("Estadística Avanzada", tabName = "estadistica", icon = icon("chart-pie")),
      menuItem("Calculadora Inversión", tabName = "calculadora", icon = icon("calculator")),
      menuItem("Informe Ejecutivo", tabName = "reporte", icon = icon("file-alt")),
      menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
    )
  ),
  
  dashboardBody(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "css/custom.css")
    ),
    
    tabItems(
      # 1. Panel Principal
      tabItem(tabName = "panel",
        fluidRow(
          filtrosUI("filtros_sidebar")
        ),
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
      
      # 2. Análisis por Barrios (NUEVA PESTAÑA)
      tabItem(tabName = "barrios",
        barriosUI("barrios_principal")
      ),
      
      # 3. Predicción ML
      tabItem(tabName = "prediccion",
        prediccionUI("prediccion_principal")
      ),
      
      # 4. Comparador A/B
      tabItem(tabName = "comparador",
        comparadorUI("comp_principal")
      ),
      
      # 5. Oportunidades Inmobiliarias
      tabItem(tabName = "oportunidades",
        oportunidadesUI("oportunidades_principal")
      ),
      
      # 6. Recomendador KNN
      tabItem(tabName = "recomendador",
        recomendadorUI("recomendador_principal")
      ),
      
      # 7. Explorador de Datos (DT)
      tabItem(tabName = "tabla",
        tablaUI("tabla_principal")
      ),
      
      # 8. Analítica Avanzada + Exportación CSV
      tabItem(tabName = "analitica",
        graficosUI("grafico_principal"),
        fluidRow(
          exportarUI("exportar_datos")
        )
      ),
      
      # 9. Estadística Avanzada
      tabItem(tabName = "estadistica",
        estadisticaUI("estadistica_principal")
      ),
      
      # 10. Calculadora Inmobiliaria
      tabItem(tabName = "calculadora",
        calculadoraUI("calc_principal")
      ),

      # 11. Informe Ejecutivo
      tabItem(tabName = "reporte",
        reporteUI("reporte_principal")
      ),
      
      # 12. Información
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
  
  output$kpi_precio_medio <- renderValueBox({
    df <- datos_visibles()
    precio_med <- if (!is.null(df) && nrow(df) > 0) round(mean(df$precio, na.rm = TRUE)) else 0
    valueBox(paste0(precio_med, " €"), "Precio Medio", icon = icon("eur"), color = "purple")
  })
  
  output$kpi_superficie_media <- renderValueBox({
    df <- datos_visibles()
    sup_med <- if (!is.null(df) && nrow(df) > 0) round(mean(df$superficie, na.rm = TRUE)) else 0
    valueBox(paste0(sup_med, " m²"), "Superficie Media", icon = icon("home"), color = "green")
  })
  
  output$kpi_precio_m2 <- renderValueBox({
    df <- datos_visibles()
    precio_m2 <- if (!is.null(df) && nrow(df) > 0) round(mean(df$precio / df$superficie, na.rm = TRUE), 1) else 0
    valueBox(paste0(precio_m2, " €/m²"), "Precio/m² Medio", icon = icon("calculator"), color = "orange")
  })
  
  output$kpi_total_inmuebles <- renderValueBox({
    df <- datos_visibles()
    tot <- if (!is.null(df)) nrow(df) else 0
    valueBox(tot, "Inmuebles Visibles", icon = icon("building"), color = "blue")
  })
  
  # Servidores Modulares
  tablaServer("tabla_principal", datos_visibles)
  graficosServer("grafico_principal", datos_visibles)
  calculadoraServer("calc_principal", datos_visibles)
  exportarServer("exportar_datos", datos_visibles)
  reporteServer("reporte_principal", datos_visibles)
  comparadorServer("comp_principal", datos_totales)
  oportunidadesServer("oportunidades_principal", datos_visibles)
  estadisticaServer("estadistica_principal", datos_visibles)
  recomendadorServer("recomendador_principal", datos_filtrados_sidebar)
  prediccionServer("prediccion_principal", datos_totales)
  barriosServer("barrios_principal", datos_totales) # <- Instancia Servidor Barrios
}

shinyApp(ui = ui, server = server)