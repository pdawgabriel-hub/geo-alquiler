# R/mod_filtros.R
# Módulo de filtros con espacios y márgenes cuidados

# 1. UI DEL MÓDULO
filtrosUI <- function(id) {
  ns <- NS(id)
  
  # Contenedor principal con margen adecuado
  div(
    style = "padding: 10px 15px; box-sizing: border-box; overflow-x: hidden;",
    
    selectInput(
      ns("filtro_ciudad"), "Ciudad:", 
      choices = c("Todas", "Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao"),
      selected = "Todas"
    ),
    selectInput(
      ns("filtro_tipo"), "Tipo de Propiedad:", 
      choices = c("Todos", "Piso", "Casa", "Ático", "Estudio"),
      selected = "Todos"
    ),
    sliderInput(
      ns("filtro_precio"), "Rango de Precio (€):", 
      min = 500, max = 2800, value = c(500, 2800), step = 50,
      width = "100%"
    ),
    sliderInput(
      ns("filtro_superficie"), "Superficie (m²):", 
      min = 40, max = 160, value = c(40, 160), step = 5,
      width = "100%"
    ),
    
    # Botón con márgenes alrededor para separarlo del fondo y de los bordes
    div(
      style = "margin-top: 20px; margin-bottom: 25px; padding: 0 5px;",
      actionButton(
        ns("reset_filtros"), "Restablecer Filtros", 
        icon = icon("rotate-right"), 
        class = "btn-warning btn-sm",
        style = "width: 100%; display: block; border-radius: 4px;"
      )
    )
  )
}

# 2. SERVER DEL MÓDULO
filtrosServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {
    
    # Escuchamos el clic en el botón de restablecer
    observeEvent(input$reset_filtros, {
      updateSelectInput(session, "filtro_ciudad", selected = "Todas")
      updateSelectInput(session, "filtro_tipo", selected = "Todos")
      updateSliderInput(session, "filtro_precio", value = c(500, 2800))
      updateSliderInput(session, "filtro_superficie", value = c(40, 160))
    })
    
    # Retornamos la tabla reactiva filtrada
    datos_filtrados <- reactive({
      df <- datos_totales
      
      if (input$filtro_ciudad != "Todas") {
        df <- df[df$ciudad == input$filtro_ciudad, ]
      }
      if (input$filtro_tipo != "Todos") {
        df <- df[df$tipo == input$filtro_tipo, ]
      }
      df <- df[df$precio >= input$filtro_precio[1] & df$precio <= input$filtro_precio[2], ]
      df <- df[df$superficie >= input$filtro_superficie[1] & df$superficie <= input$filtro_superficie[2], ]
      
      return(df)
    })
    
    return(datos_filtrados)
  })
}