# scripts/ingesta/00_config.R
#
# Configuración central del pipeline de ingesta de datos reales de GeoAlquiler.
# Aquí se define QUÉ ciudades/municipios/zonas cubre la app y DÓNDE queda cada
# fichero (crudo, cacheado, procesado). El resto de scripts de scripts/ingesta/
# solo leen de aquí, así que para añadir o quitar una ciudad basta con tocar
# este fichero.

# --- 1. Rutas del proyecto -----------------------------------------------
# Todos los scripts de scripts/ingesta/ asumen que R se ejecuta con el
# directorio de trabajo en la raíz del proyecto (igual que generar_datos.R),
# es decir: Rscript scripts/ingesta/run_pipeline.R desde geo-alquiler/.

RUTA_RAW        <- "data/raw"
RUTA_PROCESADOS <- "data/processed"
RUTA_APP_DATOS  <- "inst/app/data"

for (ruta in c(RUTA_RAW, RUTA_PROCESADOS, RUTA_APP_DATOS)) {
  if (!dir.exists(ruta)) dir.create(ruta, recursive = TRUE)
}

# --- 2. Municipios objetivo ------------------------------------------------
#
# "ciudad" es el valor que verá el usuario en los filtros de la app (columna
# `ciudad` del dataset final). "nivel_datos" indica con qué grado de detalle
# tenemos precio REAL para ese municipio, y de qué fuente exacta:
#   - "barrio_oficial" -> fuente autonómica real y desagregada por barrio:
#       * Barcelona: fianzas de lloguer dipositades a l'INCASÒL (Generalitat
#         de Catalunya), Excel público, real por barri.
#       * Bilbao: Informe EMAL trimestral (Etxebide / Gobierno Vasco), real
#         por barrio, extraído del PDF oficial.
#   - "municipio_oficial" -> fuente real pero solo a nivel de todo el
#       municipio (no desagregada por barrio):
#       * Valencia: registro de fianzas de alquiler depositadas (Generalitat
#         Valenciana), CSV público de depósitos individuales.
#   - "municipio_ancla" -> NO existe ninguna fuente pública con importe y
#       geografía real (verificado): el precio se fija a mano a partir de un
#       índice publicado (ver data/raw/anclas_manuales.csv) y se marca
#       `es_estimado = TRUE` para no aparentar más precisión de la que hay.
#       * Madrid: la Comunidad de Madrid solo publica CONTEOS agregados de
#         fianzas (sin importe ni desglose geográfico).
#       * Sevilla: Andalucía no tiene datos abiertos de fianzas, y desde
#         01/2026 el depósito de fianza ya no es obligatorio allí (Ley 5/2025).
#
# (SERPAVI del Ministerio de Vivienda se descartó como fuente: verificado que
# es solo una calculadora interactiva protegida con reCAPTCHA, sin descarga
# masiva real -- ver scripts/ingesta/README si se documenta más adelante.)
#
# Además, ZONAS_SIN_FUENTE_OFICIAL abajo permite señalar pedanías/barrios
# concretos DENTRO de un municipio para los que no existe ninguna fuente
# oficial: esas zonas se resuelven con un ancla manual documentada y quedan
# marcadas como estimadas.

MUNICIPIOS_OBJETIVO <- list(
  list(ciudad = "Madrid",     provincia = "Madrid",    nivel_datos = "municipio_ancla"),
  list(ciudad = "Barcelona",  provincia = "Barcelona", nivel_datos = "barrio_oficial"),
  list(ciudad = "Valencia",   provincia = "Valencia",  nivel_datos = "municipio_oficial"),
  list(ciudad = "Sevilla",    provincia = "Sevilla",   nivel_datos = "municipio_ancla"),
  list(ciudad = "Bilbao",     provincia = "Bizkaia",   nivel_datos = "barrio_oficial")
)

# Barrios que queremos poder distinguir DENTRO de Madrid/Sevilla aunque no
# exista fuente oficial a ese nivel (ver 00_config.R, nivel_datos =
# "municipio_ancla" para ambas). Sin esto, Madrid/Sevilla/Valencia aparecían
# con un único "barrio" igual al nombre de la ciudad en el módulo de Análisis
# por Barrios -- estas filas dan dispersión real (aunque estimada) dentro de
# la ciudad. Se resuelven vía data/raw/anclas_manuales.csv y quedan siempre
# marcadas como estimadas.
ZONAS_SIN_FUENTE_OFICIAL <- list(
  list(ciudad = "Madrid",  zona = "Salamanca"),
  list(ciudad = "Madrid",  zona = "Chamberí"),
  list(ciudad = "Madrid",  zona = "Centro"),
  list(ciudad = "Madrid",  zona = "Malasaña"),
  list(ciudad = "Madrid",  zona = "Retiro"),
  list(ciudad = "Sevilla", zona = "Triana"),
  list(ciudad = "Sevilla", zona = "Santa Cruz"),
  list(ciudad = "Sevilla", zona = "Nervión"),
  list(ciudad = "Sevilla", zona = "Macarena"),
  list(ciudad = "Sevilla", zona = "Los Remedios")
)

# --- 3. Tipologías y distribución usada para generar los "anuncios" --------
# (mismos valores que generar_datos_simulados.R, se mantienen para no romper
# el resto de módulos de la app, que esperan estos tipos exactos)
TIPOS_INMUEBLE <- c("Piso", "Apartamento", "Ático", "Estudio", "Casa / Chalet")
PROB_TIPOS     <- c(0.40, 0.25, 0.15, 0.10, 0.10)

# Nº de "anuncios" sintéticos a generar por zona con dato de precio (ajustable)
N_ANUNCIOS_POR_ZONA_MIN <- 15
N_ANUNCIOS_POR_ZONA_MAX <- 40

# --- 4. Semilla ------------------------------------------------------------
# Solo afecta a la parte NO real del dataset (dispersión de los anuncios
# alrededor del precio/m² real de cada zona), para que el resultado sea
# reproducible entre ejecuciones del pipeline.
SEMILLA_GENERACION <- 2026
