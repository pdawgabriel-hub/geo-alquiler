#' The application User-Interface
#' 
#' @param request Internal parameter for `{shiny}`. 
#' @import shiny
#' @import shinydashboard
#' @import leaflet
#' @import leaflet.extras
#' @import DT
#' @import plotly
#' @noRd
app_ui <- function(request) {
  tagList(
    # Inclusión de recursos estáticos CSS/JS desde inst/app/www
    golem_add_static_resources(),
    
    shinydashboard::dashboardPage(
      skin = "blue",
      title = "GeoAlquiler",
      
      shinydashboard::dashboardHeader(title = "GeoAlquiler"),
      
      shinydashboard::dashboardSidebar(
        shinydashboard::sidebarMenu(
          # 1. EXPLORACIÓN
          shinydashboard::menuItem("Panel Principal", tabName = "panel", icon = icon("dashboard")),
          shinydashboard::menuItem("Explorador y Datos", icon = icon("compass"),
            shinydashboard::menuSubItem("Explorador de Datos", tabName = "tabla", icon = icon("table")),
            shinydashboard::menuSubItem("Análisis por Barrios", tabName = "barrios", icon = icon("city")),
            shinydashboard::menuSubItem("Mis Favoritos", tabName = "favoritos", icon = icon("star"))
          ),
          
          # 2. ANALÍTICA Y MODELOS ML
          shinydashboard::menuItem("Analítica y Ciencia de Datos", icon = icon("brain"),
            shinydashboard::menuSubItem("Analítica Visual", tabName = "analitica", icon = icon("chart-bar")),
            shinydashboard::menuSubItem("Estadística Avanzada", tabName = "estadistica", icon = icon("chart-pie")),
            shinydashboard::menuSubItem("Predicción ML", tabName = "prediccion", icon = icon("chart-line")),
            shinydashboard::menuSubItem("Recomendador KNN", tabName = "recomendador", icon = icon("magic"))
          ),
          
          # 3. HERRAMIENTAS DE NEGOCIO E INVERSIÓN
          shinydashboard::menuItem("Herramientas de Inversión", icon = icon("briefcase"),
            shinydashboard::menuSubItem("Comparador A/B", tabName = "comparador", icon = icon("balance-scale")),
            shinydashboard::menuSubItem("Oportunidades", tabName = "oportunidades", icon = icon("award")),
            shinydashboard::menuSubItem("Calculadora Inversión", tabName = "calculadora", icon = icon("calculator")),
            shinydashboard::menuSubItem("Informe Ejecutivo", tabName = "reporte", icon = icon("file-alt"))
          ),
          
          # 4. INFORMACIÓN
          shinydashboard::menuItem("Información", tabName = "informacion", icon = icon("info-circle"))
        )
      ),
      
      shinydashboard::dashboardBody(
        shinydashboard::tabItems(
          # 1. Panel Principal
          shinydashboard::tabItem(tabName = "panel",
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
          
          # 2. Análisis por Barrios
          shinydashboard::tabItem(tabName = "barrios",
            barriosUI("barrios_principal")
          ),
          
          # 3. Predicción ML
          shinydashboard::tabItem(tabName = "prediccion",
            prediccionUI("prediccion_principal")
          ),
          
          # 4. Comparador A/B
          shinydashboard::tabItem(tabName = "comparador",
            comparadorUI("comp_principal")
          ),
          
          # 5. Oportunidades Inmobiliarias
          shinydashboard::tabItem(tabName = "oportunidades",
            oportunidadesUI("oportunidades_principal")
          ),
          
          # 6. Recomendador KNN
          shinydashboard::tabItem(tabName = "recomendador",
            recomendadorUI("recomendador_principal")
          ),
          
          # 7. Mis Favoritos (Watchlist)
          shinydashboard::tabItem(tabName = "favoritos",
            favoritosUI("fav_principal")
          ),
          
          # 8. Explorador de Datos (DT)
          shinydashboard::tabItem(tabName = "tabla",
            tablaUI("tabla_principal")
          ),
          
          # 9. Analítica Avanzada + Exportación CSV
          shinydashboard::tabItem(tabName = "analitica",
            graficosUI("grafico_principal"),
            fluidRow(
              exportarUI("exportar_datos")
            )
          ),
          
          # 10. Estadística Avanzada
          shinydashboard::tabItem(tabName = "estadistica",
            estadisticaUI("estadistica_principal")
          ),
          
          # 11. Calculadora Inmobiliaria
          shinydashboard::tabItem(tabName = "calculadora",
            calculadoraUI("calc_principal")
          ),

          # 12. Informe Ejecutivo HTML
          shinydashboard::tabItem(tabName = "reporte",
            reporteUI("reporte_principal")
          ),
          
          # 13. Información
          shinydashboard::tabItem(tabName = "informacion",
            fluidRow(
              shinydashboard::box(
                title = "Sobre el Proyecto GeoAlquiler", 
                width = 12, status = "primary", solidHeader = TRUE,
                h3("Inteligencia Inmobiliaria y Análisis Espacial"),
                p("GeoAlquiler es una solución analítica integral desarrollada en R y Shiny para la exploración geográfica y económica del mercado de alquileres.")
              )
            )
          )
        )
      )
    )
  )
}

#' Access files in the current package
#' @param ... character vectors, specifying subdirectory and file(s)
#' @noRd
app_sys <- function(...) {
  system.file(..., package = "GeoAlquiler")
}

#' Add external Resources to the Application
#' @noRd
golem_add_static_resources <- function() {
  path_www <- app_sys("app/www")
  if (path_www == "") {
    path_www <- "inst/app/www"
  }

  golem::add_resource_path(
    "www", path_www
  )

  tags$head(
    golem::favicon(),
    golem::bundle_resources(
      path = path_www,
      app_title = "GeoAlquiler"
    )
  )
}