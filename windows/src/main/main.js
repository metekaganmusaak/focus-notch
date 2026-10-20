const { app, BrowserWindow, Menu, Notification, Tray, dialog, ipcMain, nativeImage, nativeTheme, screen } = require('electron');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const { PomodoroEngine } = require('./engine');
const { I18n, LANGUAGES, resolveLanguage } = require('./i18n');
const { listPets, importGIF, removeCustomPet } = require('./pets');
const { Store } = require('./store');

const ROOT = path.join(__dirname, '..', '..');
const ASSETS = path.join(ROOT, 'assets');
const RENDERER = path.join(ROOT, 'src', 'renderer');
const PRELOAD = path.join(__dirname, 'preload.js');
/// Fixed size of the transparent notch window; the black shape animates inside it,
/// so the window itself never moves or resizes.
const NOTCH_WINDOW = { width: 760, height: 300 };
const TIMING_KEYS = new Set(['focusMinutes', 'shortBreakMinutes', 'longBreakMinutes', 'reminderLeadMinutes']);
const PHASE_TITLES = { focus: 'Focus', shortBreak: 'Short Break', longBreak: 'Long Break' };

// `--snapshot` renders every view to PNG files (for visual checks) using a throwaway profile.
const snapshotMode = process.argv.includes('--snapshot');
if (snapshotMode) app.setPath('userData', fs.mkdtempSync(path.join(os.tmpdir(), 'focus-notch-snapshot-')));

if (!snapshotMode && !app.requestSingleInstanceLock()) app.quit();
app.setAppUserModelId('com.focusnotch.app');

let store;
let engine;
let i18n;
let notchWindow = null;
let settingsWindow = null;
let tray = null;
let alert = null;
let alertTimer = null;
let petReaction = null;
let reactionTimer = null;
/// Where the notch sits: hanging from the top edge, or standing in a bottom taskbar.
let placement = { edge: 'top', band: 34, anchorX: NOTCH_WINDOW.width / 2, fraction: 0.5 };

const customPetsDirectory = () => path.join(app.getPath('userData'), 'pets');
const soundURL = (name) => pathToFileURL(path.join(ASSETS, 'sounds', `${name}.wav`)).href;

function loadLanguage() {
  const language = store.settings.language || resolveLanguage(app.getPreferredSystemLanguages());
  i18n = new I18n(path.join(ASSETS, 'locales'), language);
}

const t = (key, ...args) => i18n.t(key, ...args);

// MARK: - State

function pets() {
  return listPets({
    style: store.settings.petStyle,
    assets: ASSETS,
    customDirectory: customPetsDirectory(),
    customPets: store.customPets,
    t,
  });
}

function activePet(all = pets()) {
  if (!store.settings.showPet) return null;
  return all.find((pet) => pet.id === store.settings.selectedPetID) ?? all[0];
}

function petMood() {
  if (petReaction) return petReaction;
  if (engine.state === 'running') return engine.phase === 'focus' ? 'focus' : 'rest';
  return 'idle';
}

function state() {
  const all = pets();
  return {
    engine: engine.snapshot(),
    settings: store.settings,
    today: store.today,
    pets: all,
    pet: activePet(all),
    mood: petMood(),
    topics: store.topics,
    alert,
    statistics: {
      today: store.statistics('today'),
      week: store.statistics('week'),
      allTime: store.statistics('allTime'),
    },
    placement,
    loginItem: app.getLoginItemSettings().openAtLogin,
    version: app.getVersion(),
    platform: process.platform,
  };
}

let broadcastQueued = false;
function broadcast() {
  if (broadcastQueued) return;
  broadcastQueued = true;
  setImmediate(() => {
    broadcastQueued = false;
    const snapshot = state();
    for (const window of [notchWindow, settingsWindow]) {
      if (window && !window.isDestroyed()) window.webContents.send('state', snapshot);
    }
    updateTray();
  });
}

// MARK: - Alerts

function presentAlert(next) {
  alert = { id: Date.now(), ...next };
  clearTimeout(alertTimer);
  alertTimer = setTimeout(() => {
    alert = null;
    broadcast();
  }, next.action ? 15_000 : 7_000);
  if (store.settings.soundEnabled) playSound(next.sound);
  if (store.settings.notificationsEnabled && Notification.isSupported()) {
    new Notification({ title: next.title, body: next.message, silent: true, icon: path.join(ASSETS, 'icon.png') }).show();
  }
  broadcast();
}

