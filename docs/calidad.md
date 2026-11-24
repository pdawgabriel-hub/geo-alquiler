# Calidad

## Tests {#tests}

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'                       # todos
Rscript -e 'testthat::test_file("tests/testthat/test_observatorio.R")'   # uno concreto
```

Hay **29 tests** (`test_that()`) con **102 comprobaciones** (`expect_*()`):

| Fichero | Tests | Comprobaciones | Qué cubre |
|---|---|---|---|
| `test_calculos.R` | 12 | 52 | Las funciones de `fct_calculos.R`: KPIs (también con un conjunto vacío); validación del encuadre del mapa; cuota hipotecaria y proyección año a año; oportunidades frente a la media de su ciudad; distancia del recomendador KNN, con y sin coordenadas; fórmula de predicción con una sola ciudad. Más un `testServer` de la Calculadora |
| `test_observatorio.R` | 15 | 47 | Indicadores derivados y datos ausentes; formato numérico español; cortes por cuantiles; reconstrucción de la geometría; normalización y cruce exacto y aproximado de nombres de municipio; motivo de cada dato ausente; parseo de las tablas del Catastro; JSON de geometría idéntico al de Leaflet; caché por ámbito; y el módulo completo con `testServer` |
| `test_mod_tabla.R`, `test_tabla.R` | 2 | 3 | Módulo de tabla: marcar y desmarcar favoritos (`testServer`) |

### Cómo están organizados

Los tests cargan el código que prueban con `source()`, en vez de instalar el paquete:

```r
source("../../R/fct_calculos.R")
source("../../R/mod_calculadora.R")
```

`testthat::test_dir()` ejecuta cada fichero con `tests/testthat/` como directorio de trabajo, de ahí la ruta `../../R/`. Esto tiene dos ventajas: los tests corren en segundos sin construir el paquete, y cada fichero declara exactamente qué código usa. A cambio, si el código usa funciones de otros paquetes sin prefijo (por ejemplo `renderValueBox` de `shinydashboard`), el test tiene que cargarlos con `library()`.

Hay tres tipos de test, de más simple a más completo:

**1. Funciones puras con valores de referencia.** La mayoría. Se comprueba el resultado contra un valor calculado a mano o conocido, nunca recalculándolo con la misma fórmula dentro del test (eso solo comprobaría que la fórmula es igual a sí misma):

```r
test_that("cuota_hipoteca aplica el sistema francés", {
  # Valor de referencia: 200.000 € a 30 años al 3 % -> 843,21 €/mes
  expect_equal(round(cuota_hipoteca(200000, 0.03, 30), 2), 843.21)
  # Sin interés, la cuota es el capital entre el número de meses
  expect_equal(cuota_hipoteca(120000, 0, 10), 1000)
})
```

**2. Tests de regresión: casos que ya fallaron una vez.** Cuando se arregla un fallo, se añade un test con el caso exacto que lo provocaba, para que no vuelva. Por ejemplo, un encuadre del mapa sin área (que Leaflet reporta un instante al redimensionar) vaciaba siete pantallas:

```r
degenerado <- list(north = 40.5, south = 40.5, east = -3.6, west = -3.6)
expect_equal(nrow(filtrar_por_encuadre(df, degenerado)), nrow(df))
```

Otro del mismo tipo: la predicción con una sola ciudad, con la que `lm()` fallaba por tener un factor de un solo nivel.

**3. Módulos con `testServer()`.** Ejecuta el servidor de un módulo sin navegador: se simulan inputs con `session$setInputs()` y se inspeccionan sus `reactive` internos directamente por su nombre:

```r
test_that("La calculadora pasa los porcentajes de los inputs a tanto por uno", {
  testServer(calculadoraServer, {
    session$setInputs(precio_compra = 200000, alquiler_mensual = 1000, gastos_mantenimiento = 1200,
                      porcentaje_entrada = 20, interes_hipoteca = 3, plazo_anos = "25",
                      incremento_alquiler = 2, apreciacion_inmueble = 1)
    expect_equal(simulacion(), simular_inversion(200000, 1000, 1200, 0.2, 0.03, 25, 0.02, 0.01))
  })
})
```

Este test no repite la lógica financiera (ya la prueba el tipo 1): solo comprueba el **cableado**, que es justo lo que puede romperse en el módulo, por ejemplo olvidar dividir entre 100.

### Datos de prueba

Los tests no leen los Parquet reales: construyen pequeños `data.frame` con valores elegidos para que el resultado esperado sea fácil de calcular a mano. En `test_calculos.R`, `inmuebles_mock()` tiene cinco inmuebles en dos ciudades, con precios/m² de 10, 10 y 7 en Madrid, de modo que la media es 9 y el tercero está un 22,2 % por debajo. En `test_observatorio.R`, `observatorio_mock()` reproduce el formato del Parquet del Observatorio (geometría en WKB incluida) con dos municipios.

### Refactorizar sin cambiar el comportamiento

Al mover los cálculos de los módulos a `fct_calculos.R`, antes de tocar ningún módulo se comprobó que cada función nueva daba exactamente lo mismo que el código original: se compararon contra una copia literal del código antiguo con datos reales y entradas aleatorias (200 simulaciones de la Calculadora, siete umbrales de oportunidades, 20 inmuebles del recomendador y los KPIs con datos completos, vacíos y de una sola ciudad). Es la forma segura de reorganizar código que no tenía tests: primero fijar su comportamiento actual y luego moverlo.

### Escribir un test nuevo

1. Si el cálculo está dentro de un módulo, sácalo a una función en `R/fct_*.R` y haz que el módulo la llame.
2. Escribe en `tests/testthat/test_*.R` un `test_that("frase que describe el comportamiento", { ... })` con datos pequeños y resultados calculados a mano. Prueba también el caso vacío y los extremos.
3. Si arreglas un fallo, añade el caso exacto que lo provocaba.
4. Ejecuta `Rscript -e 'testthat::test_dir("tests/testthat")'`. Al hacer push, GitHub ejecutará los mismos tests (ver [Integración continua](#ci)).

Para una validación completa del paquete (tests, `DESCRIPTION`, documentación y estructura):

```bash
R CMD build .
R CMD check --no-manual GeoAlquiler_*.tar.gz
```

## Integración continua {#ci}

`.github/workflows/ci.yml` ejecuta los tests en GitHub en cada push y en cada pull request. El resultado aparece en la insignia **Tests** del README, junto a cada commit y en la pestaña [*Actions*](https://github.com/pdawgabriel-hub/geo-alquiler/actions) del repositorio.

Los cambios que solo tocan la documentación (`docs/`, `mkdocs.yml`, `requirements-docs.txt` y su workflow) no lo lanzan (`paths-ignore`): no pueden romper la app y así no la vuelven a desplegar. De esos se encarga `.github/workflows/docs.yml`, que construye esta guía con `mkdocs build --strict` (un enlace roto hace fallar la construcción) y la publica en GitHub Pages.

### Qué hace el workflow

Tiene dos jobs. **Tests** se ejecuta siempre:

| Paso | Qué hace y por qué |
|---|---|
| `actions/checkout@v5` | Descarga el código del commit. |
| Instalar librerías del sistema | `apt-get install` de GDAL, GEOS, PROJ, udunits, SQLite, libcurl, OpenSSL y libxml2: las librerías de C que necesitan `sf`, `terra`, `arrow` y `curl`. |
| `r-lib/actions/setup-r@v2` | Instala **R 4.3.3**, la misma versión que `renv.lock`. Con `use-public-rspm: true` usa paquetes **precompilados** de Posit Package Manager para Ubuntu 24.04: sin eso habría que compilar `arrow`, `sf` o `terra` desde el código fuente, y cada ejecución tardaría mucho más. |
| `r-lib/actions/setup-renv@v2` | Ejecuta `renv::restore()` para instalar las versiones exactas del lockfile, y guarda la librería en caché: si `renv.lock` no cambia, la siguiente ejecución la reutiliza. |
| Ejecutar tests | `testthat::test_dir("tests/testthat", stop_on_failure = TRUE)`: si falla una comprobación, el proceso termina con error y el commit queda en rojo. |

Una ejecución completa tarda unos 2 minutos.

**Despliegue** solo se ejecuta en un push a `main` y solo si **Tests** ha pasado (`needs: tests`). Antes de nada comprueba si existen los secretos del repositorio:

```yaml
- name: Comprobar credenciales
  id: credenciales
  env:
    SHINYAPPS_TOKEN: ${{ secrets.SHINYAPPS_TOKEN }}
    SHINYAPPS_SECRET: ${{ secrets.SHINYAPPS_SECRET }}
  run: |
    if [ -n "$SHINYAPPS_TOKEN" ] && [ -n "$SHINYAPPS_SECRET" ]; then
      echo "disponibles=true" >> "$GITHUB_OUTPUT"
    else
      echo "::notice::Sin secretos SHINYAPPS_TOKEN/SHINYAPPS_SECRET: se omite el despliegue."
    fi
