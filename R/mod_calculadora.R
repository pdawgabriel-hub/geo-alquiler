# Módulo de Calculadora de Inversión y Análisis de Sensibilidad "What-If" para GeoAlquiler

# 1. UI DEL MÓDULO
calculadoraUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("sliders-h"), " Parámetros de la Inversión"),
        width = 4, status = "primary", solidHeader = TRUE,
        numericInput(ns("precio_compra"), "Precio de Compra (€):", value = 150000, step = 5000),
        numericInput(ns("gastos_compra"), "Gastos e Impuestos Compra (%):", value = 10, min = 0, max = 20),
        numericInput(ns("reforma"), "Reforma / Puesta a punto (€):", value = 10000, step = 1000),
        numericInput(ns("alquiler_mensual"), "Alquiler Estimado (€/mes):", value = 850, step = 50),
        hr(),
        h5(strong("Estructura de Gastos Anuales")),
        numericInput(ns("ibi_comunidad"), "IBI + Comunidad anual (€):", value = 1200, step = 100),
        numericInput(ns("seguros"), "Seguros anuales (€):", value = 350, step = 50)
      ),
      
      box(
        title = tagList(icon("chart-line"), " Simulación de Escenarios \"What-If\""),
        width = 8, status = "warning", solidHeader = TRUE,
        p("Ajusta los factores de riesgo para evaluar la resistencia de la inversión:"),
        fluidRow(
          column(6,
            sliderInput(
              ns("meses_ocupado"),
              "Meses alquilado al año (Ocupación):",
              min = 6, max = 12, value = 11, step = 0.5
            )
          ),
          column(6,
            sliderInput(
              ns("pct_mantenimiento"),
              "Gasto imprevisto / Mantenimiento (% alquiler):",
              min = 0, max = 25, value = 5, step = 1, post = "%"
            )
          )
        ),
        hr(),
        fluidRow(
          valueBoxOutput(ns("vbox_inversion_total"), width = 4),
          valueBoxOutput(ns("vbox_rent_bruta"), width = 4),
          valueBoxOutput(ns("vbox_rent_neta"), width = 4)
        )
      )
    ),
    
    fluidRow(
      box(
        title = tagList(icon("balance-scale"), " Comparativa de Escenarios de Ocupación vs Rentabilidad"),
        width = 12, status = "info", solidHeader = TRUE,
        DTOutput(ns("tabla_escenarios"))
      )
    )
  )
}

# 2. SERVER DEL MÓDULO (Acepta opcionalmente el argumento 'datos' de app.R sin dar error)
calculadoraServer <- function(id, datos = NULL) {
  moduleServer(id, function(input, output, session) {
    
    # Cálculos dinámicos de la inversión base y escenario actual
    metricas <- reactive({
      req(input$precio_compra, input$alquiler_mensual)
      
      inversion_total <- input$precio_compra * (1 + input$gastos_compra / 100) + input$reforma
      
      # Ingresos brutos según meses de ocupación
      ingresos_brutos_anuales <- input$alquiler_mensual * input$meses_ocupado
      
      # Gastos operativos
      mantenimiento <- ingresos_brutos_anuales * (input$pct_mantenimiento / 100)
      gastos_fijos <- input$ibi_comunidad + input$seguros
      gastos_totales_anuales <- gastos_fijos + mantenimiento
      
      ingresos_netos_anuales <- ingresos_brutos_anuales - gastos_totales_anuales
      
      rent_bruta <- ( (input$alquiler_mensual * 12) / inversion_total ) * 100
      rent_neta <- ( ingresos_netos_anuales / inversion_total ) * 100
      
      list(
        inversion_total = round(inversion_total, 2),
        ingresos_brutos = round(ingresos_brutos_anuales, 2),
        ingresos_netos = round(ingresos_netos_anuales, 2),
        rent_bruta = round(rent_bruta, 2),
        rent_neta = round(rent_neta, 2)
      )
    })
    
    # Renderizado de ValueBoxes
    output$vbox_inversion_total <- renderValueBox({
      m <- metricas()
      valueBox(
        paste0(format(m$inversion_total, big.mark = "."), " €"),
        "Inversión Total Inicial",
        icon = icon("coins"),
        color = "blue"
      )
    })
    
    output$vbox_rent_bruta <- renderValueBox({
      m <- metricas()
      valueBox(
        paste0(m$rent_bruta, " %"),
        "Rentabilidad Bruta (100% Ocupación)",
        icon = icon("percentage"),
        color = "purple"
      )
    })
    
    output$vbox_rent_neta <- renderValueBox({
      m <- metricas()
      col_color <- if (m$rent_neta >= 5) "green" else if (m$rent_neta >= 3) "yellow" else "red"
      
      valueBox(
        paste0(m$rent_neta, " %"),
        "Rentabilidad Neta (Escenario Actual)",
        icon = icon("chart-line"),
        color = col_color
      )
    })
    
    # Tabla de análisis de sensibilidad (Escenarios de 8 a 12 meses alquilado)
    output$tabla_escenarios <- renderDataTable({
      m <- metricas()
      req(input$precio_compra, input$alquiler_mensual)
      
      inv_tot <- m$inversion_total
      gastos_fijos <- input$ibi_comunidad + input$seguros
      
      # Generar matriz de sensibilidad con diferentes meses de ocupación
      meses_vec <- c(12, 11, 10, 9, 8)
      
      escenarios <- data.frame(
        Ocupacion = paste0(meses_vec, " meses (", round((meses_vec/12)*100), "%)"),
        IngresosBrutos = meses_vec * input$alquiler_mensual,
        GastosOperativos = round((meses_vec * input$alquiler_mensual * (input$pct_mantenimiento / 100)) + gastos_fijos, 2)
      )
      
      escenarios$CashFlowAnual <- escenarios$IngresosBrutos - escenarios$GastosOperativos
      escenarios$RentabilidadNeta <- paste0(round((escenarios$CashFlowAnual / inv_tot) * 100, 2), " %")
      escenarios$CashFlowMensual <- paste0(round(escenarios$CashFlowAnual / 12, 2), " €")
      escenarios$IngresosBrutos <- paste0(escenarios$IngresosBrutos, " €")
      escenarios$CashFlowAnual <- paste0(escenarios$CashFlowAnual, " €")
      
      datatable(
        escenarios,
        colnames = c("Escenario Ocupación", "Ingresos Brutos/Año", "Gastos Totales/Año", "Cash Flow Anual", "Rentabilidad Neta", "Cash Flow Medio/Mes"),
        options = list(dom = 't', ordering = FALSE),
        rownames = FALSE
      )
    })
  })
}