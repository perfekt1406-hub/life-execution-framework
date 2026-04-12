delete process.env.ELECTRON_RUN_AS_NODE;

const { app, BrowserWindow, Menu, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

const DAY_START_HOUR = 3;
const DAY_START_MIN = 30;

function getStatePath(name) {
  const dir = path.join(app.getPath('userData'), 'state');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, name);
}

function getLogicalDate() {
  const now = new Date();
  if (
    now.getHours() < DAY_START_HOUR ||
    (now.getHours() === DAY_START_HOUR && now.getMinutes() < DAY_START_MIN)
  ) {
    return new Date(now.getTime() - 86400000).toISOString().slice(0, 10);
  }
  return now.toISOString().slice(0, 10);
}

function wasOpenedToday() {
  try {
    return fs.readFileSync(getStatePath('last-open'), 'utf8').trim() === getLogicalDate();
  } catch {
    return false;
  }
}

function stampToday() {
  fs.writeFileSync(getStatePath('last-open'), getLogicalDate());
}

function isFirstRun() {
  return !fs.existsSync(getStatePath('setup-done'));
}

function markSetupDone() {
  fs.writeFileSync(getStatePath('setup-done'), '1');
}

function getLauncher() {
  const AutoLaunch = require('auto-launch');
  return new AutoLaunch({
    name: 'Life Execution Framework',
    path: app.getPath('exe'),
    args: ['--autostart'],
  });
}

const isAutoStart = process.argv.includes('--autostart');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 860,
    frame: false,
    title: 'Life Execution Framework',
    backgroundColor: '#0e0e0e',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  mainWindow.loadFile('life-framework.html');
  stampToday();

  ipcMain.on('window-close',    () => mainWindow && mainWindow.close());
  ipcMain.on('window-minimize', () => mainWindow && mainWindow.minimize());
  ipcMain.on('window-maximize', () => mainWindow && (mainWindow.isMaximized() ? mainWindow.unmaximize() : mainWindow.maximize()));

  ipcMain.handle('get-first-run', () => isFirstRun());

  ipcMain.handle('get-autostart', async () => {
    try { return await getLauncher().isEnabled(); }
    catch { return false; }
  });

  ipcMain.handle('set-autostart', async (_e, enabled) => {
    const launcher = getLauncher();
    try {
      if (enabled) await launcher.enable();
      else await launcher.disable();
      return true;
    } catch (err) {
      console.error('Auto-launch toggle failed:', err);
      return false;
    }
  });

  ipcMain.handle('finish-setup', () => {
    markSetupDone();
    return true;
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  Menu.setApplicationMenu(null);
  if (isAutoStart && wasOpenedToday()) {
    app.quit();
    return;
  }

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  app.quit();
});
