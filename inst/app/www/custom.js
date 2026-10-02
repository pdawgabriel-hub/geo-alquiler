// En móvil, el sidebar de shinydashboard se abre como una capa superpuesta
// (clase "sidebar-open" en <body>) pero no se cierra sola al elegir una
// pestaña -- se queda tapando el contenido hasta que el usuario la cierra a
// mano. Se cierra automáticamente al navegar a cualquier pestaña real
// (enlaces con data-toggle="tab"), sin afectar a los que solo despliegan un
// submenú.
document.addEventListener('click', function (event) {
  var link = event.target.closest('.sidebar-menu a[data-toggle="tab"]');
  if (link) {
    document.body.classList.remove('sidebar-open');
  }
});

// Observatorio del Alquiler: al cambiar de indicador solo cambian el color y
// la etiqueta de cada municipio, no su forma. En vez de volver a mandar desde
// el servidor ~8.000 polígonos (varios MB), se recolorean en el navegador los
// que ya están pintados, buscándolos por su layerId (código INE).
// leaflet restaura en "mouseout" solo las propiedades del resaltado (borde),
// así que el nuevo relleno se mantiene al pasar el ratón por encima.
if (window.Shiny) {
  Shiny.addCustomMessageHandler('observatorio_recolorear', function (msg) {
    var widget = window.HTMLWidgets && HTMLWidgets.find('#' + msg.mapa);
    var mapa = widget && widget.getMap && widget.getMap();
    if (!mapa || !mapa.layerManager) return;
    for (var i = 0; i < msg.ids.length; i++) {
      var capa = mapa.layerManager.getLayer('shape', msg.ids[i]);
      if (!capa) continue;
      var sinDato = msg.valores[i] === msg.sin_dato;
      capa.setStyle({ fillColor: msg.colores[i], fillOpacity: sinDato ? 0.35 : 0.8 });
      // La etiqueta es "Municipio (Provincia) — valor": se conserva el
      // nombre y se sustituye solo el valor, para no reenviar los nombres.
      var tooltip = capa.getTooltip();
      if (tooltip) {
        var texto = String(tooltip.getContent());
        var corte = texto.lastIndexOf(msg.separador);
        var nombre = corte >= 0 ? texto.slice(0, corte) : texto;
        capa.setTooltipContent(nombre + msg.separador + msg.valores[i]);
      }
    }
  });
}
