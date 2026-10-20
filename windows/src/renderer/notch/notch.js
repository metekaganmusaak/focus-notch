(() => {
  const api = window.focusNotch;
  const { t, duration, clock, phaseColor, PHASE_TITLES, icon, escapeHTML } = window.FN;

  const WINDOW_HEIGHT = 300;
  // A virtual notch: PCs have no hardware notch, so the pet and countdown sit side by
  // side with no gap. Widths of the collapsed pill per size setting, so it fits a busy taskbar.
  const SIZES = {
    small: { idle: 64, compact: 132 },
    medium: { idle: 110, compact: 200 },
    large: { idle: 180, compact: 300 },
  };
  /// The latest app state from the main process.
  let model = null;
  const size = () => SIZES[model?.settings.notchSize] ?? SIZES.medium;
  /// Set by the app: which screen edge the notch is on, the height of the bar it
  /// sits in (menu bar or taskbar), and its horizontal center inside the window.
  let place = { edge: 'top', band: 34, anchorX: 380 };
  const PHASE_ICONS = { focus: 'timer', shortBreak: 'clock', longBreak: 'clock' };

  /// Body size and corner radii per mode, as in NotchLayout.swift.
  function layout(mode) {
    switch (mode) {
      case 'compact': return { w: size().compact, h: place.band, top: 6, bottom: 12 };
      case 'expanded': return { w: 510, h: place.band + 170, top: 14, bottom: 30 };
      case 'alert': return { w: 470, h: place.band + 96, top: 14, bottom: 30 };
      default: return { w: size().idle, h: place.band, top: 6, bottom: 12 };
    }
  }
  const isOpen = (mode) => mode === 'expanded' || mode === 'alert';

  const $ = (selector, root = document) => root.querySelector(selector);
  const views = { compact: $('#compact'), expanded: $('#expanded'), alert: $('#alert') };
  const shapePath = $('#shape-path');
  const stage = $('#stage');

  function placeViews() {
    document.body.classList.toggle('bottom-edge', place.edge === 'bottom');
    for (const name of Object.keys(SIZES)) document.body.classList.toggle(`size-${name}`, size() === SIZES[name]);
    document.body.style.setProperty('--notch-height', `${place.band}px`);
    for (const view of Object.values(views)) {
      view.style.width = `${layout(view.id).w}px`;
      view.style.height = `${layout(view.id).h}px`;
      view.style.left = `${place.anchorX}px`;
    }
  }

  // MARK: - Shape animation (a damped spring, like SwiftUI's .spring(response: 0.42, dampingFraction: 0.8))

  const STIFFNESS = (2 * Math.PI / 0.42) ** 2;
  const DAMPING = (4 * Math.PI * 0.8) / 0.42;
  const current = { ...layout('idle') };
  const velocity = { w: 0, h: 0, top: 0, bottom: 0 };
  let target = { ...current };
  let animating = false;
  let lastFrame = 0;

  /// The notch outline: flush with the screen edge, flared where it meets it, rounded at
  /// the far end. On the bottom edge the same shape is mirrored to grow upward.
  function pathFor({ w, h, top: requestedTop, bottom: requestedBottom }) {
    const width = w + requestedTop * 2;
    const x = place.anchorX - width / 2;
    const top = Math.min(requestedTop, width / 4);
    const bottom = Math.max(0, Math.min(requestedBottom, h - top, (width - top * 2) / 2));
    const r = x + width;
    const y = (value) => (place.edge === 'bottom' ? WINDOW_HEIGHT - value : value);
    return [
      `M${x},${y(0)}`,
      `Q${x + top},${y(0)} ${x + top},${y(top)}`,
      `L${x + top},${y(h - bottom)}`,
      `Q${x + top},${y(h)} ${x + top + bottom},${y(h)}`,
      `L${r - top - bottom},${y(h)}`,
      `Q${r - top},${y(h)} ${r - top},${y(h - bottom)}`,
      `L${r - top},${y(top)}`,
      `Q${r - top},${y(0)} ${r},${y(0)}`,
      'Z',
    ].join(' ');
  }

  function draw() {
    const d = pathFor(current);
    shapePath.setAttribute('d', d);
    stage.style.clipPath = `path('${d}')`;
  }

  function step(now) {
    const dt = Math.min((now - lastFrame) / 1000, 1 / 30);
    lastFrame = now;
    let settled = true;
    for (const key of Object.keys(velocity)) {
      const force = -STIFFNESS * (current[key] - target[key]) - DAMPING * velocity[key];
      velocity[key] += force * dt;
      current[key] += velocity[key] * dt;
      if (Math.abs(current[key] - target[key]) > 0.05 || Math.abs(velocity[key]) > 0.05) settled = false;
    }
    if (settled) {
      Object.assign(current, target);
      for (const key of Object.keys(velocity)) velocity[key] = 0;
    }
    draw();
    if (settled) animating = false;
    else requestAnimationFrame(step);
  }

  function animateTo(next) {
    target = next;
    if (animating) return;
    animating = true;
    lastFrame = performance.now();
    requestAnimationFrame(step);
  }

  // MARK: - Mode and hover

  let mode = 'idle';
  let hovering = false;
  let editingTopic = false;
  let hoverTimer = null;
  let forcedHover = null;
  let drag = null;

  function computeMode() {
    if (!model) return 'idle';
    if (model.alert) return 'alert';
    if (forcedHover ?? (hovering || editingTopic || drag)) return 'expanded';
    if (model.engine.isSessionActive) return 'compact';
    return 'idle';
  }

  function applyMode() {
    const next = computeMode();
    if (next === mode) return;
    mode = next;
    for (const [name, view] of Object.entries(views)) {
      const active = name === mode;
      view.classList.toggle('active', active);
      view.setAttribute('aria-hidden', String(!active));
    }
    document.body.classList.toggle('open', isOpen(mode));
    api.setInteractive(isOpen(mode));
    animateTo(layout(mode));
  }

  function pointerInside(x, y) {
    const box = layout(mode);
    const width = box.w + box.top * 2;
    // Once open, allow some slack so small overshoots don't collapse the panel.
    const slack = isOpen(mode) ? 14 : 2;
    const left = place.anchorX - width / 2 - slack;
    const withinY = place.edge === 'bottom'
      ? y >= WINDOW_HEIGHT - box.h - slack && y <= WINDOW_HEIGHT
      : y >= 0 && y <= box.h + slack;
    return x >= left && x <= left + width + slack * 2 && withinY;
  }

  function pointerMoved(x, y) {
    const inside = pointerInside(x, y);
    if (inside === hovering) {
      clearTimeout(hoverTimer);
      hoverTimer = null;
      return;
    }
    if (hoverTimer) return;
    // A short delay on entry ignores a pointer passing by; a longer one on exit forgives wiggles.
    hoverTimer = setTimeout(() => {
      hoverTimer = null;
      hovering = inside;
      applyMode();
    }, inside ? 90 : 280);
  }

  document.addEventListener('mousemove', (event) => pointerMoved(event.clientX, event.clientY));
  document.addEventListener('mouseleave', () => pointerMoved(-1, -1));

  // MARK: - Rendering

  function setClock(element, text) {
    if (element.dataset.text === text) return;
    const previous = element.dataset.text ?? '';
    element.dataset.text = text;
    element.innerHTML = [...text]
      .map((char, index) => `<span class="digit${previous && previous[index] !== char ? ' roll' : ''}">${char}</span>`)
      .join('');
  }

  function setPet(container, pet, mood, fallbackIcon, size) {
    container.classList.toggle('no-pet', !pet);
    const image = $('.pet', container);
    const url = pet?.urls[mood] ?? '';
    if (image.getAttribute('src') !== url) {
      if (url) image.setAttribute('src', url);
      else image.removeAttribute('src');
    }
    image.classList.toggle('pixel', Boolean(pet?.pixel));
    const fallback = $('.phase-icon', container);
    if (fallback.dataset.icon !== fallbackIcon) {
      fallback.dataset.icon = fallbackIcon;
      fallback.innerHTML = icon(fallbackIcon, size);
    }
  }

  function renderCompact(engine, tint) {
    const view = views.compact;
    setPet($('.wing.leading', view), model.pet, model.mood, PHASE_ICONS[engine.phase], 22);
    view.classList.toggle('idle-state', engine.state !== 'running');
    const status = $('.mini-status', view);
    const kind = engine.state === 'running' ? 'ring' : engine.state;
    if (status.dataset.kind !== kind) {
      status.dataset.kind = kind;
      status.innerHTML = kind === 'ring'
        ? '<svg width="13" height="13" viewBox="0 0 100 100" style="rotate:-90deg"><circle cx="50" cy="50" r="40" fill="none" stroke="rgba(255,255,255,.12)" stroke-width="16"/><circle class="mini-progress" cx="50" cy="50" r="40" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-dasharray="251.3" style="transition:stroke-dashoffset 1s linear"/></svg>'
        : icon(engine.state === 'paused' ? 'pause' : 'play', 11);
    }
    const mini = $('.mini-progress', status);
    if (mini) mini.style.strokeDashoffset = String(251.3 * (1 - engine.progress));
    setClock($('.compact-time', view), clock(engine.remaining));
  }

  function renderExpanded(engine, tint) {
    const view = views.expanded;
    view.classList.toggle('running', engine.state === 'running');
    $('.phase-title', view).textContent = t(PHASE_TITLES[engine.phase]);
    $('.paused-label', view).textContent = engine.state === 'paused' ? t('Paused') : '';
    $('.today-sessions', view).textContent = String(model.today.sessions);
    $('.today-time', view).textContent = duration(model.today.focusSeconds);
    $('.today', view).title = t('Focus time today');

    setPet($('.avatar', view), model.pet, model.mood, PHASE_ICONS[engine.phase], 44);
    $('.ring .progress', view).style.strokeDashoffset = String(282.74 * (1 - engine.progress));

    let subtitle;
    if (!engine.isSessionActive && engine.isPristine) subtitle = t('Ready to focus?');
    else if (engine.phase === 'focus') subtitle = t('Round %lld of %lld', Math.min(engine.completedInCycle + 1, engine.sessionsPerCycle), engine.sessionsPerCycle);
    else subtitle = t('Up next: %@', t('Focus'));
    $('.subtitle', view).textContent = subtitle;
    setClock($('.big-time', view), clock(engine.remaining));

    const dots = $('.dots', view);
    const signature = `${engine.sessionsPerCycle}:${engine.completedInCycle}:${engine.phase}`;
    if (dots.dataset.signature !== signature) {
      dots.dataset.signature = signature;
      dots.innerHTML = Array.from({ length: Math.max(engine.sessionsPerCycle, 1) }, (_, index) => {
        const current = engine.phase === 'focus' && index === engine.completedInCycle;
        const done = index < engine.completedInCycle;
        return `<i class="${current ? 'current' : ''}"><b style="width:${done ? 100 : 0}%"></b></i>`;
      }).join('');
    }
    const currentDot = $('.dots i.current b', view);
    if (currentDot) currentDot.style.width = `${engine.progress * 100}%`;

    const toggle = $('[data-action="toggle"]', view);
    const toggleIcon = engine.state === 'running' ? 'pause' : 'play';
    if (toggle.dataset.icon !== toggleIcon) {
      toggle.dataset.icon = toggleIcon;
      toggle.innerHTML = icon(toggleIcon, 20);
    }
    toggle.title = engine.state === 'running' ? t('Pause') : engine.state === 'paused' ? t('Resume') : t('Start');
    $('[data-action="reset"]', view).disabled = engine.isPristine;
    $('[data-action="finish"]', view).disabled = !engine.isSessionActive;

    renderTopics();
  }

  function renderTopics() {
    const chips = $('.chips', views.expanded);
    const selected = model.settings.currentTopicID;
    const signature = JSON.stringify([model.topics, selected, editingTopic]);
    if (chips.dataset.signature === signature) return;
    chips.dataset.signature = signature;
    const topicChips = model.topics.map((topic) =>
      `<button class="chip${topic.id === selected ? ' selected' : ''}" data-topic="${escapeHTML(topic.id)}">${escapeHTML(topic.name)}</button>`);
    const adder = editingTopic
      ? `<input class="chip-input" maxlength="40" placeholder="${escapeHTML(t('New topic'))}">`
      : `<button class="chip" data-add-topic title="${escapeHTML(t('Add topic'))}">${icon('plus', 11)}${model.topics.length ? '' : escapeHTML(t('Add topic'))}</button>`;
    chips.innerHTML = topicChips.join('') + adder;
    const input = $('.chip-input', chips);
    if (input) {
      input.focus();
      input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
          api.action('addTopic', input.value);
          stopEditing();
        } else if (event.key === 'Escape') {
          stopEditing();
        }
      });
      input.addEventListener('blur', () => editingTopic && stopEditing());
    }
  }

  function stopEditing() {
    editingTopic = false;
    api.setKeyboard(false);
    if (model) renderTopics();
    applyMode();
  }

  function renderAlert() {
    const view = views.alert;
    const alert = model.alert;
    if (!alert) return;
    view.style.setProperty('--tint', phaseColor(model.settings.theme, alert.tint));
    setPet($('.alert-pet', view), model.pet, alert.mood, 'bell', 36);
    $('.alert-title', view).textContent = alert.title;
    $('.alert-message', view).textContent = alert.message;
    const action = $('[data-action="alertAction"]', view);
    action.hidden = !alert.action;
    action.textContent = alert.action ?? '';
  }

  let renderedSize = null;

  function applyPlacement(next, first) {
    const sizeChanged = renderedSize !== model.settings.notchSize;
    if (!sizeChanged && (!next || JSON.stringify(next) === JSON.stringify(place))) return;
    renderedSize = model.settings.notchSize;
    if (next) place = next;
    placeViews();
    if (first) {
      Object.assign(current, layout(mode));
      draw();
    } else {
      animateTo(layout(mode));
    }
  }

  function render(first = false) {
    applyPlacement(model.placement, first);
    const engine = model.engine;
    const tint = phaseColor(model.settings.theme, engine.phase);
    document.body.style.setProperty('--tint', tint);
    document.body.style.setProperty('--focus-tint', phaseColor(model.settings.theme, 'focus'));
    renderCompact(engine, tint);
    renderExpanded(engine, tint);
    renderAlert();
    applyMode();
  }

  // MARK: - Events

  document.addEventListener('click', (event) => {
    const topic = event.target.closest('[data-topic]');
    if (topic) {
      const id = topic.dataset.topic;
      api.action('selectTopic', model.settings.currentTopicID === id ? null : id);
      return;
    }
    if (event.target.closest('[data-add-topic]')) {
      editingTopic = true;
      api.setKeyboard(true);
      renderTopics();
      applyMode();
      return;
    }
    const button = event.target.closest('[data-action]');
    if (button) api.action(button.dataset.action);
  });

  // Drag the open panel by its status strip to slide the notch along the bar.
  const header = $('.header', views.expanded);
  header.addEventListener('pointerdown', (event) => {
    if (event.button !== 0 || event.target.closest('button')) return;
    drag = { x: event.screenX };
    header.setPointerCapture(event.pointerId);
    document.body.classList.add('dragging');
  });
  header.addEventListener('pointermove', (event) => {
    if (!drag) return;
    const deltaX = event.screenX - drag.x;
    if (!deltaX) return;
    drag.x = event.screenX;
    api.dragNotch(deltaX);
  });
  const endDrag = () => {
    drag = null;
    document.body.classList.remove('dragging');
    applyMode();
  };
  header.addEventListener('pointerup', endDrag);
  header.addEventListener('pointercancel', endDrag);

  api.onPlaySound((url) => {
    const audio = new Audio(url);
    audio.volume = 0.9;
    audio.play().catch(() => {});
  });

  api.onDebug((options) => {
    if ('hover' in options) forcedHover = options.hover || null;
    applyMode();
  });

  // Static labels and icons.
  $('[data-action="settings"]').innerHTML = icon('gear', 13);
  $('[data-action="settings"]').title = t('Settings');
  $('[data-action="reset"]').innerHTML = icon('reset', 15);
  $('[data-action="reset"]').title = t('Reset');
  $('[data-action="skip"]').innerHTML = icon('skip', 15);
  $('[data-action="skip"]').title = t('Skip');
  $('[data-action="finish"]').innerHTML = `${icon('flag', 13)}<span>${escapeHTML(t('Finish'))}</span>`;
  $('[data-action="finish"]').title = t('End this session and see your summary');
  $('[data-action="dismissAlert"]').innerHTML = icon('close', 11);
  $('[data-action="dismissAlert"]').title = t('Dismiss');
  $('.flame').innerHTML = icon('flame', 12);
  $('.tag-icon').innerHTML = icon('tag', 12);

  placeViews();
  draw();
  api.onState((next) => {
    model = next;
    render();
  });
  api.getState().then((initial) => {
    model = initial;
    render(true);
  });
})();
