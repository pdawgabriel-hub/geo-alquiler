# Módulo para simular estimaciones financieras de inversión inmobiliaria

# 1. UI DEL MÓDULO
calculadoraUI <- function(id) {
  ns <- NS(id)
  
  fluidRow(
    box(
      title = "Parámetros de Inversión", 
      width = 5, 
      status = "warning", 
      solidHeader = TRUE,
      numericInput(ns("precio_compra"), "Precio estimado de compra (€):", value = 180000, step = 5000),
      numericInput(ns("gastos_compra"), "Gastos e impuestos de compra (%):", value = 10, min = 0, max = 20),
      numericInput(ns("reforma"), "Presupuesto de reforma / adecuación (€):", value = 15000, step = 1000),
      numericInput(ns("gastos_anuales"), "Gastos anuales estimados (IBI, comunidad, seguro) (€):", value = 1200, step = 100)
    ),
    box(
      title = "Métricas y Retorno Estimado", 
      width = 7, 
      status = "success", 
      solidHeader = TRUE,
      valueBoxOutput(ns("kpi_inversion_total"), width = 6),
      valueBoxOutput(ns("kpi_alquiler_estimado"), width = 6),
      valueBoxOutput(ns("kpi_rentabilidad_bruta"), width = 6),
      valueBoxOutput(ns("kpi_rentabilidad_neta"), width = 6)
    )
  )
}

# 2. SERVER DEL MÓDULO
calculadoraServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    # 1. Inversión total = Compra + Gastos% + Reforma
    inversion_total <- reactive({
      req(input$precio_compra)
      compra <- input$precio_compra
      gastos <- compra * (input$gastos_compra / 100)
      reforma <- input$reforma
      return(compra + gastos + reforma)
    })
    
    # 2. Alquiler mensual estimado (Usa la media de los datos filtrados en pantalla)
    alquiler_estimado <- reactive({
      df <- datos_reactivos()
      if (nrow(df) == 0) return(0)
      round(mean(df$precio))
    })
    
    output$kpi_inversion_total <- renderValueBox({
      valueBox(
        paste0(format(inversion_total(), big.mark = "."), " €"),
        "Inversión Total Requerida", icon = icon("wallet"), color = "navy"
      )
    })
    
    output$kpi_alquiler_estimado <- renderValueBox({
      valueBox(
        paste0(alquiler_estimado(), " €/mes"),
        "Alquiler Estimado Zona", icon = icon("key"), color = "teal"
      )
    })
    
    output$kpi_rentabilidad_bruta <- renderValueBox({
      inv <- inversion_total()
      alq_anual <- alquiler_estimado() * 12
      rent_bruta <- ifelse(inv > 0, round((alq_anual / inv) * 100, 2), 0)
      
      valueBox(
        paste0(rent_bruta, " %"),
        "Rentabilidad Bruta Anual", icon = icon("chart-pie"), color = "green"
      )
    })
    
    output$kpi_rentabilidad_neta <- renderValueBox({
      inv <- inversion_total()
      alq_anual <- alquiler_estimado() * 12
      ingreso_neto <- alq_anual - input$gastos_anuales
      rent_neta <- ifelse(inv > 0, round((ingreso_neto / inv) * 100, 2), 0)
      
      valueBox(
        paste0(rent_neta, " %"),
        "Rentabilidad Neta Estimada", icon = icon("coins"), color = "olive"
      )
    })
    
  })
}