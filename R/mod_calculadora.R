# Módulo de Calculadora Inmobiliaria, Amortización Hipotecaria y Cash Flow

calculadoraUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("calculator"), " Parámetros de Inversión y Financiación"),
        width = 4, status = "primary", solidHeader = TRUE,
        
        numericInput(ns("precio_compra"), "Precio de Compra (€):", value = 180000, min = 10000, step = 5000),
        numericInput(ns("alquiler_mensual"), "Alquiler Estimado Mensual (€):", value = 850, min = 100, step = 50),
        numericInput(ns("gastos_mantenimiento"), "Gastos Anuales (Comunidad, IBI, Seguro) (€):", value = 1200, min = 0, step = 100),
        
        hr(),
        h4(icon("university"), " Condiciones Hipotecarias"),
        sliderInput(ns("porcentaje_entrada"), "% Entrada / Capital Propio:", min = 0, max = 50, value = 20, step = 5, post = "%"),
        numericInput(ns("interes_hipoteca"), "Tipo de Interés Anual (TIN):", value = 3.2, min = 0.1, max = 15, step = 0.1),
        selectInput(ns("plazo_anos"), "Plazo de la Hipoteca:", choices = c("15 años" = 15, "20 años" = 20, "25 años" = 25, "30 años" = 30), selected = 25),
        
        hr(),
        h4(icon("chart-line"), " Expectativas de Mercado"),
        sliderInput(ns("incremento_alquiler"), "Subida Anual Alquiler / Inflación:", min = 0, max = 5, value = 2, step = 0.5, post = "%"),
        sliderInput(ns("apreciacion_inmueble"), "Revalorización Anual Inmueble:", min = 0, max = 5, value = 1.5, step = 0.5, post = "%")
      ),
      
      box(
        title = tagList(icon("chart-pie"), " Métricas Clave y Retorno"),
        width = 8, status = "success", solidHeader = TRUE,
        
        fluidRow(
          valueBoxOutput(ns("kpi_cuota_mensual"), width = 4),
          valueBoxOutput(ns("kpi_roi_bruto"), width = 4),
          valueBoxOutput(ns("kpi_cashflow_mensual"), width = 4)
        ),
        
        tabBox(
          width = 12,
          title = "Análisis Avanzado",
          
          tabPanel("Proyección de Flujo de Caja", 
                   plotlyOutput(ns("grafico_proyeccion"), height = "380px")
          ),
          tabPanel("Cuadro de Amortización (Resumen Anual)", 
                   DTOutput(ns("tabla_amortizacion"))
          )
        )
      )
    )
  )
}

calculadoraServer <- function(id, datos = NULL) {
  moduleServer(id, function(input, output, session) {
    
    # 1. Simulación de la inversión (cálculo en simular_inversion(),
    # R/fct_calculos.R; aquí solo se leen los inputs y se pasan a tanto por uno)
    simulacion <- reactive({
      simular_inversion(
        precio = req(input$precio_compra),
        alquiler_mensual = req(input$alquiler_mensual),
        gastos_anuales = req(input$gastos_mantenimiento),
        pct_entrada = req(input$porcentaje_entrada) / 100,
        tin = req(input$interes_hipoteca) / 100,
        anos = as.numeric(req(input$plazo_anos)),
        inc_alquiler = req(input$incremento_alquiler) / 100,
        aprec_inmueble = req(input$apreciacion_inmueble) / 100
      )
    })

    # 2. Render KPIs
    output$kpi_cuota_mensual <- renderValueBox({
      sim <- simulacion()
      valueBox(
        paste0(round(sim$cuota_mensual, 0), " €/mes"),
        "Cuota Hipotecaria",
        icon = icon("university"),
        color = "blue"
      )
    })
    
    output$kpi_roi_bruto <- renderValueBox({
      yield <- rentabilidad_bruta(req(input$precio_compra), req(input$alquiler_mensual))
      
      valueBox(
        paste0(yield, " %"),
        "Rentabilidad Bruta Inicial",
        icon = icon("percentage"),
        color = "purple"
      )
    })
    
    output$kpi_cashflow_mensual <- renderValueBox({
      sim <- simulacion()
      cf_mensual <- cash_flow_mensual(req(input$alquiler_mensual), req(input$gastos_mantenimiento), sim$cuota_mensual)
      
      col_color <- if (cf_mensual >= 0) "green" else "red"
      
      valueBox(
        paste0(round(cf_mensual, 0), " €/mes"),
        "Cash Flow Neto Año 1",
        icon = icon("coins"),
        color = col_color
      )
    })
    
    # 3. Gráfico de Proyección con Plotly
    output$grafico_proyeccion <- renderPlotly({
      sim <- simulacion()
      df <- sim$proyeccion
      
      plot_ly(df, x = ~Ano) %>%
        add_trace(y = ~Cash_Flow_Acumulado, name = "Flujo Caja Acumulado (€)", type = 'scatter', mode = 'lines+markers',
                   line = list(color = '#10b981', width = 3)) %>%
        add_trace(y = ~Saldo_Pendiente, name = "Deuda Hipoteca Pendiente (€)", type = 'scatter', mode = 'lines',
                   line = list(color = '#ef4444', dash = 'dash')) %>%
        add_trace(y = ~Valor_Inmueble, name = "Valor Estimado Inmueble (€)", type = 'scatter', mode = 'lines',
                   line = list(color = '#3b82f6', width = 2)) %>%
        layout(
          title = "Evolución Financiera del Inmueble en el Tiempo",
          xaxis = list(title = "Año"),
          yaxis = list(title = "Euros (€)"),
          hovermode = "x unified",
          legend = list(orientation = "h", x = 0, y = -0.2)
        )
    })
    
    # 4. Tabla DT de Amortización
    output$tabla_amortizacion <- renderDT({
      sim <- simulacion()
      df <- sim$proyeccion[-1, ] # Omitir Año 0
      
      datatable(
        df[, c("Ano", "Valor_Inmueble", "Saldo_Pendiente", "Ingreso_Alquiler_Anual", "Pago_Hipoteca_Anual", "Cash_Flow_Anual", "Cash_Flow_Acumulado")],
        colnames = c("Año", "Valor Inmueble", "Deuda Pendiente", "Ingresos Alquiler", "Pago Hipoteca", "Cash Flow Neto", "CF Acumulado"),
        options = list(pageLength = 10, dom = 'tip', scrollX = TRUE),
        rownames = FALSE
      ) %>%
        formatCurrency(2:7, currency = "€", interval = 3, mark = ".", dec.mark = ",", digits = 0)
    })
    
  })
}