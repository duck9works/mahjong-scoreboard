'use strict';

// Legacy service worker cleanup script.
// This is served at the same path used by old Flutter web builds so that
// previously-registered workers can update to this script, clear caches,
// and unregister themselves.
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(Promise.resolve());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const names = await caches.keys();
      await Promise.all(names.map((name) => caches.delete(name)));
    } catch (_) {
      // Ignore cache cleanup failures and continue unregister flow.
    }

    await self.registration.unregister();

    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    await Promise.all(
      clients.map((client) => client.navigate(client.url)),
    );
  })());
});
