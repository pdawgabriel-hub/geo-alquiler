# Rendimiento

La app está pensada para cargar rápido también en el móvil y con conexiones lentas. La regla general es hacer el trabajo pesado en el servidor y mandar al navegador solo lo que se va a pintar.

| Optimización | Qué resuelve |
|---|---|
| **Gráficos con `plotly` nativo (no `ggplotly()`)** | Todos los gráficos interactivos se construyen con `plot_ly()`/`add_trace()` en vez de convertir un `ggplot2` con `ggplotly()`, que genera un JSON notablemente más pesado para el mismo gráfico. |
| **Histogramas pre-agregados en el servidor** | Los bins se calculan en R con `hist()` y se envían solo las barras, en vez de cada precio en crudo para que Plotly los agrupe en el navegador. |
| **Submuestreo en gráficos densos** | El scatter de precio/superficie y los boxplots de Estadística Avanzada limitan los puntos que viajan al navegador (muestra aleatoria con un aviso visible) cuando el conjunto filtrado es muy grande. |
| **Mapa agregado por barrio** | La capa por defecto del Panel Principal manda un resumen por barrio (precio medio + nº de inmuebles), no cada inmueble. Los pines individuales y el mapa de calor se cargan bajo demanda (`leafletProxy`) solo si se activa esa capa. |
| **Clustering de marcadores** | El mapa de Oportunidades agrupa sus marcadores (`markerClusterOptions`) para que un umbral poco restrictivo no sature el navegador. |
| **CSS responsive** (`inst/app/www/custom.css`) | Ajusta las alturas de Leaflet/Plotly (fijas en píxeles por defecto), el control de capas y los controles de `DT` a cada ancho de pantalla, con `scrollX` en todas las tablas. |
| **JS mínimo** (`inst/app/www/custom.js`) | Cierra el menú lateral al navegar en pantallas estrechas, y recolorea el mapa del Observatorio (ver abajo). |
| **Mapas base sin clave de API** | OpenStreetMap como capa base por defecto (Positron/DarkMatter de CartoDB exigen ahora API key). |

## Observatorio: cómo carga ~8.200 polígonos {#observatorio}

| Técnica | Detalle |
|---|---|
| **Dos niveles de detalle** | La vista nacional usa la geometría simplificada a ~1,5 km (a zoom 5-6 un píxel ya son ~2 km): ~90.000 vértices en vez de ~260.000. Al elegir una provincia se usa la de ~250 m. |
| **Canvas en vez de SVG** | `leafletOptions(preferCanvas = TRUE)`: miles de polígonos en SVG son muy lentos de dibujar. |
| **JSON de geometría generado a mano** | `addPolygons()` + `jsonlite` tarda ~6 s en convertir los polígonos al JSON de Leaflet, porque construye cientos de miles de listas anidadas. `geometria_a_json_leaflet()` genera el mismo JSON directamente desde `st_coordinates()` con operaciones vectorizadas, en ~1,4 s. Se marca con clase `json` para que shiny y htmlwidgets lo inserten sin volver a serializarlo. Un test comprueba que es idéntico al de Leaflet. |
| **Caché por proceso** | `cargar_observatorio()` lee el parquet y lo convierte a `sf` una sola vez por proceso (en shinyapps.io un proceso atiende muchas sesiones), y la geometría serializada se cachea por ámbito dentro de ese objeto. |
| **Los polígonos van con el mapa** | El primer render del mapa ya incluye los polígonos, sin esperar a que el navegador avise de que el mapa existe. Los cambios de ámbito posteriores van por `leafletProxy`: volver a renderizar el widget lo destruiría con un redibujado de canvas pendiente y Leaflet daría un error (`clearRect`). |
| **Recolorear en el navegador** | Cambiar de indicador no cambia la forma de los municipios. Un manejador JS (`observatorio_recolorear` en `custom.js`) busca cada polígono por su código INE y cambia su color y su etiqueta: ~200 KB en vez de reenviar toda la geometría. El resaltado de Leaflet solo restaura el borde en `mouseout`, así que el nuevo relleno se mantiene. |
| **El mapa primero, el resto después** | Shiny envía juntas todas las salidas de un ciclo y no pinta ninguna hasta cargar las librerías de todas; la primera vez eso incluye `plotly.js` (~3,5 MB). El gráfico y el ranking esperan a `input$mapa_pintado`, que el navegador envía (`htmlwidgets::onRender` + dos `requestAnimationFrame`) cuando el mapa ya está en pantalla. |
| **Clics del gráfico sin `event_data()`** | Se lee directamente el input `plotly_click-<source>`: `event_data()` emitía en cada sesión un aviso diferido de "evento no registrado" que no se puede silenciar. |

Resultado medido en local con Chromium: el mapa nacional aparece a ~1,2 s de abrir la pestaña (antes ~3,2 s), y a ~2,6 s la primera vez tras arrancar el servidor (antes ~9,8 s).

El código de los canales con el navegador (mensaje propio, input propio y `leafletProxy`) está explicado en [Recorrido por el código](codigo.md#navegador).
