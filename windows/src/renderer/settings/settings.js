(() => {
  const api = window.focusNotch;
  const { t, duration, phaseColor, THEMES, THEME_NAMES, icon, escapeHTML: h } = window.FN;

  const TABS = [
    { id: 'timer', title: 'Timer', icon: 'timer' },
    { id: 'pets', title: 'Focus Friend', icon: 'paw' },
    { id: 'statistics', title: 'Statistics', icon: 'chart' },
    { id: 'notifications', title: 'Notifications', icon: 'bell' },
    { id: 'general', title: 'General', icon: 'sliders' },
  ];
  const REMINDER_CHOICES = [1, 2, 3, 5, 10, 15];
  /// Notch position presets, as fractions of the screen width.
  const POSITIONS = [['Left', 0.22], ['Center', 0.5], ['Right', 0.78]];
  const PERIODS = [['today', 'Today'], ['week', 'This Week'], ['allTime', 'All Time']];

  let model = null;
  let tab = 'timer';
  let period = 'today';
  let importError = '';
  let renderedSignature = '';

  const pane = document.getElementById('pane');
  const tabs = document.querySelector('.tabs');

  // MARK: - Building blocks

  const group = (title, rows, footer = '') => `
    <section class="group">
      ${title ? `<h2>${h(title)}</h2>` : ''}
      <div class="card">${rows.join('')}</div>
      ${footer ? `<p class="footer">${h(footer)}</p>` : ''}
    </section>`;

  const toggle = (label, key, { disabled = false, checked = model.settings[key] } = {}) => `
    <label class="row">
      <span class="label">${h(label)}</span>
      <span class="switch"><input type="checkbox" data-setting="${key}" ${checked ? 'checked' : ''} ${disabled ? 'disabled' : ''}><span></span></span>
    </label>`;

  const minutes = (label, key, min, max, color) => `
    <div class="row stack" style="--slider:${color}">
      <div class="slider-head">
        <i class="dot" style="background:${color}"></i>
        <span class="label">${h(label)}</span>
        <input class="number" type="number" min="${min}" max="${max}" value="${model.settings[key]}" data-setting="${key}" aria-label="${h(label)}">
        <span class="unit">${h(t('min'))}</span>
      </div>
      <div class="slider-line">
        <span>${min}</span>
        <input type="range" min="${min}" max="${max}" step="1" value="${model.settings[key]}" data-setting="${key}" aria-label="${h(label)}">
        <span>${max}</span>
      </div>
    </div>`;

  // MARK: - Panes

  function timerPane() {
    const s = model.settings;
    const color = (phase) => phaseColor(s.theme, phase);
    return group(t('Durations'), [
      minutes(t('Focus'), 'focusMinutes', 5, 120, color('focus')),
      minutes(t('Short Break'), 'shortBreakMinutes', 1, 30, color('shortBreak')),
      minutes(t('Long Break'), 'longBreakMinutes', 5, 60, color('longBreak')),
      `<div class="row">
        <span class="label">${h(t('Sessions before a long break'))}</span>
        <span class="stepper">
          <button data-step="-1">−</button><output>${s.sessionsBeforeLongBreak}</output><button data-step="1">+</button>
        </span>
      </div>`,
    ]) + group(t('Automation'), [
      toggle(t('Start breaks automatically'), 'autoStartBreaks'),
      toggle(t('Start focus sessions automatically'), 'autoStartFocus'),
    ], t('Changes apply to the next phase if a timer is already running.'));
  }

  function petsPane() {
    const s = model.settings;
    const cards = model.pets.map((pet) => `
      <button class="pet-card${pet.id === s.selectedPetID ? ' selected' : ''}" data-pet="${h(pet.id)}">
        <span class="art"><img class="${pet.pixel ? 'pixel' : ''}" src="${h(pet.id === s.selectedPetID ? pet.urls.celebrate : pet.urls.idle)}" alt=""></span>
        <span class="name">${h(pet.name)}</span>
        ${pet.isCustom ? `<span class="remove" role="button" data-remove-pet="${h(pet.id)}" title="${h(t('Remove'))}">${icon('close', 10)}</span>` : ''}
      </button>`).join('');
    const addCard = `
      <button class="pet-card add-card" data-action="choose-gif">
        <span class="art">${icon('plus', 22)}</span>
        <span class="name">${h(t('Add GIF…'))}</span>
      </button>`;
    const style = `
      <div class="row">
        <span class="label">${h(t('Style'))}</span>
        <div class="segmented">
          ${['cute', 'pixel'].map((value) => `<button data-style="${value}" aria-pressed="${s.petStyle === value}">${h(t(value === 'cute' ? 'Cute' : 'Pixel'))}</button>`).join('')}
        </div>
      </div>`;
    return group('', [
      toggle(t('Show focus friend'), 'showPet'),
      toggle(t('Pet sounds'), 'petSoundsEnabled', { disabled: !s.showPet }),
    ], t('Your friend works alongside you during focus sessions and naps during breaks.'))
      + group(t('Choose your companion'), [
        style,
        `<div class="pet-grid${s.showPet ? '' : ' grid-disabled'}">${cards}${addCard}</div>`,
      ], [t('Add your own pet: drop an animated GIF here or click +.'), importError].filter(Boolean).join(' '));
  }

  function statisticsPane() {
    const stats = model.statistics[period];
    const topicName = (id) => model.topics.find((topic) => topic.id === id)?.name ?? t('No topic');
    const longest = stats.rows[0]?.focusSeconds || 1;
    const accent = phaseColor(model.settings.theme, 'focus');
    const bars = stats.rows.length
      ? stats.rows.map((row) => `
        <div class="row bar-row">
          <div class="top"><span>${h(topicName(row.topicID))}</span><span>${h(duration(row.focusSeconds))}</span></div>
          <div class="bar${row.topicID ? '' : ' muted'}"><b style="width:${(row.focusSeconds / longest) * 100}%;${row.topicID ? `background:${accent}` : ''}"></b></div>
        </div>`).join('')
      : `<div class="row empty">${h(t('No focus time yet.'))}</div>`;
    const topics = model.topics.map((topic) => `
      <div class="row">
        <span class="label">${h(topic.name)}</span>
        ${topic.id === model.settings.currentTopicID ? `<span class="check">✓</span>` : ''}
        <button class="icon-only" data-remove-topic="${h(topic.id)}" title="${h(t('Remove'))}">${icon('trash', 15)}</button>
      </div>`).join('');
    return group('', [
      `<div class="row"><div class="segmented" style="flex:1">${PERIODS.map(([value, title]) =>
        `<button data-period="${value}" aria-pressed="${period === value}">${h(t(title))}</button>`).join('')}</div></div>`,
      `<div class="tiles">
        <div class="tile"><div class="caption">${icon('clock', 13)}${h(t('Focus time'))}</div><div class="value">${h(duration(stats.totals.focusSeconds))}</div></div>
        <div class="tile"><div class="caption">${icon('flame', 13)}${h(t('Completed sessions'))}</div><div class="value">${stats.totals.sessions}</div></div>
      </div>`,
      bars,
    ]) + group(t('Topics'), [
      topics,
      `<form class="row" data-form="topic">
        <input class="text-input" name="topic" maxlength="40" placeholder="${h(t('New topic'))}">
        <button class="button" type="submit">${h(t('Add'))}</button>
      </form>`,
    ], t('Pick a topic in the notch before you start, and your focus time is counted under it.'))
      + group('', [`<div class="row"><button class="button danger" data-action="resetToday">${h(t("Reset Today's Statistics"))}</button></div>`]);
  }

  function notificationsPane() {
    const s = model.settings;
    return group('', [
      toggle(t('Show notifications'), 'notificationsEnabled'),
      toggle(t('Play sounds'), 'soundEnabled'),
    ]) + group('', [
      `<label class="row">
        <span class="label">${h(t('Remind me before the next session'))}</span>
        <select data-setting="reminderLeadMinutes">${REMINDER_CHOICES.map((value) =>
          `<option value="${value}" ${value === s.reminderLeadMinutes ? 'selected' : ''}>${h(t('%lld min', value))}</option>`).join('')}</select>
      </label>`,
    ], t("During a break you'll get a heads-up before the next focus session begins. Breaks shorter than this are announced as soon as they start."))
      + group('', [`<div class="row"><button class="button" data-action="testNotification">${h(t('Send Test Notification'))}</button></div>`]);
  }

  function generalPane() {
    const s = model.settings;
    const languageName = (code) => {
      try {
        const name = new Intl.DisplayNames([code], { type: 'language' }).of(code);
        return name.charAt(0).toLocaleUpperCase(code) + name.slice(1);
      } catch {
        return code;
      }
    };
    const themes = Object.keys(THEMES).map((theme) => `
      <button class="theme${s.theme === theme ? ' selected' : ''}" data-theme="${theme}">
        <span class="swatch" style="background:${phaseColor(theme, 'focus')}">
          <i style="background:${phaseColor(theme, 'shortBreak')}"></i><i style="background:${phaseColor(theme, 'longBreak')}"></i>
        </span>
        ${h(t(THEME_NAMES[theme]))}
      </button>`).join('');
    return group('', [
      `<label class="row">
        <span class="label">${h(t('Language'))}</span>
        <select data-setting="language">
          <option value="" ${s.language ? '' : 'selected'}>${h(t('System Default'))}</option>
          ${window.FN.languages.map((code) => `<option value="${code}" ${s.language === code ? 'selected' : ''}>${h(languageName(code))}</option>`).join('')}
        </select>
      </label>`,
      `<label class="row">
        <span class="label">${h(t('Launch at login'))}</span>
        <span class="switch"><input type="checkbox" data-login-item ${model.loginItem ? 'checked' : ''}><span></span></span>
      </label>`,
    ]) + positionGroup() + group(t('Theme'), [`<div class="themes">${themes}</div>`])
      + group('', [`<div class="row"><span class="label">${h(t('Version'))}</span><span class="unit">${h(model.version)}</span></div>`]);
  }

  /// Where the virtual notch sits along the taskbar (Windows, or any bottom placement).
  function positionGroup() {
    if (model.platform !== 'win32' && model.placement.edge !== 'bottom') return '';
    const fraction = model.placement.fraction;
    const percent = Math.round(fraction * 100);
    return group(t('Notch position'), [
      `<div class="row"><div class="segmented" style="flex:1">${POSITIONS.map(([title, value]) =>
        `<button data-position="${value}" aria-pressed="${Math.abs(fraction - value) < 0.03}">${h(t(title))}</button>`).join('')}</div></div>`,
      `<div class="row"><div class="slider-line" style="flex:1">
        <span>${h(t('Left'))}</span>
        <input type="range" min="12" max="88" step="1" value="${percent}" data-setting="notchPosition" data-scale="0.01" aria-label="${h(t('Notch position'))}">
        <span>${h(t('Right'))}</span>
      </div></div>`,
    ], t('You can also move it by dragging the open notch.'));
  }

  const PANES = { timer: timerPane, pets: petsPane, statistics: statisticsPane, notifications: notificationsPane, general: generalPane };

  /// Only the data a pane shows, so the running timer doesn't redraw it (and restart its GIFs) every second.
  function signature() {
    const parts = { tab, period, importError, settings: model.settings };
    if (tab === 'pets') parts.pets = model.pets.map((pet) => pet.id + pet.name);
    if (tab === 'statistics') Object.assign(parts, { statistics: model.statistics, topics: model.topics });
    if (tab === 'general') Object.assign(parts, { loginItem: model.loginItem, placement: model.placement });
    return JSON.stringify(parts);
  }

  function render(force = false) {
    if (!model) return;
    // Don't redraw under the user's cursor while they type or drag.
    const active = document.activeElement;
    if (!force && active && pane.contains(active) && active.matches('input[type=range], input[type=number], .text-input')) return;
    const next = signature();
    if (!force && next === renderedSignature) return;
    renderedSignature = next;
    document.documentElement.style.setProperty('--accent', phaseColor(model.settings.theme, 'focus'));
    pane.innerHTML = PANES[tab]();
  }

  function renderTabs() {
    tabs.innerHTML = TABS.map((item) => `
      <button class="tab" role="tab" data-tab="${item.id}" aria-selected="${item.id === tab}">
        ${icon(item.icon, 20)}<span>${h(t(item.title))}</span>
      </button>`).join('');
    document.title = t(TABS.find((item) => item.id === tab).title);
  }

  function selectTab(id) {
    tab = id;
    renderTabs();
    render(true);
    window.scrollTo(0, 0);
  }

  // MARK: - Events

  const clampToInput = (input) => Math.min(Math.max(Math.round(Number(input.value) || 0), Number(input.min)), Number(input.max));

  pane.addEventListener('input', (event) => {
    const input = event.target;
    if (input.type === 'range') {
      // Keep the number box in step while dragging.
      const box = input.closest('.row').querySelector('input[type=number]');
      if (box) box.value = input.value;
      api.setSetting(input.dataset.setting, Number(input.value) * Number(input.dataset.scale ?? 1));
    }
  });

  pane.addEventListener('change', (event) => {
    const input = event.target;
    if (input.matches('[data-login-item]')) return api.setLoginItem(input.checked);
    const key = input.dataset.setting;
    if (!key) return;
    if (input.type === 'checkbox') api.setSetting(key, input.checked);
    else if (input.type === 'number') {
      const value = clampToInput(input);
      input.value = value;
      input.closest('.row').querySelector('input[type=range]').value = value;
      api.setSetting(key, value);
    } else if (input.type === 'range') {
      input.blur();
    } else if (key === 'reminderLeadMinutes') api.setSetting(key, Number(input.value));
    else api.setSetting(key, input.value);
  });

  pane.addEventListener('click', async (event) => {
    const target = event.target;
    const removePet = target.closest('[data-remove-pet]');
    if (removePet) {
      event.stopPropagation();
      return api.action('removePet', removePet.dataset.removePet);
    }
    const pet = target.closest('[data-pet]');
    if (pet) return api.setSetting('selectedPetID', pet.dataset.pet);
    const style = target.closest('[data-style]');
    if (style) return api.setSetting('petStyle', style.dataset.style);
    const position = target.closest('[data-position]');
    if (position) return api.setSetting('notchPosition', Number(position.dataset.position));
    const theme = target.closest('[data-theme]');
    if (theme) return api.setSetting('theme', theme.dataset.theme);
    const periodButton = target.closest('[data-period]');
    if (periodButton) {
      period = periodButton.dataset.period;
      return render(true);
    }
    const removeTopic = target.closest('[data-remove-topic]');
    if (removeTopic) return api.action('removeTopic', removeTopic.dataset.removeTopic);
    const stepButton = target.closest('[data-step]');
    if (stepButton) {
      const value = Math.min(Math.max(model.settings.sessionsBeforeLongBreak + Number(stepButton.dataset.step), 2), 12);
      return api.setSetting('sessionsBeforeLongBreak', value);
    }
    const action = target.closest('[data-action]');
    if (!action) return;
    if (action.dataset.action === 'choose-gif') {
      const ok = await api.chooseGIF();
      importError = ok ? '' : t("This file couldn't be added. Please choose a valid GIF.");
      return render(true);
    }
    api.action(action.dataset.action);
  });

  pane.addEventListener('submit', (event) => {
    event.preventDefault();
    const input = event.target.elements.topic;
    if (input.value.trim()) api.action('createTopic', input.value);
    input.value = '';
    input.blur();
  });

  tabs.addEventListener('click', (event) => {
    const button = event.target.closest('[data-tab]');
    if (button) selectTab(button.dataset.tab);
  });

  // Dropping GIFs anywhere on the pets tab adds them.
  document.addEventListener('dragover', (event) => {
    if (tab !== 'pets') return;
    event.preventDefault();
    document.body.classList.add('drop-target');
  });
  document.addEventListener('dragleave', () => document.body.classList.remove('drop-target'));
  document.addEventListener('drop', async (event) => {
    event.preventDefault();
    document.body.classList.remove('drop-target');
    if (tab !== 'pets') return;
    const files = [...event.dataTransfer.files].filter((file) => file.name.toLowerCase().endsWith('.gif'));
    if (!files.length) return;
    const ok = await api.importFiles(files);
    importError = ok ? '' : t("This file couldn't be added. Please choose a valid GIF.");
    render(true);
  });

  api.onDebug((options) => {
    if (options.tab) selectTab(options.tab);
  });

  api.onState((next) => {
    model = next;
    render();
  });
  api.getState().then((initial) => {
    model = initial;
    renderTabs();
    render(true);
  });
})();
