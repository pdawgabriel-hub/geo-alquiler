# R/mod_tabla.R
# Módulo para la tabla interactiva de inmuebles usando la librería DT

library(DT)

# 1. UI DEL MÓDULO
tablaUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = "Explorador de Inmuebles Filtrados", 
    width = 12, 
    solidHeader = TRUE, 
    status = "primary",
    DTOutput(ns("tabla_inmuebles"))
  )
}

# 2. SERVER DEL MÓDULO
tablaServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    output$tabla_inmuebles <- renderDT({
      df <- datos_reactivos()
      
      if (nrow(df) == 0) return(NULL)
      
      # Seleccionamos y formateamos las columnas para presentarlas de forma limpia
      tabla_clean <- df[, c("id", "ciudad", "tipo", "precio", "superficie")]
      tabla_clean$precio_m2 <- round(tabla_clean$precio / tabla_clean$superficie, 1)
      
      colnames(tabla_clean) <- c("ID", "Ciudad", "Tipo", "Precio (€/mes)", "Superficie (m²)", "Precio/m² (€)")
      
      datatable(
        tabla_clean,
        rownames = FALSE,
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
      )
    })
    
  })
}