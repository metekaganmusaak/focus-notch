// Bundled pets (same art as the macOS app) plus GIFs the user added.
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const MOODS = ['idle', 'focus', 'rest', 'celebrate'];
const PIXEL_PETS = ['cat', 'dog', 'bunny', 'fox', 'panda', 'frog'];
const CUTE_ONLY_PETS = ['hamster', 'penguin', 'owl', 'koala', 'duck', 'hedgehog'];
const NAMES = {
  cat: 'Cat', dog: 'Dog', bunny: 'Bunny', fox: 'Fox', panda: 'Panda', frog: 'Frog',
  hamster: 'Hamster', penguin: 'Penguin', owl: 'Owl', koala: 'Koala', duck: 'Duck', hedgehog: 'Hedgehog',
};

const fileURL = (file) => pathToFileURL(file).href;

/// The pets for a style. IDs are shared between styles so a choice survives a style
/// switch; the pixel style only has the first six animals.
function listPets({ style, assets, customDirectory, customPets, t }) {
  const ids = style === 'pixel' ? PIXEL_PETS : [...PIXEL_PETS, ...CUTE_ONLY_PETS];
  const builtIn = ids.map((id) => {
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
  const custom = customPets.map((pet) => {
    const url = fileURL(path.join(customDirectory, pet.fileName));
    return {
      id: pet.id,
      name: pet.name,
      isCustom: true,
      pixel: false,
      urls: Object.fromEntries(MOODS.map((mood) => [mood, url])),
      sound: null,
    };
  });
  return [...builtIn, ...custom];
}

/// Copies a GIF into the user data folder. Returns the new record, or null if it isn't a GIF.
function importGIF(file, customDirectory) {
  const header = Buffer.alloc(6);
  const handle = fs.openSync(file, 'r');
  try {
    fs.readSync(handle, header, 0, 6, 0);
  } finally {
    fs.closeSync(handle);
  }
  if (!header.toString('ascii').startsWith('GIF8')) return null;
  const id = `custom-${randomUUID()}`;
  const fileName = `${id}.gif`;
  fs.mkdirSync(customDirectory, { recursive: true });
  fs.copyFileSync(file, path.join(customDirectory, fileName));
  return { id, name: path.basename(file, path.extname(file)).slice(0, 40), fileName };
}

function removeCustomPet(record, customDirectory) {
  fs.rmSync(path.join(customDirectory, record.fileName), { force: true });
}

module.exports = { listPets, importGIF, removeCustomPet };
