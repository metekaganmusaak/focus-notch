// The only bridge between the pages and the app; pages have no Node access.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('focusNotch', {
  i18n: () => ipcRenderer.sendSync('get-i18n'),
  getState: () => ipcRenderer.invoke('get-state'),
  onState: (callback) => ipcRenderer.on('state', (_event, state) => callback(state)),
  onPlaySound: (callback) => ipcRenderer.on('play-sound', (_event, url) => callback(url)),
  onDebug: (callback) => ipcRenderer.on('debug', (_event, options) => callback(options)),
  onPeek: (callback) => ipcRenderer.on('peek', () => callback()),
  action: (name, argument) => ipcRenderer.send('action', name, argument),
  setSetting: (key, value) => ipcRenderer.send('set-setting', key, value),
  setInteractive: (interactive) => ipcRenderer.send('set-interactive', interactive),
  setKeyboard: (wanted) => ipcRenderer.send('keyboard', wanted),
  dragNotch: (deltaX) => ipcRenderer.send('drag-notch', deltaX),
  addPet: (name, gifs) => ipcRenderer.invoke('add-pet', name, gifs),
  setLoginItem: (enabled) => ipcRenderer.send('set-login-item', enabled),
});