```

El resto de pasos llevan `if: steps.credenciales.outputs.disponibles == 'true'`. Este rodeo es necesario porque GitHub no permite usar `secrets` directamente en un `if`. Sin secretos, el job termina en verde sin desplegar nada; con ellos, configura la cuenta con `rsconnect::setAccountInfo()` y ejecuta `scripts/deploy.R`. `concurrency` impide que dos push seguidos lancen dos despliegues a la vez.

### Leer un fallo

En *Actions*, entra en la ejecución con la cruz roja, después en el job y despliega el paso marcado en rojo:

- **Falla "Ejecutar tests"**: el final del log indica qué `test_that` ha fallado, en qué línea y qué valor esperaba frente al obtenido. Reprodúcelo en local con `testthat::test_file()` sobre ese fichero.
- **Falla `setup-renv`**: no se ha podido instalar algún paquete. El resumen final (`The following package(s) were not installed successfully`) lista cada paquete con su motivo; el que importa es el que no dice `dependency failed`, porque los demás caen en cadena.

### Reproducir el CI en local

En tu ordenador, `renv` reutiliza su caché y no ve los problemas que aparecen al instalar desde cero. Para repetir en local lo que hace GitHub, restaura sobre una librería vacía, fuera del proyecto, sin caché y con los mismos binarios:

```bash
RENV_PATHS_LIBRARY=/tmp/libreria-ci \
RENV_CONFIG_CACHE_ENABLED=FALSE \
RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest" \
Rscript -e 'renv::restore(prompt = FALSE)'

