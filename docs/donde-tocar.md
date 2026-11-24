# Dónde tocar para…

| Quiero… | Cambiar | No hace falta tocar |
|---|---|---|
| Añadir o actualizar una ciudad | `scripts/ingesta/00_config.R` (y `data/raw/anclas_manuales.csv` si no hay fuente oficial); regenerar los datos | La app |
| Añadir un indicador al Observatorio | La columna en `09_observatorio.R` si viene de una fuente nueva; `calcular_indicadores_observatorio()`, `indicadores_observatorio()` y `motivo_sin_dato()` en `R/fct_observatorio.R` | El módulo: selector, leyenda, ficha y ranking salen del catálogo |
| Cambiar el año del Observatorio | `ANIO_OBSERVATORIO` en `00_config.R`, y la URL de SERPAVI en `09_observatorio.R` si el Ministerio publica una capa nueva | La app |
| Corregir el cruce de un municipio del Catastro | `EQUIVALENCIAS_CATASTRO` en `09_observatorio.R` | — |
| Añadir una pantalla nueva | Un `R/mod_nuevo.R`; registrarlo en `app_ui.R` (menú + `tabItem`) y en `app_server.R`, decidiendo qué dataset recibe | El resto de módulos |
| Cambiar un cálculo de negocio | La función en `R/fct_calculos.R` (o `fct_observatorio.R`) y su test en `tests/testthat/` | El módulo, que solo llama a la función |
| Añadir un fichero de datos a la app | `inst/app/data/` y la lista de `scripts/deploy.R` | — |
| Cambiar esta guía | El `.md` de la página en `docs/`; si es una página nueva, añadirla también al `nav` de `mkdocs.yml` | La app: el CI de R no se lanza por cambios en `docs/` |
| Añadir una imagen a la guía o al README | `docs/img/` (capturas en `docs/img/capturas/`) y enlazarla desde la página | — |
