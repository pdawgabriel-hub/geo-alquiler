# Este script crea un conjunto de datos simulados de inmuebles en España.

set.seed(123) # Fijamos una semilla para que los datos aleatorios sean siempre los mismos

# Coordenadas aproximadas de algunas ciudades españolas
ciudades <- data.frame(
  ciudad = c("Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao"),
  lat_base = c(40.4168, 41.3851, 39.4699, 37.3891, 43.2630),
  lng_base = c(-3.7038, 2.1734, -0.3763, -5.9845, -2.9350)
)

n_pisos <- 200 # Crearemos 200 inmuebles de prueba

# Generamos datos aleatorios asociados a las ciudades
posiciones <- sample(1:nrow(ciudades), n_pisos, replace = TRUE)

datos_alquiler <- data.frame(
  id = 1:n_pisos,
  ciudad = ciudades$ciudad[posiciones],
  # Añadimos un pequeño margen aleatorio a las coordenadas para dispersar los puntos en el mapa
  lat = ciudades$lat_base[posiciones] + rnorm(n_pisos, mean = 0, sd = 0.03),
  lng = ciudades$lng_base[posiciones] + rnorm(n_pisos, mean = 0, sd = 0.03),
  precio = round(runif(n_pisos, min = 500, max = 2800)),
  superficie = round(runif(n_pisos, min = 45, max = 160)),
  tipo = sample(c("Piso", "Casa", "Ático", "Estudio"), n_pisos, replace = TRUE)
)

# Guardamos el resultado en un archivo binario nativo de R (.rds), súper rápido de leer
saveRDS(datos_alquiler, "data/processed/alquileres.rds")

cat("Dataset generado correctamente en 'data/processed/alquileres.rds'\n")