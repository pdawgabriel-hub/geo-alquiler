if (!requireNamespace("arrow", quietly = TRUE)) {
  install.packages("arrow")
}

library(arrow)

# 1. Cargar archivo original RDS
datos <- readRDS("data/processed/alquileres.rds")

# 2. Guardar en formato Parquet comprimido (snappy)
write_parquet(datos, "data/processed/alquileres.parquet")

cat("¡Conversión completada con éxito! Archivo guardado en data/processed/alquileres.parquet\n")