function dismissAlert() {
  clearTimeout(alertTimer);
  alert = null;
  broadcast();
}

function playSound(name) {
  if (notchWindow && !notchWindow.isDestroyed()) notchWindow.webContents.send('play-sound', soundURL(name));
}

function makeAlert(event) {
  const settings = store.settings;
  switch (event.type) {
    case 'focusCompleted': {
      const length = engine.duration(event.next);
      const title = event.next === 'longBreak' ? t('Time for a long break!') : t('Time for a break!');
      let message;
      if (event.autoStarted) {
        const spelled = i18n.duration(length);
        message = t('Great focus! Relax for %@.', spelled);
        if (settings.autoStartFocus && length <= settings.reminderLeadMinutes * 60) {
          message += ` ${t('Your next focus session starts in %@.', spelled)}`;
        }
      } else {
        message = t("Great focus! Start your break whenever you're ready.");
      }
      return { title, message, tint: event.next, mood: 'celebrate', sound: 'chime_break', action: event.autoStarted ? null : t('Start Break') };
    }
    case 'breakCompleted':
      return {
        title: t("Break's over!"),
        message: event.autoStarted ? t("Your next focus session has started. You've got this!") : t('Ready for the next focus session?'),
        tint: 'focus', mood: 'idle', sound: 'chime_focus',
        action: event.autoStarted ? null : t('Start Focus'),
      };
    case 'nextSessionSoon': {
      const spelled = i18n.duration(event.remaining);
      return {
        title: t('Heads up!'),
        message: settings.autoStartFocus ? t('Your next focus session starts in %@.', spelled) : t('Your break ends in %@.', spelled),
        tint: engine.phase, mood: 'idle', sound: 'chime_reminder', action: null,
      };
    }
    case 'finished':
      if (event.focusTime < 60) {
        return { title: t('Session finished'), message: t('See you next time!'), tint: 'focus', mood: 'idle', sound: 'chime_finish', action: null };
      }
      return {
        title: t('Great work!'),
        message: t('Focus time: %@ · Sessions: %lld', i18n.duration(event.focusTime, 'short'), event.sessions),
        tint: 'focus', mood: 'celebrate', sound: 'chime_finish', action: null,
      };
    default:
      return null;
  }
}

function react(mood, milliseconds = 1800) {
  petReaction = mood;
  clearTimeout(reactionTimer);
  reactionTimer = setTimeout(() => {
    petReaction = null;
    broadcast();
  }, milliseconds);
  broadcast();
}

// MARK: - Actions

const actions = {
  toggle: () => engine.toggle(),
  start: () => engine.start(),
  skip: () => engine.skip(),
  reset: () => engine.reset(),
  finish: () => engine.finish(),
  alertAction: () => {
    dismissAlert();
    engine.start();
  },
  dismissAlert,
  pet: () => {
    react('celebrate');
    const pet = activePet();
    if (store.settings.petSoundsEnabled && pet?.sound && notchWindow) notchWindow.webContents.send('play-sound', pet.sound);
  },
  settings: () => openSettings(),
  selectTopic: (id) => store.setSetting('currentTopicID', id ?? null),
  addTopic: (name) => {
    const topic = store.addTopic(name);
    if (topic) store.setSetting('currentTopicID', topic.id);
  },
  createTopic: (name) => store.addTopic(name),
  removeTopic: (id) => store.removeTopic(id),
  removePet: (id) => {
    const record = store.customPets.find((pet) => pet.id === id);
    if (!record) return;
    removeCustomPet(record, customPetsDirectory());
    store.customPets = store.customPets.filter((pet) => pet.id !== id);
    if (store.settings.selectedPetID === id) store.settings.selectedPetID = 'cat';
    store.save();
  },
  resetToday: () => store.resetToday(),
  testNotification: () => {
    if (Notification.isSupported()) {
      new Notification({ title: 'Focus Notch', body: t('Notifications are working. Stay focused!'), silent: true, icon: path.join(ASSETS, 'icon.png') }).show();
    }
    if (store.settings.soundEnabled) playSound('chime_break');
  },
  quit: () => app.quit(),
};

