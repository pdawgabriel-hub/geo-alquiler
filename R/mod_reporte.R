# Módulo de Generación de Informes Ejecutivos para GeoAlquiler

reporteUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = tagList(icon("file-pdf"), " Generar e Imprimir Informe Ejecutivo"),
        width = 12, status = "primary", solidHeader = TRUE,
        p("Genera un informe con los métricos clave del mercado actual y los inmuebles filtrados en GeoAlquiler."),
        fluidRow(
          column(4,
            textInput(ns("titulo_reporte"), "Título del Informe:", value = "Informe Ejecutivo de Mercado")
          ),
          column(4,
            textInput(ns("nombre_analista"), "Preparado por:", value = "Analista de Inversión")
          ),
          column(4,
            br(),
            downloadButton(ns("descargar_informe"), "Descargar Reporte HTML/PDF", class = "btn-success btn-block")
          )
        )
      )
    ),
    
    fluidRow(
      box(
        title = tagList(icon("eye"), " Vista Previa del Reporte"),
        width = 12, status = "info", solidHeader = TRUE,
        htmlOutput(ns("vista_previa"))
      )
    )
  )
}

reporteServer <- function(id, datos = NULL) {
  moduleServer(id, function(input, output, session) {
    
    # Renderizado del HTML del Informe
    generar_html_reporte <- reactive({
      df <- if (is.reactive(datos)) datos() else datos
      
      num_inmuebles <- if (!is.null(df)) nrow(df) else 0
      precio_medio <- if (!is.null(df) && "precio" %in% names(df)) round(mean(df$precio, na.rm = TRUE), 0) else 0
      
      pm2_medio <- if (!is.null(df) && all(c("precio", "superficie") %in% names(df))) {
        round(mean(df$precio / df$superficie, na.rm = TRUE), 1)
      } else { 0 }
      
      col_tit <- if (!is.null(df) && "titulo" %in% names(df)) "titulo" else names(df)[1]
      col_pre <- if (!is.null(df) && "precio" %in% names(df)) "precio" else names(df)[2]
      col_sup <- if (!is.null(df) && "superficie" %in% names(df)) "superficie" else names(df)[3]
      col_ciu <- if (!is.null(df) && "ciudad" %in% names(df)) "ciudad" else col_tit
      
      # Generar filas de la tabla de muestra
      filas_html <- ""
      if (!is.null(df) && nrow(df) > 0) {
        top_df <- head(df, 8)
        for (i in 1:nrow(top_df)) {
          filas_html <- paste0(filas_html, sprintf(
            "<tr>
              <td>%s</td>
              <td>%s</td>
              <td>%s €</td>
              <td>%s m²</td>
              <td>%.1f €/m²</td>
            </tr>",
            top_df[[col_ciu]][i],
            top_df[[col_tit]][i],
            top_df[[col_pre]][i],
            top_df[[col_sup]][i],
            top_df[[col_pre]][i] / top_df[[col_sup]][i]
          ))
        }
      }
      
      # Plantilla HTML con estilos inline
      paste0('
      <div style="font-family: Arial, sans-serif; background: #f8fafc; padding: 25px; border-radius: 8px;">
        <div style="background: #1e3a8a; color: white; padding: 20px; border-radius: 6px; margin-bottom: 20px;">
          <h2 style="margin: 0;">GeoAlquiler — ', input$titulo_reporte, '</h2>
          <p style="margin: 5px 0 0 0; color: #93c5fd; font-size: 13px;">Preparado por: ', input$nombre_analista, ' | Fecha: ', Sys.Date(), '</p>
        </div>
        
        <div style="display: table; width: 100%; margin-bottom: 20px;">
          <div style="display: table-cell; background: white; padding: 15px; border-radius: 6px; text-align: center; border: 1px solid #e2e8f0; width: 32%;">
            <div style="font-size: 11px; color: #64748b; font-weight: bold; text-transform: uppercase;">Inmuebles Filtrados</div>
            <div style="font-size: 22px; font-weight: bold; color: #0f172a; margin-top: 5px;">', num_inmuebles, '</div>
          </div>
          <div style="display: table-cell; width: 2%;"></div>
          <div style="display: table-cell; background: white; padding: 15px; border-radius: 6px; text-align: center; border: 1px solid #e2e8f0; width: 32%;">
            <div style="font-size: 11px; color: #64748b; font-weight: bold; text-transform: uppercase;">Precio Medio Alquiler</div>
            <div style="font-size: 22px; font-weight: bold; color: #0f172a; margin-top: 5px;">', precio_medio, ' €</div>
          </div>
          <div style="display: table-cell; width: 2%;"></div>
          <div style="display: table-cell; background: white; padding: 15px; border-radius: 6px; text-align: center; border: 1px solid #e2e8f0; width: 32%;">
            <div style="font-size: 11px; color: #64748b; font-weight: bold; text-transform: uppercase;">Ratio Medio €/m²</div>
            <div style="font-size: 22px; font-weight: bold; color: #0f172a; margin-top: 5px;">', pm2_medio, ' €/m²</div>
          </div>
        </div>
        
        <h4 style="color: #1e3a8a; border-bottom: 2px solid #3b82f6; padding-bottom: 5px;">Muestra de Inmuebles Destacados</h4>
        <table style="width: 100%; border-collapse: collapse; background: white; border: 1px solid #e2e8f0; font-size: 13px;">
          <thead>
            <tr style="background: #0f172a; color: white;">
              <th style="padding: 10px; text-align: left;">Ciudad</th>
              <th style="padding: 10px; text-align: left;">Título</th>
              <th style="padding: 10px; text-align: left;">Precio</th>
              <th style="padding: 10px; text-align: left;">Superficie</th>
              <th style="padding: 10px; text-align: left;">Ratio</th>
            </tr>
          </thead>
          <tbody>
            ', filas_html, '
          </tbody>
        </table>
      </div>')
    })
    
    # Vista previa en pantalla
    output$vista_previa <- renderUI({
      HTML(generar_html_reporte())
    })
    
    # Handler de descarga
    output$descargar_informe <- downloadHandler(
      filename = function() {
        paste0("GeoAlquiler_Informe_", Sys.Date(), ".html")
      },
      content = function(file) {
        writeLines(generar_html_reporte(), file)
      }
    )
  })
}