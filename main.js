/**
 * Electron main process: window lifecycle, IPC, Linux autostart .desktop, logical-day state.
 */
delete process.env.ELECTRON_RUN_AS_NODE;

const { app, BrowserWindow, Menu, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

const DAY_START_HOUR = 3;
const DAY_START_MIN = 30;

/**
 * Resolves the directory for persisted state files. Input: file base name. Output: absolute path under userData/state or state-dev.
 */
function getStatePath(name) {
  const suffix = app.isPackaged ? '' : '-dev';
  const dir = path.join(app.getPath('userData'), `state${suffix}`);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, name);
}

/**
 * Formats a Date as YYYY-MM-DD in the local timezone (not UTC).
 * Must match install.sh logical day; UTC dates caused "already opened" across calendar days.
 * Input: Date. Output: "YYYY-MM-DD" string.
 */
function formatLocalDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * Logical workbook day: calendar date in local time, with day starting at DAY_START_HOUR:DAY_START_MIN.
 * Output: "YYYY-MM-DD" string for comparison with last-open stamp.
 */
function getLogicalDate() {
  const now = new Date();
  if (
    now.getHours() < DAY_START_HOUR ||
    (now.getHours() === DAY_START_HOUR && now.getMinutes() < DAY_START_MIN)
  ) {
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    return formatLocalDate(yesterday);
  }
  return formatLocalDate(now);
}

/**
 * Writes current logical date to last-open. Input: none. Output: none.
 */
function stampToday() {
  fs.writeFileSync(getStatePath('last-open'), getLogicalDate());
}

/**
 * First-run onboarding not completed. Input: none. Output: boolean.
 */
function isFirstRun() {
  return !fs.existsSync(getStatePath('setup-done'));
}

/**
 * Marks onboarding complete. Input: none. Output: none.
 */
function markSetupDone() {
  fs.writeFileSync(getStatePath('setup-done'), '1');
}

/**
 * XDG autostart desktop file path for Linux. Input: none. Output: absolute path string.
 */
function getLinuxDesktopPath() {
  return path.join(app.getPath('home'), '.config', 'autostart', 'life-execution-framework.desktop');
}

/**
 * Escapes one argument for the XDG Desktop Entry Exec line (quotes, backslashes).
 * Input: path or string. Output: quoted string safe for Exec=.
 */
function quoteDesktopExecArg(arg) {
  return '"' + String(arg).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

/**
 * Builds a .desktop file body with quoted Exec and optional Hidden flag.
 * Packaged apps: Exec is the installed binary plus --autostart (toggle from the installed build).
 * Unpackaged (dev): Electron needs the app directory and --no-sandbox on Linux; XDG autostart has no project cwd.
 * Input: hidden (boolean). Output: desktop entry string.
 */
function buildDesktopEntry(hidden) {
  const exe = app.getPath('exe');
  let execLine;
  if (app.isPackaged) {
    execLine = `${quoteDesktopExecArg(exe)} --autostart`;
  } else if (process.platform === 'linux') {
    const appDir = __dirname;
    execLine = `${quoteDesktopExecArg(exe)} --no-sandbox ${quoteDesktopExecArg(appDir)} --autostart`;
  } else {
    execLine = `${quoteDesktopExecArg(exe)} ${quoteDesktopExecArg(__dirname)} --autostart`;
  }
  return [
    '[Desktop Entry]',
    'Type=Application',
    'Version=1.0',
    'Name=Life Execution Framework',
    'Comment=Life Execution Framework startup script',
    `Exec=${execLine}`,
    'StartupNotify=false',
    'Terminal=false',
    `Hidden=${hidden ? 'true' : 'false'}`,
  ].join('\n') + '\n';
}

/**
 * Linux-only launcher: writes/removes ~/.config/autostart .desktop (avoids auto-launch path bugs).
 * Input: none. Output: object with enable, disable, isEnabled (async, same shape as auto-launch).
 */
function createLinuxLauncher() {
  const desktopPath = getLinuxDesktopPath();
  return {
    async enable() {
      const dir = path.dirname(desktopPath);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(desktopPath, buildDesktopEntry(false));
    },
    async disable() {
      if (fs.existsSync(desktopPath)) fs.unlinkSync(desktopPath);
    },
    async isEnabled() {
      if (!fs.existsSync(desktopPath)) return false;
      const content = fs.readFileSync(desktopPath, 'utf8');
      return !content.includes('Hidden=true');
    },
  };
}

/**
 * Returns platform launcher for autostart toggle. Input: none. Output: launcher with enable/disable/isEnabled.
 */
function getLauncher() {
  if (process.platform === 'linux') return createLinuxLauncher();
  const AutoLaunch = require('auto-launch');
  return new AutoLaunch({
    name: 'Life Execution Framework',
    path: app.getPath('exe'),
    args: ['--autostart'],
  });
}

let mainWindow;

/**
 * Creates the main BrowserWindow and registers IPC handlers. Input: none. Output: none.
 */
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1360,
    height: 920,
    frame: false,
    title: 'Life Execution Framework',
    backgroundColor: '#0a0c10',
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
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  app.quit();
});