function importFiles(files) {
  let added = null;
  for (const file of files) {
    try {
      const record = importGIF(file, customPetsDirectory());
      if (!record) continue;
      store.customPets.push(record);
      added = record;
    } catch {
      // Unreadable file: reported below as a failure.
    }
  }
  if (added) {
    store.settings.selectedPetID = added.id;
    store.save();
    broadcast();
  }
  return Boolean(added);
}

function registerIPC() {
  ipcMain.on('get-i18n', (event) => {
    event.returnValue = { language: i18n.language, rtl: i18n.rtl, strings: i18n.strings, languages: LANGUAGES };
  });
  ipcMain.handle('get-state', () => state());
  ipcMain.on('action', (_event, name, argument) => {
    actions[name]?.(argument);
    broadcast();
  });
  ipcMain.on('set-setting', (_event, key, value) => {
    if (!store.setSetting(key, value)) return;
    if (TIMING_KEYS.has(key)) engine.settingsDidChange();
    if (key === 'notchPosition') positionNotch();
    if (key === 'language') {
      loadLanguage();
      for (const window of [notchWindow, settingsWindow]) {
        if (window && !window.isDestroyed()) window.webContents.reload();
      }
    }
    broadcast();
  });
  // Dragging the open panel's status strip slides the notch along the taskbar.
  ipcMain.on('drag-notch', (_event, deltaX) => {
    const { bounds } = screen.getPrimaryDisplay();
    const fraction = Math.min(Math.max(placement.fraction + deltaX / bounds.width, 0.12), 0.88);
    store.setSetting('notchPosition', fraction);
    positionNotch();
  });
  ipcMain.on('set-interactive', (_event, interactive) => {
    if (interactive) notchWindow.setIgnoreMouseEvents(false);
    else notchWindow.setIgnoreMouseEvents(true, { forward: true });
  });
  // Typing a topic in the notch needs keyboard focus; afterwards it goes back to the previous app.
  ipcMain.on('keyboard', (_event, wanted) => {
    if (wanted) notchWindow.focus();
    else notchWindow.blur();
  });
  ipcMain.handle('choose-gif', async () => {
    const result = await dialog.showOpenDialog(settingsWindow ?? undefined, {
      title: t('Choose an animated GIF for your focus friend'),
      filters: [{ name: 'GIF', extensions: ['gif'] }],
      properties: ['openFile', 'multiSelections'],
    });
    return result.canceled ? true : importFiles(result.filePaths);
  });
  ipcMain.handle('import-gifs', (_event, files) => importFiles(files));
  ipcMain.on('set-login-item', (_event, enabled) => {
    app.setLoginItemSettings({ openAtLogin: Boolean(enabled) });
    broadcast();
  });
}

// MARK: - Windows

/// Windows 11 centers taskbar icons unless "Taskbar alignment" is set to left.
function taskbarIconsCentered() {
  if (process.platform !== 'win32' || Number(os.release().split('.')[2]) < 22000) return false;
  try {
    const output = execFileSync('reg', ['query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced', '/v', 'TaskbarAl'],
      { encoding: 'utf8', windowsHide: true });
    return !/TaskbarAl\s+REG_DWORD\s+0x0\b/.test(output);
  } catch {
    return true; // The value is missing until the user changes it, and centered is the default.
  }
}

let iconsCentered = null;

/// On Windows the notch stands in the bottom taskbar and grows upward; with a top
/// taskbar (or on macOS, under the menu bar) it hangs from the top edge instead.
function positionNotch() {
  if (!notchWindow || notchWindow.isDestroyed()) return;
  const { bounds, workArea } = screen.getPrimaryDisplay();
  const topInset = workArea.y - bounds.y;
  const bottomInset = bounds.y + bounds.height - (workArea.y + workArea.height);
  // `--taskbar` previews the Windows taskbar placement on any OS.
  const inTaskbar = (process.platform === 'win32' && topInset === 0) || process.argv.includes('--taskbar');
  const edge = inTaskbar ? 'bottom' : 'top';
  const band = edge === 'bottom'
    ? (bottomInset > 0 ? bottomInset : 40)
    : (topInset > 0 ? Math.min(topInset, 48) : 34);

  // Left of centered Windows 11 icons by default, clear of the Widgets button.
  iconsCentered ??= taskbarIconsCentered();
  const defaultCenter = edge === 'bottom' && iconsCentered
    ? Math.max(bounds.width * 0.22, 390)
    : bounds.width / 2;
  const fraction = store.settings.notchPosition ?? defaultCenter / bounds.width;
  const centerX = bounds.x + bounds.width * fraction;
  const { width, height } = NOTCH_WINDOW;
  const x = Math.round(Math.min(Math.max(centerX - width / 2, bounds.x), bounds.x + bounds.width - width));
  // Keep the open panel (about 540 px wide) inside the window even near a screen edge.
  const anchorX = Math.round(Math.min(Math.max(centerX - x, 280), width - 280));
  const y = edge === 'bottom' ? bounds.y + bounds.height - height : bounds.y;
  notchWindow.setBounds({ x, y, width, height });
  placement = { edge, band, anchorX, fraction };
  broadcast();
}

