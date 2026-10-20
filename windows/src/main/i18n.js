// Translations come from the macOS String Catalog (synced to assets/locales). Keys are
// the English strings; format specifiers (%@, %lld, %1$@ …) follow the Apple conventions.
const fs = require('node:fs');
const path = require('node:path');

const LANGUAGES = [
  'en', 'zh-Hans', 'zh-Hant', 'hi', 'es', 'fr', 'ar', 'bn', 'pt-BR', 'ru', 'ur',
  'id', 'de', 'ja', 'tr', 'ko', 'vi', 'it', 'fa', 'pl', 'uk', 'th', 'nl',
];
const RTL = new Set(['ar', 'fa', 'ur']);

/// Picks the best supported language for a list of BCP 47 tags, most preferred first.
function resolveLanguage(preferred) {
  for (const tag of preferred) {
    const lower = tag.toLowerCase();
    if (lower.startsWith('zh')) {
      return /hant|tw|hk|mo/.test(lower) ? 'zh-Hant' : 'zh-Hans';
    }
    if (lower.startsWith('pt')) return 'pt-BR';
    const exact = LANGUAGES.find((code) => code.toLowerCase() === lower);
    if (exact) return exact;
    const base = LANGUAGES.find((code) => code === lower.split('-')[0]);
    if (base) return base;
  }
  return 'en';
}

function format(template, args) {
  let next = 0;
  return template.replace(/%(?:(\d+)\$)?(@|lld|d)/g, (_, position) => {
    const index = position ? Number(position) - 1 : next++;
    return String(args[index] ?? '');
  });
}

class I18n {
  constructor(localesDirectory, language) {
    this.language = language;
    this.rtl = RTL.has(language);
    this.strings = {};
    if (language !== 'en') {
      try {
        this.strings = JSON.parse(fs.readFileSync(path.join(localesDirectory, `${language}.json`), 'utf8'));
      } catch {
        this.strings = {};
      }
    }
  }

  t(key, ...args) {
    return format(this.strings[key] ?? key, args);
  }

  /// "5 minutes" / "1 hr, 30 min" in the app language.
  duration(seconds, style = 'long') {
    const total = Math.max(Math.round(seconds / 60), 0);
    const parts = total >= 60 ? { hours: Math.floor(total / 60), minutes: total % 60 } : { minutes: total };
    if (parts.minutes === 0 && parts.hours) delete parts.minutes;
    try {
      // Zero units are hidden by default, which would turn "0 min" into an empty string.
      const options = total === 0 ? { style, minutesDisplay: 'always' } : { style };
      return new Intl.DurationFormat(this.language, options).format(parts);
    } catch {
      return parts.hours ? `${parts.hours} h ${parts.minutes ?? 0} min` : `${parts.minutes} min`;
    }
  }
}

module.exports = { I18n, LANGUAGES, resolveLanguage, format };
