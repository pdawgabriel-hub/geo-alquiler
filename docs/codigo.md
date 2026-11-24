# Recorrido por el código

Esta página recorre los patrones que se repiten en el código, con fragmentos reales del repositorio. Si entiendes estos cinco, puedes leer cualquier fichero de `R/`.

## Un módulo: interfaz por un lado, servidor por otro

Cada pantalla es un par de funciones en su `mod_*.R`. La de interfaz (`*UI(id)`) construye los controles con `NS(id)`, que antepone el identificador del módulo a cada `inputId` para que dos módulos puedan tener un control llamado igual sin pisarse. La de servidor (`*Server(id, ...)`) recibe los datos ya preparados como argumento y no sabe de dónde vienen:

```r
oportunidadesServer <- function(id, datos_visibles) {
  moduleServer(id, function(input, output, session) {
    df_oportunidades <- reactive({
      detectar_oportunidades(datos_visibles(), input$pct_descuento)
    })
    # ... KPIs, mapa y tabla a partir de df_oportunidades()
  })
}
```

`datos_visibles` es un `reactive`: el módulo lo llama como función (`datos_visibles()`) y Shiny vuelve a calcular `df_oportunidades` cada vez que cambian los filtros, el encuadre del mapa o el umbral.

## Separar el cálculo de la reactividad

La regla del proyecto: **un módulo lee inputs, llama a una función y pinta el resultado**. El cálculo vive en una función pura de `R/fct_calculos.R` o `R/fct_observatorio.R`, sin `input`, `output` ni `reactive`. Así se puede probar con valores concretos, sin levantar un servidor.

La Calculadora es el ejemplo más claro. Toda su lógica financiera (cuota hipotecaria, amortización mes a mes, proyección a N años) está en `simular_inversion()`, y el módulo solo traduce los inputs, que llegan en porcentaje, a tanto por uno:

```r
simulacion <- reactive({
  simular_inversion(
    precio = req(input$precio_compra),
    alquiler_mensual = req(input$alquiler_mensual),
    gastos_anuales = req(input$gastos_mantenimiento),
    pct_entrada = req(input$porcentaje_entrada) / 100,
    tin = req(input$interes_hipoteca) / 100,
    anos = as.numeric(req(input$plazo_anos)),
    inc_alquiler = req(input$incremento_alquiler) / 100,
    aprec_inmueble = req(input$apreciacion_inmueble) / 100
  )
})
```

`req()` detiene el cálculo en silencio mientras un input esté vacío, en vez de propagar un error a la pantalla.

## `app_server.R`: el único sitio que sabe qué datos recibe cada módulo

`app_server.R` no contiene lógica: carga los datos, encadena filtros y mapa, y reparte. Leyendo estas líneas se ve el flujo completo descrito en [Flujo de datos dentro de la app](arquitectura.md#flujo-datos):

```r
datos_filtrados_sidebar <- filtrosServer("filtros_sidebar", datos_totales)
datos_visibles <- mapaServer("mapa_principal", datos_filtrados_sidebar)

tablaServer("tabla_principal", datos_visibles, favoritos_ids)
oportunidadesServer("oportunidades_principal", datos_visibles)
recomendadorServer("recomendador_principal", datos_filtrados_sidebar)
prediccionServer("prediccion_principal", datos_totales)
observatorioServer("observatorio_principal", datos_observatorio)
# ...
```

`mapaServer()` es a la vez un módulo y un filtro: pinta el mapa y **devuelve** un `reactive` con los inmuebles del encuadre visible, que es lo que reciben las pantallas que dependen de "lo que estoy mirando". El estado que comparten varios módulos (los favoritos) se crea aquí con `reactiveVal()` y se pasa a los que lo necesitan.

## Hablar con el navegador sin reenviar todo {#navegador}

Shiny actualiza una salida mandando su contenido completo. Para el mapa del Observatorio (~8.200 polígonos) eso es demasiado, así que hay tres canales directos con el navegador:

**Servidor → navegador, con un mensaje propio.** Al cambiar de indicador, el servidor no vuelve a pintar el mapa: manda solo los colores y los valores nuevos, identificados por código INE.

```r
session$sendCustomMessage("observatorio_recolorear", list(
  mapa = ns("mapa"), ids = df$cod_ine, colores = est$colores,
  valores = est$valores_txt, sin_dato = formatear_indicador(NA, input$indicador),
  separador = SEP_ETIQUETA
))
```

Y `inst/app/www/custom.js` lo recibe y recolorea los polígonos que ya están dibujados (versión simplificada):

```js
Shiny.addCustomMessageHandler('observatorio_recolorear', function (msg) {
  var mapa = HTMLWidgets.find('#' + msg.mapa).getMap();
  for (var i = 0; i < msg.ids.length; i++) {
    var capa = mapa.layerManager.getLayer('shape', msg.ids[i]);
    if (!capa) continue;
    capa.setStyle({ fillColor: msg.colores[i], fillOpacity: msg.valores[i] === msg.sin_dato ? 0.35 : 0.8 });
    // ... y actualiza la etiqueta conservando el nombre del municipio
  }
});
```

**Navegador → servidor, con un input propio.** Para mandar el gráfico y el ranking solo cuando el mapa ya se ve, el navegador avisa con `Shiny.setInputValue()`, que en el servidor aparece como un input más (`input$mapa_pintado`):

```r
htmlwidgets::onRender("
  function(el) {
    requestAnimationFrame(function() {
      requestAnimationFrame(function() {
        Shiny.setInputValue(el.id + '_pintado', true);
      });
    });
  }")
```

El gráfico y el ranking empiezan con `req(input$mapa_pintado)`, así que no se calculan hasta ese momento.

**Leaflet por proxy.** Cambiar de provincia sustituye los polígonos con `leafletProxy("mapa")`, que manda órdenes al mapa existente (`clearShapes()`, añadir polígonos, encuadrar) en vez de recrearlo.

Qué se gana con cada una de estas técnicas, con tiempos medidos: [Rendimiento](rendimiento.md#observatorio).

## El pipeline: fallar pronto y con un mensaje útil

Cada fuente del pipeline tiene una función de descarga (con caché) y otra de lectura. La de lectura comprueba primero que el fichero tiene la forma esperada y, si no, se detiene diciendo qué ha encontrado. Así un cambio de formato en una web del Ministerio no acaba en un dataset mal interpretado:

```r
esperadas <- c("CodINE", "CPRO", "LITPRO", "NAMEUNIT", "Num_VC", "Renta_Medi", ...)
faltan <- setdiff(esperadas, names(x))
if (length(faltan) > 0) {
  stop("[SERPAVI] Faltan columnas esperadas en el shapefile: ", paste(faltan, collapse = ", "),
       ". Columnas encontradas: ", paste(names(x), collapse = ", "))
}
```

Los cálculos que comparten pipeline y app (indicadores del Observatorio, normalización de nombres) están en `R/fct_observatorio.R`, y el pipeline los carga con `source()`. Así una misma función no puede dar un resultado al generar los datos y otro distinto al mostrarlos. El pipeline completo se explica en [Pipeline de datos](datos.md).
