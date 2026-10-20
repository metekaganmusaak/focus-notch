// Copies the shared assets from the macOS project so both apps stay in sync:
// pet GIFs, sounds, the app icon, and translations (Localizable.xcstrings → one JSON per language).
import { copyFileSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const resources = join(root, '..', 'macos', 'FocusNotch', 'Resources');
const assets = join(root, 'assets');

function copyDir(from, to, filter) {
  rmSync(to, { recursive: true, force: true });
  mkdirSync(to, { recursive: true });
  const files = readdirSync(from).filter(filter);
  for (const file of files) copyFileSync(join(from, file), join(to, file));
  return files.length;
}

const pets = copyDir(join(resources, 'Pets'), join(assets, 'pets'), (f) => f.endsWith('.gif'));
const sounds = copyDir(join(resources, 'Sounds'), join(assets, 'sounds'), (f) => f.endsWith('.wav'));

const icons = join(resources, 'Assets.xcassets', 'AppIcon.appiconset');
mkdirSync(join(root, 'build'), { recursive: true });
copyFileSync(join(icons, 'icon_512x512@2x.png'), join(root, 'build', 'icon.png'));
copyFileSync(join(icons, 'icon_256x256@1x.png'), join(assets, 'icon.png'));
copyFileSync(join(icons, 'icon_16x16@2x.png'), join(assets, 'tray.png'));

const catalog = JSON.parse(readFileSync(join(resources, 'Localizable.xcstrings'), 'utf8'));
const locales = {};
for (const [key, entry] of Object.entries(catalog.strings)) {
  for (const [language, localization] of Object.entries(entry.localizations ?? {})) {
    const value = localization.stringUnit?.value;
    if (value) (locales[language] ??= {})[key] = value;
  }
}
const localesDir = join(assets, 'locales');
rmSync(localesDir, { recursive: true, force: true });
mkdirSync(localesDir, { recursive: true });
for (const [language, strings] of Object.entries(locales)) {
  writeFileSync(join(localesDir, `${language}.json`), JSON.stringify(strings, null, 1));
}

console.log(`Synced ${pets} pet GIFs, ${sounds} sounds, ${Object.keys(locales).length} languages.`);
