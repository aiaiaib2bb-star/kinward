import '@fontsource-variable/vazirmatn';
import '@fontsource/fredoka/latin-400.css';
import '@fontsource/fredoka/latin-500.css';
import '@fontsource/fredoka/latin-600.css';
import '@fontsource/fredoka/latin-700.css';
import './styles/base.css';
import './styles/ui.css';
import './styles/cards.css';
import './styles/cosmetics.css';
import './styles/game.css';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { sfx } from './audio/sfx';
import { net, start } from './net/socket';
import { app } from './state/app';
import { settings } from './state/settings';
import { mesh, voice } from './voice/mesh';

// A handle for automated tests and curious players; it holds nothing secret.
(window as unknown as { __hokm: unknown }).__hokm = { app, net, settings, voice, mesh };

// Browsers keep audio locked until a touch; open it on every touch until it's running.
window.addEventListener('pointerdown', () => sfx.unlock(), { passive: true });

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

start();

if ('serviceWorker' in navigator && import.meta.env.PROD) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  });
}
