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
    
    # 1. Cálculos Base Hipotecarios
    simulacion <- reactive({
      precio <- req(input$precio_compra)
      alquiler <- req(input$alquiler_mensual)
      gastos_anuales <- req(input$gastos_mantenimiento)
      pct_entrada <- req(input$porcentaje_entrada) / 100
      tin <- req(input$interes_hipoteca) / 100
      anos <- as.numeric(req(input$plazo_anos))
      inc_alquiler <- req(input$incremento_alquiler) / 100
      aprec_inmueble <- req(input$apreciacion_inmueble) / 100
      
      entrada <- precio * pct_entrada
      monto_prestamo <- precio - entrada
      
      # Cuota Hipotecaria Francesa (mensual)
      tasa_mensual <- tin / 12
      num_cuotas <- anos * 12
      
      cuota_mensual <- if (tin > 0) {
        monto_prestamo * (tasa_mensual * (1 + tasa_mensual)^num_cuotas) / (((1 + tasa_mensual)^num_cuotas) - 1)
      } else {
        monto_prestamo / num_cuotas
      }
      
      # Proyección año a año
      df_proyeccion <- data.frame(
        Ano = 0:anos,
        Valor_Inmueble = NA_real_,
        Saldo_Pendiente = NA_real_,
        Ingreso_Alquiler_Anual = NA_real_,
        Gastos_Operativos_Anuales = NA_real_,
        Pago_Hipoteca_Anual = NA_real_,
        Cash_Flow_Anual = NA_real_,
        Cash_Flow_Acumulado = NA_real_
      )
      
      # Año 0
      df_proyeccion$Valor_Inmueble[1] <- precio
      df_proyeccion$Saldo_Pendiente[1] <- monto_prestamo
      df_proyeccion$Ingreso_Alquiler_Anual[1] <- 0
      df_proyeccion$Gastos_Operativos_Anuales[1] <- 0
      df_proyeccion$Pago_Hipoteca_Anual[1] <- 0
      df_proyeccion$Cash_Flow_Anual[1] <- -entrada
      df_proyeccion$Cash_Flow_Acumulado[1] <- -entrada
      
      saldo_actual <- monto_prestamo
      alquiler_actual <- alquiler * 12
      gastos_actuales <- gastos_anuales
      cf_acumulado <- -entrada
      
      for (a in 1:anos) {
        # Amortización del año
        interes_ano <- 0
        capital_ano <- 0
        for (m in 1:12) {
          int_m <- saldo_actual * tasa_mensual
          cap_m <- cuota_mensual - int_m
          interes_ano <- interes_ano + int_m
          capital_ano <- capital_ano + cap_m
          saldo_actual <- max(0, saldo_actual - cap_m)
        }
        
        val_inmueble <- precio * ((1 + aprec_inmueble)^a)
        ing_alq <- alquiler_actual * ((1 + inc_alquiler)^(a - 1))
        gast_op <- gastos_actuales * ((1 + inc_alquiler)^(a - 1)) # Asumimos inflación en gastos
        pago_hip <- cuota_mensual * 12
        
        cf_anual <- ing_alq - gast_op - pago_hip
        cf_acumulado <- cf_acumulado + cf_anual
        
        df_proyeccion$Valor_Inmueble[a + 1] <- round(val_inmueble, 0)
        df_proyeccion$Saldo_Pendiente[a + 1] <- round(saldo_actual, 0)
        df_proyeccion$Ingreso_Alquiler_Anual[a + 1] <- round(ing_alq, 0)
        df_proyeccion$Gastos_Operativos_Anuales[a + 1] <- round(gast_op, 0)
        df_proyeccion$Pago_Hipoteca_Anual[a + 1] <- round(pago_hip, 0)
        df_proyeccion$Cash_Flow_Anual[a + 1] <- round(cf_anual, 0)
        df_proyeccion$Cash_Flow_Acumulado[a + 1] <- round(cf_acumulado, 0)
      }
      
      list(
        cuota_mensual = cuota_mensual,
        entrada = entrada,
        monto_prestamo = monto_prestamo,
        proyeccion = df_proyeccion
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
      precio <- req(input$precio_compra)
      alquiler <- req(input$alquiler_mensual)
      yield <- if (precio > 0) round(((alquiler * 12) / precio) * 100, 2) else 0
      
      valueBox(
        paste0(yield, " %"),
        "Rentabilidad Bruta Inicial",
        icon = icon("percentage"),
        color = "purple"
      )
    })
    
    output$kpi_cashflow_mensual <- renderValueBox({
      sim <- simulacion()
      alquiler <- req(input$alquiler_mensual)
      gastos_m <- req(input$gastos_mantenimiento) / 12
      cf_mensual <- alquiler - gastos_m - sim$cuota_mensual
      
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