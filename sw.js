// ============================================================================
// PlanB Tools — Service Worker
// Phase 0 Notifications iOS Web Push (16/05/2026)
//
// Ce SW remplace l'ancien SW inline (blob URL) qui était embarqué dans
// index.html. Il doit être servi depuis la racine du site (/sw.js) pour que
// son scope couvre toutes les sous-pages (taf/, production/, receptions/…).
//
// Rôles :
//   1. Cache offline minimal (comme avant)
//   2. Réception des notifications Push (Apple Push Notification service)
//   3. Gestion du clic sur la notification (focus tab existante OU ouvre l'app)
// ============================================================================

const CACHE_NAME = 'planb-tools-v14';   // bump à chaque mise à jour du SW (v14 : scanner barre SHOOT fixe + cadrage paysage + reset bouton PDF 01/06/2026)
const PRECACHE_URLS = ['/', '/index.html', '/manifest.json'];


// ----------------------------------------------------------------------------
// Install : précharge les ressources critiques
// ----------------------------------------------------------------------------
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => cache.addAll(PRECACHE_URLS))
            .then(() => self.skipWaiting())   // active la nouvelle version dès install
    );
});


// ----------------------------------------------------------------------------
// Activate : nettoie les anciens caches
// ----------------------------------------------------------------------------
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) => Promise.all(
            keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
        )).then(() => self.clients.claim())
    );
});


// ----------------------------------------------------------------------------
// Fetch : cache-first puis network fallback
// ----------------------------------------------------------------------------
self.addEventListener('fetch', (event) => {
    // On ne cache que les GET du même origin
    if (event.request.method !== 'GET') return;

    event.respondWith(
        caches.match(event.request).then((cached) => cached || fetch(event.request))
    );
});


// ----------------------------------------------------------------------------
// Push : reçoit une notification depuis Apple Push Notification service
//
// Payload attendu côté serveur (edge function send-push) :
// {
//   title:   "Températures matin Freddy",
//   body:    "Aucun relevé enregistré. Pense à passer au frigo.",
//   url:     "/temperatures/",            // page à ouvrir au clic
//   tag:     "temp_matin_freddy",         // dedup : remplace la précédente
//   icon:    "/icons/icon-192.png",       // (optionnel)
//   badge:   "/icons/badge-72.png"        // (optionnel)
// }
// ----------------------------------------------------------------------------
self.addEventListener('push', (event) => {
    let data = {};
    try {
        data = event.data ? event.data.json() : {};
    } catch (e) {
        data = { title: 'PlanB Tools', body: event.data ? event.data.text() : '' };
    }

    const title = data.title || 'PlanB Tools';
    const options = {
        body:        data.body || '',
        tag:         data.tag || 'planb-default',
        renotify:    true,                                 // re-notifie même si tag existe déjà
        icon:        data.icon  || '/manifest-icon-192.png',
        badge:       data.badge || '/manifest-icon-192.png',
        data: {
            url: data.url || '/',
            sentAt: Date.now()
        },
        requireInteraction: data.requireInteraction || false
    };

    event.waitUntil(self.registration.showNotification(title, options));
});


// ----------------------------------------------------------------------------
// Notification click : focus tab existante ou ouvre l'URL ciblée
// ----------------------------------------------------------------------------
self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const targetUrl = (event.notification.data && event.notification.data.url) || '/';

    event.waitUntil(
        self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
            // Si une tab PBT est déjà ouverte, la focusser et naviguer
            for (const client of clientList) {
                if ('focus' in client) {
                    return client.focus().then(() => {
                        if ('navigate' in client) return client.navigate(targetUrl);
                    });
                }
            }
            // Sinon ouvrir une nouvelle fenêtre
            if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
        })
    );
});


// ----------------------------------------------------------------------------
// Subscription change : Apple a rotation l'endpoint, on doit re-subscribe
// (Phase 4 : implémentation complète — pour Phase 0 on log juste)
// ----------------------------------------------------------------------------
self.addEventListener('pushsubscriptionchange', (event) => {
    // TODO Phase 4 : ré-abonner avec applicationServerKey + PATCH push_subscriptions
    console.warn('[PBT-SW] pushsubscriptionchange — re-subscribe à implémenter en Phase 4');
});
