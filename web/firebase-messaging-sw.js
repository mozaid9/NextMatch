/* Firebase Cloud Messaging service worker — handles background pushes on
 * web. Config values are the public web app config (not secrets). */
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBmcYuuqbxHKSPPlNhYzrTLViLkUPtPz_g',
  appId: '1:562392184918:web:587b361e90d5d1aad3e3f7',
  messagingSenderId: '562392184918',
  projectId: 'nextmatch-eb038',
  authDomain: 'nextmatch-eb038.firebaseapp.com',
  storageBucket: 'nextmatch-eb038.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(notification.title || 'NextMatch', {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return clients.openWindow('/');
    }),
  );
});
