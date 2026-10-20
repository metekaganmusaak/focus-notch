// Drives the focus → break → focus cycle. A port of PomodoroEngine.swift: time is
// tracked against an end date, so the countdown stays correct across sleep.
const { EventEmitter } = require('node:events');

class PomodoroEngine extends EventEmitter {
  constructor(store) {
    super();
    this.store = store;
    this.phase = 'focus';
    this.state = 'idle';
    this.remaining = 0;
    this.phaseDuration = 0;
    this.completedInCycle = 0;
    this.isSessionActive = false;
    this.endDate = null;
    this.ticker = null;
    this.hasWarnedNextSession = false;
    this.sessionFocusTime = 0;
    this.sessionCompleted = 0;
    this.load('focus');
  }

  get settings() {
    return this.store.settings;
  }

  get isRunning() {
    return this.state === 'running';
  }

  get progress() {
    return this.phaseDuration > 0 ? Math.min(Math.max(1 - this.remaining / this.phaseDuration, 0), 1) : 0;
  }

  get isPristine() {
    return this.state === 'idle' && this.remaining === this.phaseDuration;
  }

  get nextPhase() {
    if (this.phase !== 'focus') return 'focus';
    return this.completedInCycle + 1 >= this.settings.sessionsBeforeLongBreak ? 'longBreak' : 'shortBreak';
  }

  duration(phase) {
    const minutes = {
      focus: this.settings.focusMinutes,
      shortBreak: this.settings.shortBreakMinutes,
      longBreak: this.settings.longBreakMinutes,
    }[phase];
    return minutes * 60;
  }

  // Controls

  start() {
    if (this.state === 'running') return;
    this.endDate = Date.now() + this.remaining * 1000;
    this.state = 'running';
    this.isSessionActive = true;
    clearInterval(this.ticker);
    this.ticker = setInterval(() => this.tick(), 250);
    this.changed();
  }

  pause() {
    if (this.state !== 'running') return;
    this.remaining = this.currentRemaining;
    this.stopTicker();
    this.state = 'paused';
    this.changed();
  }

  toggle() {
    this.isRunning ? this.pause() : this.start();
  }

  skip() {
    const wasRunning = this.isRunning;
    if (this.phase === 'focus') this.recordPartialFocus();
    if (this.phase === 'longBreak') this.completedInCycle = 0;
    const next = this.nextPhase;
    this.stopTicker();
    this.state = 'idle';
    this.load(next);
    if (wasRunning) this.start();
    this.changed();
  }

  reset() {
    this.stopTicker();
    this.state = 'idle';
    this.load(this.phase);
    this.changed();
  }

  finish() {
    if (this.phase === 'focus' && this.state !== 'idle') this.recordPartialFocus();
    const wasActive = this.isSessionActive;
    const focusTime = this.sessionFocusTime;
    const sessions = this.sessionCompleted;
    this.stopTicker();
    this.state = 'idle';
    this.completedInCycle = 0;
    this.isSessionActive = false;
    this.sessionFocusTime = 0;
    this.sessionCompleted = 0;
    this.load('focus');
    this.changed();
    if (wasActive) this.emit('event', { type: 'finished', focusTime, sessions });
  }

  /// Durations changed in settings; apply them right away unless a timer is in flight.
  settingsDidChange() {
    if (this.state === 'idle') {
      this.load(this.phase);
      this.changed();
    }
  }

  // Internals

  get leadTime() {
    return this.settings.reminderLeadMinutes * 60;
  }

  get currentRemaining() {
    if (this.state !== 'running' || this.endDate === null) return this.remaining;
    return Math.max((this.endDate - Date.now()) / 1000, 0);
  }

  tick() {
    if (this.state !== 'running') return;
    const left = this.currentRemaining;
    const shown = Math.ceil(left);
    if (shown !== this.remaining) {
      this.remaining = shown;
      this.changed();
    }
    if (this.phase !== 'focus' && !this.hasWarnedNextSession && left > 0 && left <= this.leadTime) {
      this.hasWarnedNextSession = true;
      this.emit('event', { type: 'nextSessionSoon', remaining: shown });
    }
    if (left <= 0) this.completePhase();
  }

  completePhase() {
    this.stopTicker();
    this.state = 'idle';
    if (this.phase === 'focus') {
      this.completedInCycle += 1;
      this.sessionCompleted += 1;
      this.sessionFocusTime += this.phaseDuration;
      this.store.addFocus(this.phaseDuration, true, this.settings.currentTopicID);
      const next = this.completedInCycle >= this.settings.sessionsBeforeLongBreak ? 'longBreak' : 'shortBreak';
      const autoStart = this.settings.autoStartBreaks;
      this.load(next);
      if (autoStart) this.start();
      this.changed();
      this.emit('event', { type: 'focusCompleted', next, autoStarted: autoStart });
    } else {
      if (this.phase === 'longBreak') this.completedInCycle = 0;
      const autoStart = this.settings.autoStartFocus;
      this.load('focus');
      if (autoStart) this.start();
      this.changed();
      this.emit('event', { type: 'breakCompleted', autoStarted: autoStart });
    }
  }

  load(phase) {
    this.phase = phase;
    this.phaseDuration = this.duration(phase);
    this.remaining = this.phaseDuration;
    // A break no longer than the reminder lead time is announced together with
    // its next session when it begins, so it doesn't get a separate reminder.
    this.hasWarnedNextSession = phase !== 'focus' && this.phaseDuration <= this.leadTime;
  }

  recordPartialFocus() {
    const elapsed = this.phaseDuration - this.currentRemaining;
    if (elapsed < 60) return;
    this.sessionFocusTime += elapsed;
    this.store.addFocus(elapsed, false, this.settings.currentTopicID);
  }

  stopTicker() {
    clearInterval(this.ticker);
    this.ticker = null;
    this.endDate = null;
  }

  changed() {
    this.emit('change');
  }

  snapshot() {
    return {
      phase: this.phase,
      state: this.state,
      remaining: this.remaining,
      phaseDuration: this.phaseDuration,
      progress: this.progress,
      completedInCycle: this.completedInCycle,
      sessionsPerCycle: this.settings.sessionsBeforeLongBreak,
      isSessionActive: this.isSessionActive,
      isPristine: this.isPristine,
    };
  }
}

module.exports = { PomodoroEngine };
