// Persists settings, statistics, topics and custom pets in one JSON file in the user data folder.
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_SETTINGS = {
  focusMinutes: 25,
  shortBreakMinutes: 5,
  longBreakMinutes: 15,
  sessionsBeforeLongBreak: 4,
  autoStartBreaks: true,
  autoStartFocus: true,
  reminderLeadMinutes: 5,
  notificationsEnabled: true,
  soundEnabled: true,
  showPet: true,
  petSoundsEnabled: true,
  selectedPetID: 'cat',
  petStyle: 'cute',
  theme: 'coral',
  currentTopicID: null,
  language: '',
  /// Horizontal position of the notch as a fraction of the screen width, or null for the default.
  notchPosition: null,
};

function dayKey(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

class Store {
  constructor(directory) {
    this.file = path.join(directory, 'focus-notch.json');
    let data = {};
    try {
      data = JSON.parse(fs.readFileSync(this.file, 'utf8'));
    } catch {
      // First launch or unreadable file: start fresh.
    }
    this.settings = { ...DEFAULT_SETTINGS, ...data.settings };
    this.days = data.days ?? {};
    this.topics = data.topics ?? [];
    this.customPets = data.customPets ?? [];
    this.saveTimer = null;
  }

  save() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.flush(), 300);
  }

  flush() {
    clearTimeout(this.saveTimer);
    const { settings, days, topics, customPets } = this;
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.writeFileSync(this.file, JSON.stringify({ settings, days, topics, customPets }));
  }

  setSetting(key, value) {
    if (!(key in DEFAULT_SETTINGS)) return false;
    this.settings[key] = value;
    this.save();
    return true;
  }

  // Statistics

  get today() {
    return this.days[dayKey()] ?? { sessions: 0, focusSeconds: 0, topics: {} };
  }

  addFocus(seconds, completedSession, topicID) {
    const key = dayKey();
    const day = this.days[key] ?? { sessions: 0, focusSeconds: 0, topics: {} };
    day.focusSeconds += seconds;
    if (completedSession) day.sessions += 1;
    if (topicID) {
      const totals = (day.topics[topicID] ??= { sessions: 0, focusSeconds: 0 });
      totals.focusSeconds += seconds;
      if (completedSession) totals.sessions += 1;
    }
    this.days[key] = day;
    this.save();
  }

  resetToday() {
    delete this.days[dayKey()];
    this.save();
  }

  selectedDays(period) {
    if (period === 'allTime') return Object.values(this.days);
    const count = period === 'week' ? 7 : 1;
    const result = [];
    for (let offset = 0; offset < count; offset++) {
      const date = new Date();
      date.setDate(date.getDate() - offset);
      const day = this.days[dayKey(date)];
      if (day) result.push(day);
    }
    return result;
  }

  /// Totals and per-topic rows for a period. Time logged under deleted topics counts as no topic.
  statistics(period) {
    const known = new Set(this.topics.map((topic) => topic.id));
    const totals = { sessions: 0, focusSeconds: 0 };
    const byTopic = {};
    const untracked = { sessions: 0, focusSeconds: 0 };
    for (const day of this.selectedDays(period)) {
      totals.sessions += day.sessions;
      totals.focusSeconds += day.focusSeconds;
      let trackedSessions = 0;
      let trackedSeconds = 0;
      for (const [id, entry] of Object.entries(day.topics ?? {})) {
        if (!known.has(id)) continue;
        const row = (byTopic[id] ??= { sessions: 0, focusSeconds: 0 });
        row.sessions += entry.sessions;
        row.focusSeconds += entry.focusSeconds;
        trackedSessions += entry.sessions;
        trackedSeconds += entry.focusSeconds;
      }
      untracked.sessions += day.sessions - trackedSessions;
      untracked.focusSeconds += day.focusSeconds - trackedSeconds;
    }
    const rows = Object.entries(byTopic).map(([topicID, entry]) => ({ topicID, ...entry }));
    if (untracked.focusSeconds >= 1) rows.push({ topicID: null, ...untracked });
    rows.sort((a, b) => b.focusSeconds - a.focusSeconds);
    return { totals, rows };
  }

  // Topics

  addTopic(rawName) {
    const name = String(rawName ?? '').trim().slice(0, 40);
    if (!name) return null;
    const existing = this.topics.find((topic) => topic.name.localeCompare(name, undefined, { sensitivity: 'accent' }) === 0);
    if (existing) return existing;
    const topic = { id: randomUUID(), name };
    this.topics.push(topic);
    this.save();
    return topic;
  }

  removeTopic(id) {
    this.topics = this.topics.filter((topic) => topic.id !== id);
    if (this.settings.currentTopicID === id) this.settings.currentTopicID = null;
    this.save();
  }
}

module.exports = { Store, DEFAULT_SETTINGS };
