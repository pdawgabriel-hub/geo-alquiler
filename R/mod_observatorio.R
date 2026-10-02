# Módulo Observatorio del Alquiler en España: mapa coroplético municipal que
# cruza SERPAVI (Ministerio de Vivienda) con renta y población del INE y el
# parque residencial del Catastro. Los datos vienen ya cruzados del pipeline
# (scripts/ingesta/09_observatorio.R); aquí solo se filtran y se pintan. La
# lógica de cálculo y formato vive en R/fct_observatorio.R.

TODA_ESPANA <- "Toda España"
COLOR_SIN_DATO <- "#bdbdbd"
# Encuadre de la vista nacional: Península y Baleares. Con st_bbox() de toda
# España el mapa quedaría centrado en el Atlántico por culpa de Canarias
# (que siguen pintadas, desplazando el mapa).
ENCUADRE_ESPANA <- c(-9.4, 35.9, 4.4, 43.8)
# Separador entre nombre y valor en la etiqueta de cada municipio; el JS de
# recoloreo (inst/app/www/custom.js) lo usa para sustituir solo el valor.
SEP_ETIQUETA <- " \u2014 "

# Caché por proceso de la geometría de cada ámbito ya convertida a JSON.
# Convertir ~8.000 polígonos al formato de leaflet y serializarlos cuesta
# ~5 s de CPU; así solo lo paga la primera sesión que abre cada ámbito, y las
# siguientes (y los cambios de ámbito de ida y vuelta) lo reutilizan.
.cache_geometria_obs <- new.env(parent = emptyenv())

geometria_leaflet_json <- function(clave, poligonos_sf) {
  if (is.null(.cache_geometria_obs[[clave]])) {
    llamada <- leaflet() %>% addPolygons(data = poligonos_sf)
    geom <- llamada$x$calls[[1]]$args[[1]]
    # 5 decimales en grados ~ 1 m: más precisión no se ve y engorda el envío
    .cache_geometria_obs[[clave]] <- jsonlite::toJSON(geom, digits = 5, auto_unbox = TRUE, dataframe = "columns")
  }
  .cache_geometria_obs[[clave]]
}

#' Igual que leafletProxy() %>% addPolygons(), pero con la geometría ya
#' serializada (clase "json": shiny la inserta tal cual en el mensaje).
#' El resto de argumentos (colores, etiquetas...) se generan con el propio
#' addPolygons() de leaflet sobre un polígono ficticio, para no depender del
#' orden interno de sus argumentos.
#' @noRd
anadir_poligonos_cacheados <- function(proxy, geom_json, ...) {
  llamada <- leaflet() %>% addPolygons(lng = c(0, 1, 1), lat = c(0, 0, 1), ...)
  args <- llamada$x$calls[[1]]$args
  args[[1]] <- geom_json
  do.call(invokeMethod, c(list(proxy, NULL, "addPolygons"), args))
}

