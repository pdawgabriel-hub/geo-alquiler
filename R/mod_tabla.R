# Módulo para la tabla interactiva con indicador visual de Favoritos

library(DT)

# 1. UI DEL MÓDULO
tablaUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = "Explorador de Inmuebles Filtrados", 
    width = 12, 
    solidHeader = TRUE, 
    status = "primary",
    div(style = "margin-bottom: 15px;",
      actionButton(
        ns("btn_guardar_fav"), 
        " Añadir / Quitar de Favoritos", 
        icon = icon("star"), 
        class = "btn-warning"
      )
    ),
    DTOutput(ns("tabla_inmuebles"))
  )
}

# 2. SERVER DEL MÓDULO
tablaServer <- function(id, datos_reactivos, favoritos_ids = NULL) {
  moduleServer(id, function(input, output, session) {
    
    proxy_tabla <- dataTableProxy("tabla_inmuebles")
    
    # Render de la tabla reactiva a los datos Y a los favoritos
    output$tabla_inmuebles <- renderDT({
      df <- datos_reactivos()
      
      if (is.null(df) || nrow(df) == 0) return(NULL)
      
      # Obtener lista de IDs favoritos actuales
      favs_actuales <- if (!is.null(favoritos_ids) && (is.reactive(favoritos_ids) || is.function(favoritos_ids))) {
        as.character(favoritos_ids())
      } else {
        c()
      }
      
      # Seleccionar columnas principales
      cols_deseadas <- c("id", "ciudad", "tipo", "precio", "superficie")
      cols_disponibles <- intersect(cols_deseadas, names(df))
      tabla_clean <- df[, cols_disponibles, drop = FALSE]
      
      # Añadir precio/m² si existen las columnas
      if (all(c("precio", "superficie") %in% names(tabla_clean))) {
        tabla_clean$precio_m2 <- round(tabla_clean$precio / tabla_clean$superficie, 1)
      }
      
      # Crear la columna de indicador de Favorito
      if ("id" %in% names(tabla_clean)) {
        es_fav <- as.character(tabla_clean$id) %in% favs_actuales
        tabla_clean$favorito <- ifelse(es_fav, "⭐", "—")
      } else {
        tabla_clean$favorito <- "—"
      }
      
      # Reordenar columnas para poner 'Favorito' al principio
      cols_orden <- c("favorito", setdiff(names(tabla_clean), "favorito"))
      tabla_clean <- tabla_clean[, cols_orden, drop = FALSE]
      
      # Renombrar para visualización limpia
      nombres_map <- c(
        "favorito"   = "Estado",
        "id"         = "ID",
        "ciudad"     = "Ciudad",
        "tipo"       = "Tipo",
        "precio"     = "Precio (€)",
        "superficie" = "Superficie (m²)",
        "precio_m2"  = "€/m²"
      )
      
      colnames(tabla_clean) <- ifelse(
        names(tabla_clean) %in% names(nombres_map),
        nombres_map[names(tabla_clean)],
        names(tabla_clean)
      )
      
      # Renderizar DataTable con resaltado de filas/estilos
      datatable(
        tabla_clean,
        selection = "multiple",
        rownames = FALSE,
        escape = FALSE,
        options = list(
          pageLength = 10,
          lengthMenu = c(5, 10, 25, 50),
          language = list(
            search = "Buscar:",
            lengthMenu = "Mostrar _MENU_ registros",
            info = "Mostrando _START_ a _END_ de _TOTAL_ inmuebles",
            paginate = list(previous = "Anterior", `next` = "Siguiente")
          )
        )
      ) %>%
      # Destacar visualmente la columna "Estado"
      formatStyle(
        "Estado",
        target = "cell",
        fontWeight = styleEqual("⭐", "bold"),
        color = styleEqual(c("⭐", "—"), c("#d9534f", "#aaa")),
        backgroundColor = styleEqual("⭐", "#fff9e6")
      )
    })
    
    # Manejador Toggle (Añadir / Quitar de Favoritos)
    observeEvent(input$btn_guardar_fav, ignoreInit = TRUE, {
      filas_sel <- input$tabla_inmuebles_rows_selected
      
      if (is.null(filas_sel) || length(filas_sel) == 0) {
        showNotification(
          "Selecciona al menos un inmueble en la tabla para cambiar su estado.", 
          type = "warning"
        )
        return()
      }
      
      df <- isolate(datos_reactivos())
      if (is.null(df) || nrow(df) == 0) return()
      
      ids_seleccionados <- if ("id" %in% names(df)) {
        as.character(df$id[filas_sel])
      } else {
        as.character(filas_sel)
      }
      
      ids_seleccionados <- ids_seleccionados[!is.na(ids_seleccionados) & ids_seleccionados != ""]
      
      if (length(ids_seleccionados) > 0 && !is.null(favoritos_ids) && (is.reactive(favoritos_ids) || is.function(favoritos_ids))) {
        actuales <- isolate(as.character(favoritos_ids()))
        
        # Alternar: si ya están, los quita; si no están, los añade
        nuevos_favoritos <- setdiff(ids_seleccionados, actuales)
        ya_existian <- intersect(ids_seleccionados, actuales)
        
        if (length(nuevos_favoritos) > 0) {
          # Añadir nuevos
          actualizados <- unique(c(actuales, nuevos_favoritos))
          favoritos_ids(actualizados)
          showNotification(
            paste(length(nuevos_favoritos), "inmueble(s) añadido(s) a Favoritos"),
            type = "message"
          )
        } else if (length(ya_existian) > 0) {
          # Si todos los seleccionados ya eran favoritos, los eliminamos (modo toggle)
          actualizados <- setdiff(actuales, ya_existian)
          favoritos_ids(actualizados)
          showNotification(
            paste(length(ya_existian), "inmueble(s) quitado(s) de Favoritos"),
            type = "warning"
          )
        }
        
        # Limpiar selección
        selectRows(proxy_tabla, NULL)
      }
    })
    
  })
}