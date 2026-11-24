# Arquitectura

![Esquema de la arquitectura de GeoAlquiler: la ingesta offline genera dos ficheros Parquet; la app Shiny los carga en app_server.R, que reparte datos visibles, filtrados o completos a cada módulo, y el Observatorio carga su propio fichero una vez por proceso; el navegador recibe widgets ya preparados y devuelve clics, filtros y encuadre como eventos.](img/arquitectura.svg)

La app se organiza en tres capas que no se mezclan:

1. **Ingesta offline** (`scripts/ingesta/`): descarga, limpia y cruza las fuentes. Se ejecuta a mano y produce dos ficheros Parquet que viajan con el paquete. La app nunca descarga nada en tiempo de ejecución. Detalle en [Pipeline de datos](datos.md).
2. **Lógica de negocio sin Shiny** (`R/fct_*.R`): funciones puras, sin `input`, `output` ni reactividad, que usan tanto el pipeline como la app y se prueban directamente con `testthat`.
3. **Interfaz reactiva por módulos** (`R/mod_*.R`): cada pantalla es un módulo; `app_ui.R` y `app_server.R` solo los ensamblan.

## Flujo de datos dentro de la app {#flujo-datos}

`app_server.R` carga los dos ficheros Parquet y decide qué versión de los datos recibe cada módulo. Es la decisión de diseño central de la app:

```
alquileres.parquet ──► datos_totales ──► mod_filtros ──► datos filtrados ──► mod_mapa ──► datos_visibles
                            │                                  │                              │
                            │                                  └─► Recomendador KNN           └─► Tabla, Analítica, Estadística,
                            └─► Comparador, Predicción,                                           Oportunidades, Calculadora,
                                Barrios, Favoritos                                                Informe, Exportar

observatorio_municipios.parquet ──► cargar_observatorio() (una vez por proceso) ──► mod_observatorio
```

| El módulo recibe… | Módulos | Por qué |
|---|---|---|
| `datos_visibles`: filtros + lo que se ve en el mapa del Panel Principal | Tabla, Analítica, Estadística, Oportunidades, Calculadora, Informe, Exportar | Responden a "lo que estoy mirando ahora" |
| Datos filtrados, sin recorte del mapa | Recomendador KNN | Buscar similares solo en el encuadre daría muy pocos candidatos |
| Dataset completo (`datos_totales`) | Comparador, Predicción, Barrios, Favoritos | Necesitan todo el mercado: entrenar el modelo, comparar ciudades, no perder favoritos al filtrar |
| Su propio dataset | Observatorio | Datos oficiales agregados por municipio, independientes de los filtros |

Detalles que conviene conocer:

- **`mod_mapa` devuelve los datos del encuadre visible.** Filtra por `input$mapa_alquiler_bounds`. Un redimensionado del mapa (rotar el móvil, abrir el menú) puede hacer que Leaflet informe un momento de un encuadre inválido; en ese caso se devuelven todos los datos en vez de vaciar las siete pantallas que dependen de `datos_visibles`.
- **Favoritos** se guardan en un `reactiveVal` (`favoritos_ids`) creado en `app_server.R` y compartido entre `mod_tabla` (donde se marcan) y `mod_favoritos` (donde se gestionan). Viven solo durante la sesión.
- **El Observatorio no depende de los filtros globales.** Tiene sus propios controles (indicador, ámbito, población mínima) y su propio estado de municipio seleccionado, que sincroniza mapa, ficha, gráfico y ranking.

Cómo se ve todo esto en el código, con fragmentos reales: [Recorrido por el código](codigo.md).
