// Helpers shared by the notch and settings pages: translations, themes and icons.
(() => {
  const data = window.focusNotch.i18n();
  document.documentElement.lang = data.language;
  document.documentElement.dir = data.rtl ? 'rtl' : 'ltr';

  function t(key, ...args) {
    let next = 0;
    return (data.strings[key] ?? key).replace(/%(?:(\d+)\$)?(@|lld|d)/g, (_, position) => {
      const index = position ? Number(position) - 1 : next++;
      return String(args[index] ?? '');
    });
  }

  /// "5 min" / "1 hr, 30 min" in the app language.
  function duration(seconds, style = 'short') {
    const total = Math.max(Math.round(seconds / 60), 0);
    const parts = total >= 60 ? { hours: Math.floor(total / 60), minutes: total % 60 } : { minutes: total };
    if (parts.minutes === 0 && parts.hours) delete parts.minutes;
    try {
      const options = total === 0 ? { style, minutesDisplay: 'always' } : { style };
      return new Intl.DurationFormat(data.language, options).format(parts);
    } catch {
      return parts.hours ? `${parts.hours} h ${parts.minutes ?? 0} min` : `${parts.minutes} min`;
    }
  }

  /// "24:59" or "1:05:00".
  function clock(seconds) {
    const total = Math.max(Math.ceil(seconds), 0);
    const pad = (n) => String(n).padStart(2, '0');
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor(total / 60) % 60;
    return hours > 0 ? `${hours}:${pad(minutes)}:${pad(total % 60)}` : `${pad(minutes)}:${pad(total % 60)}`;
  }

  // Same palettes as Theme.swift: focus, short break, long break.
  const THEMES = {
    coral: ['#ff735c', '#4de0a3', '#73a3ff'],
    ocean: ['#4a9eff', '#4ddbe6', '#9485ff'],
    forest: ['#6bd673', '#facc5c', '#5cc2a8'],
    lavender: ['#b88fff', '#ff99cc', '#8cb3ff'],
    sunset: ['#ff9438', '#ff6b8f', '#b875f5'],
    mono: ['#f5f5f5', '#c2c2c7', '#9999a3'],
  };
  const THEME_NAMES = { coral: 'Coral', ocean: 'Ocean', forest: 'Forest', lavender: 'Lavender', sunset: 'Sunset', mono: 'Mono' };
  const PHASES = ['focus', 'shortBreak', 'longBreak'];
  const PHASE_TITLES = { focus: 'Focus', shortBreak: 'Short Break', longBreak: 'Long Break' };

  function phaseColor(theme, phase) {
    return (THEMES[theme] ?? THEMES.coral)[PHASES.indexOf(phase)] ?? THEMES.coral[0];
  }

  // 24×24 stroke icons.
  const PATHS = {
    play: '<path d="M8 5.5v13l10.5-6.5z" fill="currentColor" stroke="none"/>',
    pause: '<rect x="6.5" y="5" width="4" height="14" rx="1.2" fill="currentColor" stroke="none"/><rect x="13.5" y="5" width="4" height="14" rx="1.2" fill="currentColor" stroke="none"/>',
    reset: '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 4.5v4h4"/>',
    skip: '<path d="M6 5.5v13l9-6.5z" fill="currentColor" stroke="none"/><rect x="16" y="5.5" width="3" height="13" rx="1" fill="currentColor" stroke="none"/>',
    flag: '<path d="M5.5 21V4"/><path d="M5.5 4.5h12l-2.5 4 2.5 4h-12"/>',
    gear: '<path d="M10.3 3h3.4l.5 2.4 1.7.7 2-1.4 2.4 2.4-1.4 2 .7 1.7 2.4.5v3.4l-2.4.5-.7 1.7 1.4 2-2.4 2.4-2-1.4-1.7.7-.5 2.4h-3.4l-.5-2.4-1.7-.7-2 1.4-2.4-2.4 1.4-2-.7-1.7L3 13.7v-3.4l2.4-.5.7-1.7-1.4-2 2.4-2.4 2 1.4 1.7-.7z"/><circle cx="12" cy="12" r="3"/>',
    flame: '<path d="M12 21.5c-4 0-6.5-2.6-6.5-6.2 0-3.6 2.8-5.6 3.8-9.3 2.4 1.4 3.4 3.6 3.6 5.6 1-1 1.5-2.2 1.6-3.6 2.4 1.8 4 4.4 4 7.3 0 3.6-2.5 6.2-6.5 6.2z" fill="currentColor" stroke="none"/>',
    tag: '<path d="M3.5 12.5V4.5a1 1 0 0 1 1-1h8l8 8-9 9z"/><circle cx="8" cy="8" r="1.4" fill="currentColor" stroke="none"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    trash: '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>',
    timer: '<circle cx="12" cy="13" r="7.5"/><path d="M12 13V9M9.5 2.5h5"/>',
    paw: '<circle cx="7" cy="9" r="1.8" fill="currentColor" stroke="none"/><circle cx="17" cy="9" r="1.8" fill="currentColor" stroke="none"/><circle cx="10" cy="5.5" r="1.8" fill="currentColor" stroke="none"/><circle cx="14" cy="5.5" r="1.8" fill="currentColor" stroke="none"/><path d="M12 11c-3 0-5.5 4-5.5 6 0 2 2 2.5 3 2.2 1-.3 1.5-.7 2.5-.7s1.5.4 2.5.7c1 .3 3-.2 3-2.2 0-2-2.5-6-5.5-6z" fill="currentColor" stroke="none"/>',
    chart: '<path d="M5 20V11M12 20V5M19 20v-6"/>',
    bell: '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
    sliders: '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
    clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  };

  function icon(name, size = 16) {
    return `<svg class="icon" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${PATHS[name] ?? ''}</svg>`;
  }

  function escapeHTML(text) {
    return String(text).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  }

  window.FN = { t, duration, clock, phaseColor, THEMES, THEME_NAMES, PHASE_TITLES, icon, escapeHTML, languages: data.languages, language: data.language };
})();