RENV_PATHS_LIBRARY=/tmp/libreria-ci Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
```

Es fiel si tu sistema es Ubuntu 24.04 con R 4.3.3, como el de GitHub. La librería tiene que estar fuera de la carpeta del proyecto: si está dentro, `renv` lee también el código de los paquetes instalados al buscar dependencias y da avisos falsos.

### Dos problemas que aparecieron al montarlo {#problemas-ci}

Ninguno se veía en local, porque los paquetes salían de la caché de `renv`. Los dos rompían la instalación desde cero, que es lo que hace GitHub en cada ejecución nueva.

1. **Entradas `null` en `renv.lock`.** Nueve paquetes (`rstudioapi`, `rsconnect`, `httr2`…) tenían un `null` en su lista de dependencias. `renv` lo interpretaba como un paquete por descargar (`[NULL]: failed to download`) y, al fallar, deshacía toda la instalación. Se corrigió quitando esas entradas del lockfile, sin cambiar ninguna versión.
2. **Bug de `renv` 1.2.3 con `curl`.** Al instalar desde cero, `renv` 1.2.3 asignaba a `curl` las dependencias del propio proyecto (las de su `DESCRIPTION`). Como `plotly` depende de `curl` a través de `httr`, se formaba un ciclo y `renv` dejaba sin instalar `curl`, `httr`, `httr2`, `plotly`, `rsconnect` y `snowflakeauth`: todos aparecían como `dependency failed` sin ningún error real. Se localizó interceptando la función interna que genera ese mensaje para ver qué dependencias había calculado para cada paquete, y se corrigió actualizando a `renv` 1.3.0 (`renv::upgrade()`), que no tiene el fallo.

La lección para el futuro: **antes de dar por bueno un cambio en `renv.lock`, prueba una restauración desde cero** con el comando de arriba.
