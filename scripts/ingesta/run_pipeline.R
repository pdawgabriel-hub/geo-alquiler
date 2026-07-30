# scripts/ingesta/run_pipeline.R
#
# Orquestador end-to-end del pipeline de datos reales de GeoAlquiler.
# Sustituye a generar_datos_simulados.R: en vez de inventar precios con
# multiplicadores arbitrarios, descarga/parsea fuentes reales (Generalitat de
# Catalunya, Generalitat Valenciana, Gobierno Vasco/Etxebide, y anclas
# manuales documentadas para las ciudades sin fuente oficial), las
# geocodifica y genera los "anuncios" individuales que consume el resto de
# la app.
#
# Uso (desde la raíz del proyecto geo-alquiler/):
#   Rscript scripts/ingesta/run_pipeline.R
#
# Requiere paquetes: httr, jsonlite, readxl, arrow (instálalos si hace falta
# con install.packages(c("httr","jsonlite","readxl","arrow"))), y el binario
# de sistema `pdftotext` (paquete poppler-utils) para la fuente de Bilbao.
#
# Las 3 URLs de fuentes reales (Barcelona, Valencia, Bilbao) están
# verificadas por descarga real, no solo citadas -- pero pueden quedar
# desactualizadas con el tiempo (sobre todo Bilbao, cuyo PDF trimestral
# cambia de nombre cada trimestre). Si una fuente falla, el aviso indica
# la ruta manual donde puedes dejar el fichero descargado a mano
# (data/raw/bilbao_manual.pdf, etc.) para seguir sin depender de la URL.

directorio_script <- dirname(sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)))
if (length(directorio_script) == 1 && nzchar(directorio_script)) setwd(file.path(directorio_script, "..", ".."))

fuentes <- c(
  "00_config.R", "01_utils.R", "02_fuente_barcelona.R", "03_fuente_valencia.R",
  "04_fuente_bilbao.R", "05_anclas_manuales.R", "06_geocodificar_zonas.R",
  "07_armonizar_precios.R", "08_generar_anuncios.R"
)
for (f in fuentes) source(file.path("scripts", "ingesta", f))

message("== 1/5: Descargando y parseando Barcelona (INCASÒL / Generalitat de Catalunya) ==")
ruta_bcn <- descargar_barcelona()
barcelona_df <- tryCatch(parsear_barcelona(ruta_bcn), error = function(e) { message("  -> ", conditionMessage(e)); NULL })

message("== 2/5: Descargando y parseando Valencia (fianzas Generalitat Valenciana) ==")
ruta_vlc <- descargar_valencia()
valencia_df <- tryCatch(parsear_valencia(ruta_vlc), error = function(e) { message("  -> ", conditionMessage(e)); NULL })

message("== 3/5: Descargando y parseando Bilbao (Informe EMAL / Etxebide) ==")
ruta_bilbao <- descargar_bilbao()
bilbao_df <- tryCatch(parsear_bilbao(ruta_bilbao), error = function(e) { message("  -> ", conditionMessage(e)); NULL })

message("== 4/5: Cargando anclas manuales (Madrid/Sevilla, sin fuente oficial) ==")
anclas_df <- cargar_anclas_manuales()

message("== Armonizando todas las fuentes en una tabla única de precios/m² por zona ==")
precios_zona <- armonizar_precios(barcelona_df, valencia_df, bilbao_df, anclas_df)
message("  Zonas con dato de precio: ", nrow(precios_zona))

message("== 5/5: Geocodificando zonas (Nominatim, ~1 seg/zona nueva) ==")
precios_zona <- geocodificar_precios_zona(precios_zona)

message("== Generando anuncios individuales a partir del precio/m² real de cada zona ==")
datos_completos <- generar_anuncios(precios_zona)
message("  Anuncios generados: ", nrow(datos_completos))
message("  De ellos, estimados (sin fuente oficial): ", sum(datos_completos$es_estimado))

message("== Guardando dataset final ==")
saveRDS(datos_completos, file.path(RUTA_PROCESADOS, "alquileres.rds"))

if (requireNamespace("arrow", quietly = TRUE)) {
  arrow::write_parquet(datos_completos, file.path(RUTA_PROCESADOS, "alquileres.parquet"))
  file.copy(file.path(RUTA_PROCESADOS, "alquileres.parquet"), file.path(RUTA_APP_DATOS, "alquileres.parquet"), overwrite = TRUE)
  message("  Guardado en ", file.path(RUTA_PROCESADOS, "alquileres.parquet"), " y copiado a ", RUTA_APP_DATOS, "/")
} else {
  warning("Paquete 'arrow' no instalado: se ha guardado solo el .rds. Instala arrow y vuelve a ejecutar para generar el .parquet que usa la app.")
}

message("== Pipeline completado ==")
