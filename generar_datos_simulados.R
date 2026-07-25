# Generador de dataset ficticio completo y robusto para GeoAlquiler

set.seed(42) # Para datos reproducibles

ciudades <- c("Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao")
coords <- list(
  "Madrid"    = c(lat = 40.4168, lon = -3.7038),
  "Barcelona" = c(lat = 41.3851, lon = 2.1734),
  "Valencia"  = c(lat = 39.4699, lon = -0.3763),
  "Sevilla"   = c(lat = 37.3891, lon = -5.9845),
  "Bilbao"    = c(lat = 43.2630, lon = -2.9350)
)

tipos <- c("Piso", "Apartamento", "Ático", "Estudio", "Casa / Chalet")
prob_tipos <- c(0.4, 0.25, 0.15, 0.1, 0.1)

lista_df <- list()
id_counter <- 1000

for (c in ciudades) {
  n <- 200 # 200 inmuebles por ciudad (1000 registros en total)
  cc <- coords[[c]]
  
  tipos_sample <- sample(tipos, n, replace = TRUE, prob = prob_tipos)
  superficie <- round(pmax(30, rnorm(n, mean = 80, sd = 25)))
  
  # Factor de precio según ciudad y tipo
  mult_ciudad <- ifelse(c %in% c("Madrid", "Barcelona"), 1.4, 1.0)
  mult_tipo <- ifelse(tipos_sample == "Ático", 1.3, ifelse(tipos_sample == "Estudio", 0.85, 1.0))
  
  precio <- round(superficie * 12 * mult_ciudad * mult_tipo * runif(n, 0.8, 1.2))
  
  # Coordenadas dispersas sobre el mapa
  latitudes <- cc["lat"] + rnorm(n, mean = 0, sd = 0.03)
  longitudes <- cc["lon"] + rnorm(n, mean = 0, sd = 0.03)
  
  lista_df[[c]] <- data.frame(
    id          = as.character(id_counter:(id_counter + n - 1)),
    titulo      = paste(tipos_sample, "en", c),
    ciudad      = c,
    tipo        = tipos_sample,
    precio      = precio,
    superficie  = superficie,
    lat         = latitudes,
    lon         = longitudes,
    lng         = longitudes, # Mantenemos 'lng' para compatibilidad completa con mod_mapa.R
    stringsAsFactors = FALSE
  )
  
  id_counter <- id_counter + n
}

datos_completos <- do.call(rbind, lista_df)

# Crear directorio si no existe y guardar
if (!dir.exists("data/processed")) {
  dir.create("data/processed", recursive = TRUE)
}

saveRDS(datos_completos, "data/processed/alquileres.rds")
cat("Dataset ficticio de 1,000 inmuebles generado en 'data/processed/alquileres.rds'\n")