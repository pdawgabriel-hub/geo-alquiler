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