function createNotchWindow() {
  notchWindow = new BrowserWindow({
    ...NOTCH_WINDOW,
    frame: false,
    transparent: true,
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    hasShadow: false,
    alwaysOnTop: true,
    show: false,
    backgroundColor: '#00000000',
    webPreferences: { preload: PRELOAD, contextIsolation: true, sandbox: true, backgroundThrottling: false },
  });
  notchWindow.setAlwaysOnTop(true, 'screen-saver');
  if (process.platform === 'darwin') notchWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  notchWindow.setIgnoreMouseEvents(true, { forward: true });
  notchWindow.loadFile(path.join(RENDERER, 'notch', 'index.html'));
  notchWindow.once('ready-to-show', () => {
    positionNotch();
    notchWindow.showInactive();
    if (snapshotMode) runSnapshots();
  });
  for (const event of ['display-added', 'display-removed', 'display-metrics-changed']) {
    screen.on(event, positionNotch);
  }
  // Clicking the taskbar raises it over other topmost windows; put the notch back on top.
  if (process.platform === 'win32') {
    setInterval(() => {
      if (!notchWindow.isDestroyed()) notchWindow.moveTop();
    }, 1500);
  }
}

function openSettings() {
  if (settingsWindow && !settingsWindow.isDestroyed()) {
    settingsWindow.show();
    settingsWindow.focus();
    return settingsWindow;
  }
  settingsWindow = new BrowserWindow({
    width: 640,
    height: 720,
    minWidth: 560,
    minHeight: 560,
    show: false,
    title: 'Focus Notch',
    icon: path.join(ASSETS, 'icon.png'),
    autoHideMenuBar: true,
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#1f1f1f' : '#f3f3f3',
    webPreferences: { preload: PRELOAD, contextIsolation: true, sandbox: true, backgroundThrottling: !snapshotMode },
  });
  settingsWindow.loadFile(path.join(RENDERER, 'settings', 'index.html'));
  settingsWindow.once('ready-to-show', () => settingsWindow.show());
  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });
  return settingsWindow;
}

// MARK: - Tray

