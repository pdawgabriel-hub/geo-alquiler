# Módulo dedicado al panel lateral de filtros y control de la reactividad

# 1. UI DEL MÓDULO (Genera los inputs dentro del sidebar)
filtrosUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    # Filtro 1: Selector de Ciudad
    selectInput(
      ns("filtro_ciudad"), 
      "Ciudad:", 
      choices = c("Todas", "Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao"),
      selected = "Todas"
    ),
    
    # Filtro 2: Selector de Tipo de Propiedad
    selectInput(
      ns("filtro_tipo"), 
      "Tipo de Propiedad:", 
      choices = c("Todos", "Piso", "Casa", "Ático", "Estudio"),
      selected = "Todos"
    ),
    
    # Filtro 3: Slider Rango de Precio
    sliderInput(
      ns("filtro_precio"), 
      "Rango de Precio (€):", 
      min = 500, max = 2800, value = c(600, 2000), step = 50
    ),
    
    # Filtro 4: Slider Rango de Superficie
    sliderInput(
      ns("filtro_superficie"), 
      "Superficie (m²):", 
      min = 40, max = 160, value = c(45, 160), step = 5
    )
  )
}

# 2. SERVER DEL MÓDULO (Devuelve el dataframe filtrado reactivo)
filtrosServer <- function(id, datos_totales) {
  moduleServer(id, function(input, output, session) {
    
    # Retornamos directamente una expresión reactiva
    datos_filtrados <- reactive({
      df <- datos_totales
      
      # 1. Filtrar por Ciudad
      if (input$filtro_ciudad != "Todas") {
        df <- df[df$ciudad == input$filtro_ciudad, ]
      }
      
      # 2. Filtrar por Tipo
      if (input$filtro_tipo != "Todos") {
        df <- df[df$tipo == input$filtro_tipo, ]
      }
      
      # 3. Filtrar por Rango de Precio
      df <- df[df$precio >= input$filtro_precio[1] & df$precio <= input$filtro_precio[2], ]
      
      # 4. Filtrar por Rango de Superficie
      df <- df[df$superficie >= input$filtro_superficie[1] & df$superficie <= input$filtro_superficie[2], ]
      
      return(df)
    })
    
    return(datos_filtrados) # ¡El server del módulo devuelve el objeto reactivo!
  })
}