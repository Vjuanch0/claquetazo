// Service worker: deja la app funcionar sin internet.
// Si cambias index.html y no ves el cambio, sube el número de VERSION.
const VERSION = 'claquetazo-v5';
const BASE = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'favicon.svg', 'apple-touch-icon.png', 'img/logo-720.webp', 'img/logo-1200.webp'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(BASE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  // Los datos y las fotos de Supabase siempre se piden a internet. La app guarda su propia copia.
  if (url.hostname.endsWith('.supabase.co')) return;
  const guardar = r => { if (r && (r.ok || r.type === 'opaque')) { const copia = r.clone(); caches.open(VERSION).then(c => c.put(e.request, copia)); } return r; };
  if (e.request.mode === 'navigate') {
    // La página: primero internet (para recibir cambios), si no hay, la copia guardada.
    e.respondWith(fetch(e.request).then(guardar).catch(() => caches.match('index.html')));
  } else {
    // Lo demás (tipografías, librerías, íconos): primero la copia guardada.
    e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(guardar)));
  }
});