let traySignature = '';
function updateTray() {
  if (!tray) return;
  const snapshot = engine.snapshot();
  const clock = (seconds) => {
    const total = Math.ceil(seconds);
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(Math.floor(total / 60))}:${pad(total % 60)}`;
  };
  const status = snapshot.isSessionActive || !snapshot.isPristine
    ? `${t(PHASE_TITLES[snapshot.phase])} · ${clock(snapshot.remaining)}`
    : t('Ready to focus?');
  tray.setToolTip(`Focus Notch — ${status}`);

  // Rebuilding the menu every second is wasteful; only do it when its items change.
  const all = pets();
  const signature = JSON.stringify([snapshot.state, snapshot.phase, snapshot.isSessionActive, snapshot.isPristine,
    store.settings.selectedPetID, store.settings.showPet, store.settings.currentTopicID, store.topics, all.map((p) => p.id), i18n.language]);
  if (signature === traySignature) return;
  traySignature = signature;

  const primary = snapshot.state === 'running' ? t('Pause')
    : snapshot.state === 'paused' ? t('Resume')
    : snapshot.phase === 'focus' ? t('Start Focus') : t('Start Break');
  const menu = Menu.buildFromTemplate([
    { label: primary, click: () => { engine.toggle(); broadcast(); } },
    { label: t('Skip'), click: () => engine.skip() },
    { label: t('Reset'), enabled: !snapshot.isPristine, click: () => engine.reset() },
    { label: t('Finish Session'), enabled: snapshot.isSessionActive, click: () => engine.finish() },
    { type: 'separator' },
    {
      label: t('Focus Friend'),
      submenu: all.map((pet) => ({
        label: pet.name, type: 'radio', checked: pet.id === store.settings.selectedPetID,
        click: () => { store.setSetting('selectedPetID', pet.id); broadcast(); },
      })),
    },
    {
      label: t('Show Focus Friend'), type: 'checkbox', checked: store.settings.showPet,
      click: (item) => { store.setSetting('showPet', item.checked); broadcast(); },
    },
    {
      label: t('Topic'),
      submenu: [
        { label: t('No topic'), type: 'radio', checked: !store.settings.currentTopicID, click: () => { actions.selectTopic(null); broadcast(); } },
        ...store.topics.map((topic) => ({
          label: topic.name, type: 'radio', checked: topic.id === store.settings.currentTopicID,
          click: () => { actions.selectTopic(topic.id); broadcast(); },
        })),
      ],
    },
    { type: 'separator' },
    { label: t('Settings…'), click: () => openSettings() },
    { label: t('Quit Focus Notch'), click: () => app.quit() },
  ]);
  tray.setContextMenu(menu);
}

function createTray() {
  const icon = nativeImage.createFromPath(path.join(ASSETS, 'tray.png')).resize({ width: 16, height: 16 });
  tray = new Tray(icon);
  tray.on('click', () => openSettings());
  updateTray();
}

// MARK: - Snapshots

async function runSnapshots() {
  const directory = path.join(ROOT, 'snapshots');
  fs.mkdirSync(directory, { recursive: true });
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const capture = async (window, name) => {
    // A window in the background may not repaint; force a fresh frame before capturing.
    window.show();
    window.webContents.invalidate();
    await wait(1200);
    const image = await window.webContents.capturePage();
    fs.writeFileSync(path.join(directory, `${name}.png`), image.toPNG());
  };

  // Sample data so the statistics tab has something to show.
  const topics = ['Math', 'English', 'Coding'].map((name) => store.addTopic(name));
  for (const [topic, sessions] of [[0, 4], [1, 2], [2, 3]]) {
    for (let i = 0; i < sessions; i++) store.addFocus(25 * 60, true, topics[topic].id);
  }
  store.setSetting('currentTopicID', topics[0].id);
  await capture(notchWindow, 'notch-1-idle');
  engine.start();
  broadcast();
  await capture(notchWindow, 'notch-2-compact');
  notchWindow.webContents.send('debug', { hover: true });
  await capture(notchWindow, 'notch-3-expanded');
  notchWindow.webContents.send('debug', { hover: false });
  presentAlert(makeAlert({ type: 'focusCompleted', next: 'shortBreak', autoStarted: false }));
  await capture(notchWindow, 'notch-4-alert');
  dismissAlert();

  const settings = openSettings();
  await new Promise((resolve) => settings.once('ready-to-show', resolve));
  for (const tab of ['timer', 'pets', 'statistics', 'notifications', 'general']) {
    settings.webContents.send('debug', { tab });
    await capture(settings, `settings-${tab}`);
  }
  app.exit(0);
}

// MARK: - Lifecycle

app.on('second-instance', () => openSettings());
app.on('window-all-closed', () => {
  // Keep running in the tray when the settings window closes.
});
app.on('before-quit', () => store?.flush());

app.whenReady().then(() => {
  store = new Store(app.getPath('userData'));
  const languageArgument = process.argv.find((argument) => argument.startsWith('--lang='));
  if (languageArgument) store.settings.language = languageArgument.slice('--lang='.length);
  const sizeArgument = process.argv.find((argument) => argument.startsWith('--notch-size='));
  if (sizeArgument) store.settings.notchSize = sizeArgument.slice('--notch-size='.length);
  loadLanguage();

  engine = new PomodoroEngine(store);
  engine.on('change', broadcast);
  engine.on('event', (event) => {
    const next = makeAlert(event);
    if (next) presentAlert(next);
  });

  if (process.platform === 'win32') Menu.setApplicationMenu(null);
  registerIPC();
  createNotchWindow();
  if (!snapshotMode) createTray();
});
