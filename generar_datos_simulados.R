# Dataset simulado con Barrios, Habitaciones y Baños

set.seed(42)

ciudades <- c("Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao")

barrios_dict <- list(
  "Madrid"    = c("Salamanca", "Chamberí", "Centro", "Retiro", "Malasaña", "Tetuán"),
  "Barcelona" = c("Eixample", "Gràcia", "Sarrià", "Gòtic", "Poblenou", "Sants"),
  "Valencia"  = c("Ciutat Vella", "Eixample", "Ruzafa", "El Carmen", "Algirós"),
  "Sevilla"   = c("Santa Cruz", "Triana", "Nervión", "Macarena", "Los Remedios"),
  "Bilbao"    = c("Abando", "Indautxu", "Casco Viejo", "Deusto", "Uribarri")
)

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
  n <- 200
  cc <- coords[[c]]
  barrios_c <- barrios_dict[[c]]
  
  barrio_sample <- sample(barrios_c, n, replace = TRUE)
  tipos_sample  <- sample(tipos, n, replace = TRUE, prob = prob_tipos)
  superficie    <- round(pmax(30, rnorm(n, mean = 80, sd = 25)))
  habitaciones  <- pmax(1, round(superficie / 30) + sample(-1:1, n, replace = TRUE))
  banos         <- pmax(1, round(habitaciones * 0.6))
  
  mult_ciudad <- ifelse(c %in% c("Madrid", "Barcelona"), 1.4, 1.0)
  mult_tipo   <- ifelse(tipos_sample == "Ático", 1.3, ifelse(tipos_sample == "Estudio", 0.85, 1.0))
  
  precio <- round((superficie * 10 + habitaciones * 150 + banos * 100) * mult_ciudad * mult_tipo * runif(n, 0.85, 1.15))
  
  latitudes  <- cc["lat"] + rnorm(n, mean = 0, sd = 0.03)
  longitudes <- cc["lon"] + rnorm(n, mean = 0, sd = 0.03)
  
  lista_df[[c]] <- data.frame(
    id           = as.character(id_counter:(id_counter + n - 1)),
    titulo       = paste(tipos_sample, "en", barrio_sample, "(", c, ")"),
    ciudad       = c,
    barrio       = barrio_sample,
    tipo         = tipos_sample,
    precio       = precio,
    superficie   = superficie,
    habitaciones = habitaciones,
    banos        = banos,
    lat          = latitudes,
    lon          = longitudes,
    lng          = longitudes,
    stringsAsFactors = FALSE
  )
  
  id_counter <- id_counter + n
}

datos_completos <- do.call(rbind, lista_df)

if (!dir.exists("data/processed")) {
  dir.create("data/processed", recursive = TRUE)
}

saveRDS(datos_completos, "data/processed/alquileres.rds")
cat("Dataset simulado generado (con barrios) en 'data/processed/alquileres.rds'\n")