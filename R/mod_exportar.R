# Módulo para la descarga de datos filtrados en formato CSV

# 1. UI DEL MÓDULO
exportarUI <- function(id) {
  ns <- NS(id)
  
  box(
    title = "Exportar Datos", 
    width = 12, 
    status = "info", 
    solidHeader = TRUE,
    p("Descarga la lista de inmuebles según los filtros seleccionados actualmente en pantalla."),
    downloadButton(ns("descargar_csv"), "Descargar en CSV", class = "btn-primary")
  )
}

# 2. SERVER DEL MÓDULO
exportarServer <- function(id, datos_reactivos) {
  moduleServer(id, function(input, output, session) {
    
    # Manejador especial de descargas de Shiny
    output$descargar_csv <- downloadHandler(
      # Nombre del archivo con la fecha del día
      filename = function() {
        paste0("alquileres_filtrados_", Sys.Date(), ".csv")
      },
      # Lógica para escribir el archivo
      content = function(file) {
        # Guardamos en formato CSV estándar compatible con Excel (separador coma)
        write.csv(datos_reactivos(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
    
  })
}