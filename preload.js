const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('windowControls', {
  close:    () => ipcRenderer.send('window-close'),
  minimize: () => ipcRenderer.send('window-minimize'),
  maximize: () => ipcRenderer.send('window-maximize'),
});

contextBridge.exposeInMainWorld('appControls', {
  isFirstRun:   () => ipcRenderer.invoke('get-first-run'),
  getAutoStart:  () => ipcRenderer.invoke('get-autostart'),
  setAutoStart:  (v) => ipcRenderer.invoke('set-autostart', v),
  finishSetup:   () => ipcRenderer.invoke('finish-setup'),
});
