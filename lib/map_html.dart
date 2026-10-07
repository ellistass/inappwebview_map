const String kMapHtml = r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>html, body, #map { height: 100%; margin: 0; padding: 0; }</style>
</head>
<body>
  <div id="map"></div>
  <script>
    const map = L.map('map').setView([6.5244, 3.3792], 12); // Lagos
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);

    const markers = L.layerGroup().addTo(map);

    function send(name, ...args) {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler(name, ...args);
      }
    }

    // JS -> Flutter
    map.on('click', (e) => send('onMapTap', e.latlng.lat, e.latlng.lng));

    // Flutter -> JS
    window.addMarker = (lat, lng, label) =>
      L.marker([lat, lng]).addTo(markers).bindPopup(label || '').openPopup();
    window.flyTo = (lat, lng, zoom) => map.flyTo([lat, lng], zoom || 14);
    window.clearMarkers = () => markers.clearLayers();
  </script>
</body>
</html>
''';
