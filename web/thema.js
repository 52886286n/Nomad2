// Dunkles Design ist Standard; die Wahl wird als Cookie gespeichert und gilt für Startseite, Videos und Wikis.
(function () {
  var hell = /(?:^|; )nomad_thema=hell/.test(document.cookie);
  var w = document.documentElement;
  function anwenden() {
    w.classList.toggle('nomad-dunkel', !hell);
    w.dataset.thema = hell ? 'hell' : 'dunkel';
  }
  anwenden();
  window.nomadThema = {
    istHell: function () { return hell; },
    wechseln: function () {
      hell = !hell;
      document.cookie = 'nomad_thema=' + (hell ? 'hell' : 'dunkel') + '; path=/; max-age=31536000; SameSite=Lax';
      anwenden();
      return hell;
    }
  };
  document.addEventListener('DOMContentLoaded', function () {
    var k = document.getElementById('thema');
    if (!k) return;
    function text() { k.textContent = hell ? '🌙 Dunkel' : '☀️ Hell'; }
    text();
    k.onclick = function () { window.nomadThema.wechseln(); text(); };
  });
})();