observatorioUI <- function(id) {
  ns <- NS(id)
  ind <- indicadores_observatorio()

  tagList(
    fluidRow(
      box(
        title = tagList(icon("landmark"), " Observatorio del Alquiler en España"),
        width = 12, status = "primary", solidHeader = TRUE,
        fluidRow(
          column(4, selectInput(ns("indicador"), "Indicador en el mapa:",
                                choices = stats::setNames(ind$id, ind$etiqueta))),
          column(3, selectInput(ns("ambito"), "Ámbito:", choices = TODA_ESPANA)),
          column(2, selectInput(ns("poblacion_min"), "Población mínima (gráfico y ranking):",
                                choices = c("Todos" = 0, "1.000 hab." = 1000, "5.000 hab." = 5000,
                                            "20.000 hab." = 20000, "50.000 hab." = 50000,
                                            "100.000 hab." = 100000),
                                selected = 5000)),
          column(3, uiOutput(ns("nota_fuentes")))
        )
      )
    ),

    fluidRow(
      valueBoxOutput(ns("kpi_alquiler_m2"), width = 3),
      valueBoxOutput(ns("kpi_esfuerzo"), width = 3),
      valueBoxOutput(ns("kpi_renta"), width = 3),
      valueBoxOutput(ns("kpi_viviendas_alquiler"), width = 3)
    ),

    fluidRow(
      box(
        title = tagList(icon("map"), " Mapa municipal"),
        width = 8, status = "primary", solidHeader = TRUE,
        leafletOutput(ns("mapa"), height = 560)
      ),
      box(
        title = tagList(icon("id-card"), " Ficha del municipio"),
        width = 4, status = "info", solidHeader = TRUE,
        uiOutput(ns("ficha"))
      )
    ),

    fluidRow(
      box(
        title = tagList(icon("chart-line"), " Renta del hogar vs. alquiler €/m²"),
        width = 6, status = "warning", solidHeader = TRUE,
        plotlyOutput(ns("grafico_renta_alquiler"), height = 420)
      ),
      box(
        title = tagList(icon("list-ol"), " Ranking de municipios"),
        width = 6, status = "warning", solidHeader = TRUE,
        DTOutput(ns("ranking"))
      )
    )
  )
}

