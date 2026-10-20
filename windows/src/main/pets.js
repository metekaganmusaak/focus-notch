// Bundled pets (same art as the macOS app) plus pets the user added, one GIF per mood.
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const MOODS = ['idle', 'focus', 'rest', 'celebrate'];
const ANIMALS = ['cat', 'dog', 'bunny', 'fox', 'panda', 'frog', 'hamster', 'penguin', 'owl', 'koala', 'duck', 'hedgehog'];
const NAMES = {
  cat: 'Cat', dog: 'Dog', bunny: 'Bunny', fox: 'Fox', panda: 'Panda', frog: 'Frog',
  hamster: 'Hamster', penguin: 'Penguin', owl: 'Owl', koala: 'Koala', duck: 'Duck', hedgehog: 'Hedgehog',
};

const fileURL = (file) => pathToFileURL(file).href;

/// The pets for a style. IDs are shared between styles so a choice survives a style switch.
function listPets({ style, assets, customDirectory, customPets, t }) {
  const builtIn = ANIMALS.map((id) => {
    const base = style === 'pixel' ? id : `cute_${id}`;
    const sound = path.join(assets, 'sounds', `pet_${id}.wav`);
    return {
      id,
      name: t(NAMES[id]),
      isCustom: false,
      pixel: style === 'pixel',
      urls: Object.fromEntries(MOODS.map((mood) => [mood, fileURL(path.join(assets, 'pets', `${base}_${mood}.gif`))])),
      sound: fs.existsSync(sound) ? fileURL(sound) : null,
    };
  });
  // Pets added before per-mood images have one `fileName` for every mood.
  const custom = customPets.map((pet) => ({
    id: pet.id,
    name: pet.name,
    isCustom: true,
    pixel: false,
    urls: Object.fromEntries(MOODS.map((mood) => [mood, fileURL(path.join(customDirectory, pet.moodFiles?.[mood] ?? pet.fileName))])),
    sound: null,
  }));
  return [...builtIn, ...custom];
}

const MAX_GIF_BYTES = 50 * 1024 * 1024;

/// Saves the GIFs the settings window made (mood → bytes) into the user data folder.
/// Returns the new record, or null if any of them isn't a GIF.
function addPet(name, gifs, customDirectory) {
  const entries = MOODS.map((mood) => [mood, gifs?.[mood]]);
  const valid = entries.every(([, bytes]) => bytes instanceof Uint8Array && bytes.length > 6 && bytes.length < MAX_GIF_BYTES
    && Buffer.from(bytes.subarray(0, 4)).toString('ascii') === 'GIF8');
  if (!valid) return null;
  const id = `custom-${randomUUID()}`;
  fs.mkdirSync(customDirectory, { recursive: true });
  const moodFiles = {};
  for (const [mood, bytes] of entries) {
    moodFiles[mood] = `${id}_${mood}.gif`;
    fs.writeFileSync(path.join(customDirectory, moodFiles[mood]), bytes);
  }
  return { id, name: String(name ?? '').trim().slice(0, 40) || 'Pet', moodFiles };
}

function removeCustomPet(record, customDirectory) {
  for (const fileName of [record.fileName, ...Object.values(record.moodFiles ?? {})].filter(Boolean)) {
    fs.rmSync(path.join(customDirectory, fileName), { force: true });
  }
}

module.exports = { listPets, addPet, removeCustomPet };