observatorioServer <- function(id, datos_observatorio) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Sin fichero de observatorio la app sigue funcionando: el módulo avisa
    # en vez de romper el resto de pestañas.
    if (is.null(datos_observatorio)) {
      output$nota_fuentes <- renderUI(
        p(class = "text-danger", "No se ha encontrado observatorio_municipios.parquet. ",
          "Genéralo con Rscript scripts/ingesta/run_pipeline.R --solo-observatorio")
      )
      return(invisible(NULL))
    }

    # Dos niveles de detalle de la misma geometría (ver 09_observatorio.R):
    # el grueso para toda España y el fino al filtrar por provincia.
    obs_detalle <- observatorio_a_sf(datos_observatorio, "geometria")
    obs_nacional <- observatorio_a_sf(datos_observatorio, "geometria_baja")
    tabla_obs <- sf::st_drop_geometry(obs_detalle)
    anio <- tabla_obs$anio_referencia[1]
    anio_pob <- max(tabla_obs$anio_poblacion_ultima, na.rm = TRUE)

    provincias <- sort(unique(stats::na.omit(tabla_obs$provincia)))
    updateSelectInput(session, "ambito", choices = c(TODA_ESPANA, provincias))

    output$nota_fuentes <- renderUI(
      p(style = "font-size: 12px; color: #666;",
        paste0("Datos de ", anio, ": SERPAVI (Mº de Vivienda), INE (renta y padrón) y Catastro. ",
               "País Vasco y Navarra no tienen datos de alquiler ni de Catastro estatal (régimen foral)."))
    )

    municipio_sel <- reactiveVal(NULL)

    # --- Datos según ámbito ---------------------------------------------------
    datos_ambito <- reactive({
      req(input$ambito)
      if (input$ambito == TODA_ESPANA) {
        obs_nacional
      } else {
        obs_detalle[!is.na(obs_detalle$provincia) & obs_detalle$provincia == input$ambito, ]
      }
    })

    # Municipios para gráfico y ranking (filtro de población mínima)
    tabla_ambito <- reactive({
      df <- sf::st_drop_geometry(datos_ambito())
      pob_min <- as.numeric(input$poblacion_min)
      df[!is.na(df$poblacion) & df$poblacion >= pob_min, ]
    })

    observeEvent(input$ambito, municipio_sel(NULL), ignoreInit = TRUE)

    # --- Estilo del mapa -------------------------------------------------------
    estilo_indicador <- function(df, id_ind) {
      fila <- indicadores_observatorio()[indicadores_observatorio()$id == id_ind, ]
      valores <- df[[id_ind]]
      cortes <- cortes_cuantiles(valores)
      paleta_nombre <- if (fila$sentido == 1) "YlOrRd" else "YlGnBu"
      pal <- if (is.null(cortes)) {
        function(x) rep(COLOR_SIN_DATO, length(x))
      } else {
        colorBin(paleta_nombre, domain = range(cortes), bins = cortes, na.color = COLOR_SIN_DATO)
      }
      # Etiquetas en texto plano y cortas: con ~8.000 municipios, cada byte
      # de más por etiqueta son ~8 KB más que viajan al navegador.
      valores_txt <- formatear_indicador(valores, id_ind)
      list(
        pal = pal, cortes = cortes, valores = valores, fila = fila,
        colores = unname(pal(valores)),
        opacidades = ifelse(is.na(valores), 0.35, 0.8),
        valores_txt = valores_txt,
        etiquetas = paste0(df$municipio, " (", df$provincia, ")", SEP_ETIQUETA, valores_txt)
      )
    }

    anadir_leyenda <- function(mapa, est) {
      if (is.null(est$cortes)) return(mapa %>% removeControl("leyenda_obs"))
      mapa %>% addLegend(
        # El NA en `values` hace que la leyenda incluya la clase "Sin dato"
        position = "bottomright", pal = est$pal, values = c(est$cortes, NA),
        title = paste0(est$fila$etiqueta, "<br><small>", est$fila$fuente, ", cuantiles</small>"),
        opacity = 0.85, na.label = "Sin dato", layerId = "leyenda_obs",
        # labelFormat() de leaflet no admite coma decimal: formato propio
        labFormat = function(type, cuts, p) {
          f <- formatC(cuts, format = "f", digits = est$fila$decimales, big.mark = ".", decimal.mark = ",")
          paste0(f[-length(f)], " – ", f[-1])
        }
      )
    }

    # El mapa base se pinta una sola vez; los polígonos se cambian después
    # por leafletProxy. Volver a renderizar el widget al cambiar de ámbito
    # destruye el mapa con un redibujado de canvas pendiente, y Leaflet lanza
    # un error ("clearRect") en el navegador.
    output$mapa <- renderLeaflet({
      leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
        addProviderTiles(providers$CartoDB.Positron, group = "Mapa Claro") %>%
        addTiles(group = "OpenStreetMap") %>%
        fitBounds(ENCUADRE_ESPANA[1], ENCUADRE_ESPANA[2], ENCUADRE_ESPANA[3], ENCUADRE_ESPANA[4]) %>%
        addLayersControl(baseGroups = c("OpenStreetMap", "Mapa Claro"),
                         options = layersControlOptions(collapsed = TRUE))
    })

    # La pestaña empieza oculta y Shiny no pinta el mapa hasta que se abre:
    # los mensajes de leafletProxy enviados antes se perderían. El mapa
    # informa de su encuadre al pintarse, y eso marca que ya está listo
    # (reactiveVal solo invalida al cambiar de valor, así que los
    # siguientes cambios de encuadre no vuelven a disparar nada).
    mapa_listo <- reactiveVal(FALSE)
    observeEvent(input$mapa_bounds, mapa_listo(TRUE))

    # Polígonos del ámbito. El indicador se lee con isolate(): cambiarlo solo
    # recolorea los polígonos ya pintados (observer de abajo).
    observe({
      req(mapa_listo())
      df <- datos_ambito()
      est <- estilo_indicador(sf::st_drop_geometry(df), isolate(input$indicador))
      caja <- if (isolate(input$ambito) == TODA_ESPANA) ENCUADRE_ESPANA else as.numeric(sf::st_bbox(df))

      geom_json <- geometria_leaflet_json(isolate(input$ambito), df)

      leafletProxy("mapa") %>%
        clearShapes() %>%
        clearGroup("seleccion") %>%
        anadir_poligonos_cacheados(
          geom_json,
          layerId = df$cod_ine,
          fillColor = est$colores,
          fillOpacity = est$opacidades,
          color = "#ffffff", weight = 0.4, opacity = 0.9,
          smoothFactor = 0.5,
          label = est$etiquetas,
          highlightOptions = highlightOptions(weight = 2.5, color = "#2c3e50", bringToFront = TRUE)
        ) %>%
        fitBounds(caja[1], caja[2], caja[3], caja[4]) %>%
        anadir_leyenda(est)
    })

    observeEvent(input$indicador, {
      df <- sf::st_drop_geometry(datos_ambito())
      est <- estilo_indicador(df, input$indicador)
      session$sendCustomMessage("observatorio_recolorear", list(
        mapa = ns("mapa"),
        ids = df$cod_ine,
        colores = est$colores,
        valores = est$valores_txt,
        sin_dato = formatear_indicador(NA, input$indicador),
        separador = SEP_ETIQUETA
      ))
      leafletProxy("mapa") %>% anadir_leyenda(est)
    }, ignoreInit = TRUE)

    # Selección de municipio: clic en el mapa, en el gráfico o en el ranking
    observeEvent(input$mapa_shape_click, {
      municipio_sel(input$mapa_shape_click$id)
    })

    observeEvent(municipio_sel(), {
      cod <- municipio_sel()
      fila <- tabla_obs[tabla_obs$cod_ine == cod, ]
      req(nrow(fila) == 1, !is.na(fila$lat_centro))
      leafletProxy("mapa") %>%
        clearGroup("seleccion") %>%
        addCircleMarkers(lng = fila$lng_centro, lat = fila$lat_centro, radius = 6,
                         color = "#c0392b", fillColor = "#e74c3c", fillOpacity = 1, weight = 2,
                         group = "seleccion")
    })

    # --- KPIs del ámbito (ponderados por población o por viviendas) -----------
    kpi_box <- function(valor, subtitulo, icono, color) {
      shinydashboard::valueBox(valor, subtitulo, icon = icon(icono), color = color)
    }
    media_ponderada <- function(x, w) {
      ok <- !is.na(x) & !is.na(w)
      if (!any(ok)) return(NA_real_)
      sum(x[ok] * w[ok]) / sum(w[ok])
    }

    output$kpi_alquiler_m2 <- shinydashboard::renderValueBox({
      df <- sf::st_drop_geometry(datos_ambito())
      v <- media_ponderada(df$alquiler_m2_mediana, df$viviendas_alquiler)
      kpi_box(formatear_indicador(v, "alquiler_m2_mediana"),
              "Alquiler €/m² (media ponderada por viviendas alquiladas)", "euro-sign", "purple")
    })

    output$kpi_esfuerzo <- shinydashboard::renderValueBox({
      df <- sf::st_drop_geometry(datos_ambito())
      v <- media_ponderada(df$esfuerzo_alquiler_pct, df$poblacion)
      kpi_box(formatear_indicador(v, "esfuerzo_alquiler_pct"),
              "Esfuerzo: alquiler anual / renta del hogar", "percent",
              if (!is.na(v) && v >= 30) "red" else "orange")
    })

    output$kpi_renta <- shinydashboard::renderValueBox({
      df <- sf::st_drop_geometry(datos_ambito())
      v <- media_ponderada(df$renta_hogar, df$poblacion)
      kpi_box(formatear_indicador(v, "renta_hogar"), "Renta neta media por hogar (ponderada)",
              "wallet", "green")
    })

    output$kpi_viviendas_alquiler <- shinydashboard::renderValueBox({
      df <- sf::st_drop_geometry(datos_ambito())
      total <- sum(df$viviendas_alquiler, na.rm = TRUE)
      kpi_box(formatC(total, format = "d", big.mark = ".", decimal.mark = ","),
              paste0("Viviendas con alquiler declarado (", sum(!is.na(df$alquiler_m2_mediana)),
                     " municipios con dato)"),
              "house-user", "blue")
    })

    # --- Ficha del municipio ---------------------------------------------------
    output$ficha <- renderUI({
      cod <- municipio_sel()
      if (is.null(cod)) {
        return(p(style = "color:#666;", icon("hand-pointer"),
                 " Haz clic en un municipio del mapa, del gráfico o del ranking para ver su ficha."))
      }
      fila <- tabla_obs[tabla_obs$cod_ine == cod, ]
      req(nrow(fila) == 1)

      # Territorios compartidos entre municipios (parzonerías, comunidades de
      # montes): tienen polígono en el mapa pero ninguna fuente los cubre.
      if (isFALSE(fila$es_municipio)) {
        return(tagList(
          h3(style = "margin-top:0;", fila$municipio),
          p(style = "color:#666;", icon("circle-info"),
            " Territorio compartido entre varios municipios, no un municipio en sí. ",
            "Ni SERPAVI, ni el INE ni el Catastro publican datos para estos territorios.")
        ))
      }

      ind <- indicadores_observatorio()
      alquiler_unifamiliar <- identical(fila$tipo_vivienda_alquiler, "unifamiliar")
      filas_tabla <- lapply(seq_len(nrow(ind)), function(i) {
        id_ind <- ind$id[i]
        v <- fila[[id_ind]]
        # Percentil frente al resto de municipios de España con dato
        todos <- tabla_obs[[id_ind]]
        pct <- if (is.na(v)) NA else round(100 * mean(todos[!is.na(todos)] <= v))
        motivo <- motivo_sin_dato(fila, id_ind)
        nota_unifamiliar <- alquiler_unifamiliar && !is.na(v) &&
          id_ind %in% c("alquiler_m2_mediana", "alquiler_mes_mediana", "esfuerzo_alquiler_pct")
        tags$tr(
          tags$td(ind$etiqueta[i], tags$br(), tags$small(style = "color:#888;", ind$fuente[i]),
                  if (!is.null(motivo)) tags$div(tags$small(style = "color:#b9770e;", motivo)),
                  if (nota_unifamiliar) tags$div(tags$small(style = "color:#b9770e;",
                    "dato de vivienda unifamiliar: SERPAVI no publica mediana de pisos aquí"))),
          tags$td(style = "text-align:right; white-space:nowrap;",
                  tags$b(formatear_indicador(v, id_ind)),
                  if (!is.na(pct)) tags$div(tags$small(style = "color:#888;", paste0("percentil ", pct))))
        )
      })

      tagList(
        h3(style = "margin-top:0;", fila$municipio),
        p(style = "color:#666;", fila$provincia, " · código INE ", fila$cod_ine),
        tags$table(class = "table table-condensed", style = "font-size:13px;", tags$tbody(filas_tabla)),
        p(style = "font-size:11px; color:#888;",
          paste0("Percentil: % de municipios de España con dato que tienen un valor igual o inferior. ",
                 "Población a ", anio, "; crecimiento ", anio, "-", anio_pob, "."))
      )
    })

    # --- Gráfico renta vs. alquiler -------------------------------------------
    output$grafico_renta_alquiler <- renderPlotly({
      df <- tabla_ambito()
      df <- df[!is.na(df$renta_hogar) & !is.na(df$alquiler_m2_mediana), ]
      validate(need(nrow(df) > 0, "No hay municipios con renta y alquiler para este ámbito y población mínima."))

      texto <- paste0(
        "<b>", df$municipio, "</b> (", df$provincia, ")",
        "<br>Renta hogar: ", formatear_indicador(df$renta_hogar, "renta_hogar"),
        "<br>Alquiler: ", formatear_indicador(df$alquiler_m2_mediana, "alquiler_m2_mediana"),
        "<br>Esfuerzo: ", formatear_indicador(df$esfuerzo_alquiler_pct, "esfuerzo_alquiler_pct"),
        "<br>Población: ", formatear_indicador(df$poblacion, "poblacion")
      )

      p <- plot_ly(source = ns("dispersion")) %>%
        add_markers(
          data = df, x = ~renta_hogar, y = ~alquiler_m2_mediana,
          customdata = ~cod_ine, text = texto, hoverinfo = "text",
          color = ~esfuerzo_alquiler_pct, colors = "YlOrRd",
          # Tamaño de burbuja proporcional a la población (en área). Se
          # calcula aquí en vez de con `size = ~poblacion`, que en plotly
          # dispara un aviso por cada render sobre `line.width`.
          marker = list(
            size = 6 + 39 * sqrt(df$poblacion / max(df$poblacion)),
            sizemode = "diameter", opacity = 0.8,
            line = list(width = 0.5, color = "#555")
          ),
          name = "Municipios"
        )

      cod <- municipio_sel()
      if (!is.null(cod) && cod %in% df$cod_ine) {
        s <- df[df$cod_ine == cod, ]
        p <- p %>% add_markers(
          x = s$renta_hogar, y = s$alquiler_m2_mediana, inherit = FALSE,
          marker = list(symbol = "star", size = 18, color = "#2c3e50"),
          text = s$municipio, hoverinfo = "text", name = s$municipio
        )
      }

      p %>%
        layout(
          xaxis = list(title = paste0("Renta neta media por hogar (€, ", anio, ")")),
          yaxis = list(title = "Alquiler mediano (€/m² al mes)"),
          showlegend = FALSE,
          margin = list(t = 10)
        ) %>%
        colorbar(title = "Esfuerzo (%)") %>%
        event_register("plotly_click") %>%
        config(displayModeBar = FALSE)
    })

    # Se lee directamente el input que publica plotly ("plotly_click-<source>",
    # sin namespace de módulo) en vez de usar event_data(): este observer se
    # crea al arrancar, antes de que el gráfico exista (solo se pinta al abrir
    # la pestaña), y event_data() emite entonces en cada sesión un aviso
    # diferido de "evento no registrado" que no se puede silenciar.
    observeEvent(session$rootScope()$input[[paste0("plotly_click-", ns("dispersion"))]], {
      clic <- jsonlite::parse_json(
        session$rootScope()$input[[paste0("plotly_click-", ns("dispersion"))]],
        simplifyVector = TRUE
      )
      if (!is.null(clic$customdata)) municipio_sel(clic$customdata)
    })

    # --- Ranking --------------------------------------------------------------
    ranking_df <- reactive({
      id_ind <- input$indicador
      df <- tabla_ambito()
      df <- df[!is.na(df[[id_ind]]), ]
      df <- df[order(-df[[id_ind]]), ]
      df
    })

    output$ranking <- renderDT({
      df <- ranking_df()
      id_ind <- input$indicador
      etiqueta <- indicadores_observatorio()$etiqueta[indicadores_observatorio()$id == id_ind]
      tabla <- data.frame(
        Municipio = df$municipio,
        Provincia = df$provincia,
        Valor = df[[id_ind]],
        Poblacion = df$poblacion,
        stringsAsFactors = FALSE
      )
      names(tabla)[3] <- etiqueta
      names(tabla)[4] <- "Población"

      decimales <- indicadores_observatorio()$decimales[indicadores_observatorio()$id == id_ind]
      datatable(
        tabla,
        rownames = FALSE,
        selection = "single",
        options = list(pageLength = 10, scrollX = TRUE, order = list(list(2, "desc")),
                       language = list(url = "https://cdn.datatables.net/plug-ins/1.10.11/i18n/Spanish.json"))
      ) %>%
        DT::formatRound(3, digits = decimales, mark = ".", dec.mark = ",") %>%
        DT::formatRound(4, digits = 0, mark = ".")
    })

    observeEvent(input$ranking_rows_selected, {
      df <- ranking_df()
      fila <- df[input$ranking_rows_selected, ]
      req(nrow(fila) == 1)
      municipio_sel(fila$cod_ine)
      if (!is.na(fila$lat_centro)) {
        leafletProxy("mapa") %>% flyTo(fila$lng_centro, fila$lat_centro, zoom = 10)
      }
    })
  })
}
