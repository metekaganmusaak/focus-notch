// Turns the images a user picks for a custom pet into small looping GIFs.
// Animated GIFs are kept as they are. Every other image can lose a flat background
// and gets the same motion per mood as the bundled cute pets. Port of PetGIFMaker.swift; keep the two in sync.
(() => {
  const CANVAS = 160;
  const SPARKLE_COLORS = ['#ffd65e', '#ffffff', '#ff8fb8', '#73ebbf'];
  const TIMING = { idle: [16, 0.1], focus: [8, 0.11], rest: [16, 0.14], celebrate: [12, 0.07] };

  function motion(mood, index, frames, pose) {
    const phase = index / frames;
    const wave = Math.sin(phase * 2 * Math.PI);
    const maxX = pose.x + pose.width, maxY = pose.y + pose.height;
    switch (mood) {
      case 'idle':
        // Slow breathing.
        return { dy: 0, scaleX: 1 - 0.01 * wave, scaleY: 1 + 0.022 * wave };
      case 'focus':
        // A light bounce, as if typing.
        return { dy: index % 2 === 0 ? 0 : -1.2, scaleX: 1, scaleY: 1 + 0.012 * wave };
      case 'rest': {
        // Deep breathing with two z's drifting up.
        const start = { x: Math.min(maxX - pose.width * 0.22, CANVAS - 34), y: Math.max(pose.y - 2, 30) };
        const zs = [0, 0.5].map((offset) => {
          const t = (phase + offset) % 1;
          return { x: start.x + 14 * t, y: start.y - 26 * t, size: 7 + 8 * t };
        });
        return { dy: 0, scaleX: 1 - 0.012 * wave, scaleY: 1 + 0.03 * wave, zs };
      }
      default: {
        // Hop with squash and stretch, surrounded by twinkling sparkles.
        const heights = [0, -4, -10, -14, -16, -16, -14, -10, -5, 0, 0, 0];
        const squash = [0.93, 1.04, 1.02, 1, 1, 1, 1, 1.01, 1.02, 0.94, 0.98, 1];
        const spots = [[pose.x + 4, pose.y + 12], [maxX - 2, pose.y + 22], [pose.x + 2, maxY - 34], [maxX - 4, maxY - 22]];
        const sparkles = spots.map(([x, y], k) => ({
          x: Math.min(Math.max(x, 8), CANVAS - 8),
          y: Math.min(Math.max(y, 8), CANVAS - 8),
          radius: 2.5 + 4 * Math.abs(Math.sin((phase * 2 + k * 0.25) * Math.PI)),
          color: SPARKLE_COLORS[k],
        }));
        return { dy: heights[index], scaleX: 2 - squash[index], scaleY: squash[index], sparkles };
      }
    }
  }

  /// One frame as premultiplied RGBA, like CoreGraphics produces on macOS.
  function render(context, image, pose, step, pixelArt) {
    context.clearRect(0, 0, CANVAS, CANVAS);
    context.imageSmoothingEnabled = !pixelArt;
    context.imageSmoothingQuality = 'high';
    context.save();
    context.translate(pose.x + pose.width / 2, pose.y + pose.height + step.dy);
    context.scale(step.scaleX, step.scaleY);
    context.drawImage(image, -pose.width / 2, -pose.height, pose.width, pose.height);
    context.restore();

    for (const z of step.zs ?? []) {
      context.strokeStyle = 'rgb(191, 217, 255)';
      context.lineWidth = z.size * 0.24;
      context.lineCap = 'round';
      context.lineJoin = 'round';
      context.beginPath();
      context.moveTo(z.x, z.y);
      context.lineTo(z.x + z.size, z.y);
      context.lineTo(z.x, z.y + z.size);
      context.lineTo(z.x + z.size, z.y + z.size);
      context.stroke();
    }
    for (const sparkle of step.sparkles ?? []) {
      context.beginPath();
      context.moveTo(sparkle.x, sparkle.y - sparkle.radius);
      for (let k = 1; k < 8; k++) {
        const angle = (k * Math.PI) / 4 - Math.PI / 2;
        const length = k % 2 === 0 ? sparkle.radius : sparkle.radius * 0.3;
        context.lineTo(sparkle.x + Math.cos(angle) * length, sparkle.y + Math.sin(angle) * length);
      }
      context.closePath();
      context.fillStyle = sparkle.color;
      context.fill();
    }

    const pixels = context.getImageData(0, 0, CANVAS, CANVAS).data;
    for (let i = 0; i < pixels.length; i += 4) {
      const alpha = pixels[i + 3] / 255;
      pixels[i] = Math.round(pixels[i] * alpha);
      pixels[i + 1] = Math.round(pixels[i + 1] * alpha);
      pixels[i + 2] = Math.round(pixels[i + 2] * alpha);
    }
    return pixels;
  }

  // MARK: - Color quantization

  /// Median-cut palette over 5-bit color buckets, shared by every frame. Index 0 is
  /// transparent; pixels below the alpha threshold use it.
  function quantize(frames, alphaThreshold = 102) {
    const keyAt = (p, i) => ((p[i] >> 3) << 10) | ((p[i + 1] >> 3) << 5) | (p[i + 2] >> 3);
    const buckets = new Map();
    for (const frame of frames) {
      for (let i = 0; i < frame.length; i += 4) {
        if (frame[i + 3] < alphaThreshold) continue;
        const key = keyAt(frame, i);
        let bucket = buckets.get(key);
        if (!bucket) buckets.set(key, (bucket = { key, count: 0, r: 0, g: 0, b: 0 }));
        bucket.count++;
        bucket.r += frame[i];
        bucket.g += frame[i + 1];
        bucket.b += frame[i + 2];
      }
    }
    for (const bucket of buckets.values()) bucket.mean = [bucket.r / bucket.count, bucket.g / bucket.count, bucket.b / bucket.count];

    const longestAxis = (box) => [0, 1, 2]
      .map((axis) => {
        const values = box.map((bucket) => bucket.mean[axis]);
        return { axis, range: Math.max(...values) - Math.min(...values) };
      })
      .reduce((best, next) => (next.range > best.range ? next : best));
    const total = (box) => box.reduce((sum, bucket) => sum + bucket.count, 0);

    const boxes = buckets.size ? [[...buckets.values()]] : [];
    while (boxes.length < 255) {
      let index = -1, score = 0;
      boxes.forEach((box, i) => {
        if (box.length < 2) return;
        const value = longestAxis(box).range * total(box);
        if (value > score) { score = value; index = i; }
      });
      if (index < 0) break;
      const [box] = boxes.splice(index, 1);
      const { axis } = longestAxis(box);
      const sorted = box.sort((a, b) => a.mean[axis] - b.mean[axis]);
      const count = total(sorted);
      let running = 0, split = 1;
      for (let i = 0; i < sorted.length; i++) {
        running += sorted[i].count;
        if (running * 2 >= count) { split = Math.max(1, Math.min(i + 1, sorted.length - 1)); break; }
      }
      boxes.push(sorted.slice(0, split), sorted.slice(split));
    }

    const colors = boxes.map((box) => {
      const count = total(box);
      return [box.reduce((s, b) => s + b.r, 0) / count, box.reduce((s, b) => s + b.g, 0) / count, box.reduce((s, b) => s + b.b, 0) / count];
    });
    const lookup = new Map();
    for (const bucket of buckets.values()) {
      let best = 0, bestDistance = Infinity;
      colors.forEach((color, index) => {
        const distance = (color[0] - bucket.mean[0]) ** 2 + (color[1] - bucket.mean[1]) ** 2 + (color[2] - bucket.mean[2]) ** 2;
        if (distance < bestDistance) { bestDistance = distance; best = index; }
      });
      lookup.set(bucket.key, best + 1);
    }

    const palette = [[0, 0, 0], ...colors.map((color) => color.map(Math.round))];
    const indexed = frames.map((frame) => {
      const out = new Uint8Array(frame.length / 4);
      for (let i = 0, j = 0; i < frame.length; i += 4, j++) {
        out[j] = frame[i + 3] >= alphaThreshold ? lookup.get(keyAt(frame, i)) : 0;
      }
      return out;
    });
    return { palette, frames: indexed };
  }

  // MARK: - GIF encoding

  const littleEndian = (value) => [value & 0xff, (value >> 8) & 0xff];

  /// GIF-flavoured LZW with variable code sizes.
  function lzw(indices, minCodeSize) {
    const clearCode = 1 << minCodeSize;
    const endCode = clearCode + 1;
    let nextCode = endCode + 1;
    let codeSize = minCodeSize + 1;
    let table = new Map();
    const output = [];
    let buffer = 0, bufferedBits = 0;

    const emit = (code) => {
      buffer |= code << bufferedBits;
      bufferedBits += codeSize;
      while (bufferedBits >= 8) {
        output.push(buffer & 0xff);
        buffer >>= 8;
        bufferedBits -= 8;
      }
    };

    emit(clearCode);
    let prefix = indices[0];
    for (let i = 1; i < indices.length; i++) {
      const k = indices[i];
      const key = (prefix << 8) | k;
      const code = table.get(key);
      if (code !== undefined) {
        prefix = code;
        continue;
      }
      emit(prefix);
      if (nextCode === 4096) {
        emit(clearCode);
        nextCode = endCode + 1;
        codeSize = minCodeSize + 1;
        table = new Map();
      } else {
        if (nextCode >= 1 << codeSize) codeSize++;
        table.set(key, nextCode++);
      }
      prefix = k;
    }
    emit(prefix);
    emit(endCode);
    if (bufferedBits > 0) output.push(buffer & 0xff);
    return output;
  }

  /// A looping GIF where index 0 is transparent and every frame clears to the
  /// background, so transparent pixels never show the previous frame.
  function encodeGIF(width, height, palette, frames, delay) {
    const colors = palette.slice();
    let bits = 2;
    while (1 << bits < colors.length) bits++;
    while (colors.length < 1 << bits) colors.push([0, 0, 0]);

    const out = [...'GIF89a'].map((c) => c.charCodeAt(0));
    out.push(...littleEndian(width), ...littleEndian(height), 0x80 | 0x70 | (bits - 1), 0, 0);
    for (const color of colors) out.push(...color);
    out.push(0x21, 0xff, 0x0b, ...[...'NETSCAPE2.0'].map((c) => c.charCodeAt(0)), 0x03, 0x01, 0x00, 0x00, 0x00);

    const centiseconds = Math.round(delay * 100);
    for (const data of frames) {
      out.push(0x21, 0xf9, 0x04, 0x09, ...littleEndian(centiseconds), 0x00, 0x00);
      out.push(0x2c, 0, 0, 0, 0, ...littleEndian(width), ...littleEndian(height), 0x00, bits);
      const compressed = lzw(data, bits);
      for (let offset = 0; offset < compressed.length; offset += 255) {
        const chunk = compressed.slice(offset, offset + 255);
        out.push(chunk.length);
        for (const byte of chunk) out.push(byte);
      }
      out.push(0);
    }
    out.push(0x3b);
    return new Uint8Array(out);
  }

  // MARK: - Entry point

  /// Walks the GIF blocks and stops at the second image.
  function isAnimatedGIF(bytes) {
    if (bytes.length < 13 || String.fromCharCode(...bytes.subarray(0, 4)) !== 'GIF8') return false;
    const skipSubBlocks = (offset) => {
      while (offset < bytes.length && bytes[offset] !== 0) offset += bytes[offset] + 1;
      return offset + 1;
    };
    const colorTable = (flags) => (flags & 0x80 ? 3 << ((flags & 0x07) + 1) : 0);
    let offset = 13 + colorTable(bytes[10]);
    let images = 0;
    while (offset < bytes.length) {
      const block = bytes[offset];
      if (block === 0x21) {
        offset = skipSubBlocks(offset + 2);
      } else if (block === 0x2c) {
        if (++images > 1) return true;
        offset = skipSubBlocks(offset + 10 + colorTable(bytes[offset + 9]) + 1);
      } else {
        break;
      }
    }
    return false;
  }

  // MARK: - Background removal

  /// How far (RGB distance) a pixel may be from the background color and still count as background.
  const BACKGROUND_TOLERANCE = 48;
  /// Edge pixels up to this much further away get partial transparency.
  const BACKGROUND_SOFTNESS = 72;

  /// When at least three corners share one opaque color, everything of that color
  /// connected to the border becomes transparent, the edges around it are softened,
  /// and the result is cropped to what's left. Null when there's no such background.
  function removingFlatBackground(image) {
    const { width, height } = image;
    const count = width * height;
    const canvas = new OffscreenCanvas(width, height);
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, width, height).data;

    const color = (i) => [pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2]];
    const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

    const corners = [0, width - 1, (height - 1) * width, count - 1];
    if (!corners.every((i) => pixels[i * 4 + 3] > 250)) return null;
    const cornerColors = corners.map(color);
    const matching = cornerColors
      .map((candidate) => cornerColors.filter((other) => distance(other, candidate) < BACKGROUND_TOLERANCE))
      .reduce((best, next) => (next.length > best.length ? next : best));
    if (matching.length < 3) return null;
    const background = [0, 1, 2].map((k) => matching.reduce((sum, c) => sum + c[k], 0) / matching.length);

    // Flood fill from the border through background-colored pixels.
    const removed = new Uint8Array(count);
    const stack = [];
    const visit = (i) => {
      if (!removed[i] && distance(color(i), background) < BACKGROUND_TOLERANCE) {
        removed[i] = 1;
        stack.push(i);
      }
    };
    for (let x = 0; x < width; x++) { visit(x); visit((height - 1) * width + x); }
    for (let y = 0; y < height; y++) { visit(y * width); visit(y * width + width - 1); }
    while (stack.length) {
      const i = stack.pop();
      const x = i % width, y = (i / width) | 0;
      if (x > 0) visit(i - 1);
      if (x < width - 1) visit(i + 1);
      if (y > 0) visit(i - width);
      if (y < height - 1) visit(i + width);
    }
    // A flat image with nothing on it: keep it as it is.
    let kept = 0;
    for (let i = 0; i < count; i++) if (!removed[i]) kept++;
    if (kept <= Math.floor(count / 50)) return null;

    const output = new ImageData(width, height);
    output.data.set(pixels);
    let minX = width, minY = height, maxX = -1, maxY = -1;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const i = y * width + x;
        if (removed[i]) {
          output.data.fill(0, i * 4, i * 4 + 4);
          continue;
        }
        let edge = false;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            const nx = x + dx, ny = y + dy;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height && removed[ny * width + nx]) edge = true;
          }
        }
        if (edge) {
          // Unmix the background from the pixel; canvas pixels aren't premultiplied.
          const p = color(i);
          const alpha = Math.min(Math.max((distance(p, background) - BACKGROUND_TOLERANCE) / BACKGROUND_SOFTNESS, 0), 1);
          for (let k = 0; k < 3; k++) {
            const premultiplied = Math.min(Math.max(p[k] - (1 - alpha) * background[k], 0), 255 * alpha);
            output.data[i * 4 + k] = alpha > 0 ? Math.round(premultiplied / alpha) : 0;
          }
          output.data[i * 4 + 3] = Math.round(255 * alpha);
        }
        if (output.data[i * 4 + 3] > 20) {
          minX = Math.min(minX, x); maxX = Math.max(maxX, x);
          minY = Math.min(minY, y); maxY = Math.max(maxY, y);
        }
      }
    }
    if (maxX < minX) return null;

    const cropped = new OffscreenCanvas(maxX - minX + 1, maxY - minY + 1);
    cropped.getContext('2d').putImageData(output, -minX, -minY);
    return cropped;
  }

  /// GIF bytes for one mood from an image `File`. Throws if the image can't be decoded.
  /// With `removeBackground`, a flat color filling the corners of a still image is made transparent.
  async function gifBytes(file, mood, { removeBackground = true } = {}) {
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (isAnimatedGIF(bytes)) return bytes;

    // Decoding applies the EXIF orientation of camera photos; large images are downsampled first.
    const original = await createImageBitmap(file);
    const shrink = Math.min(1, (CANVAS * 2) / Math.max(original.width, original.height));
    const resized = shrink < 1
      ? await createImageBitmap(original, {
        resizeWidth: Math.max(1, Math.round(original.width * shrink)),
        resizeHeight: Math.max(1, Math.round(original.height * shrink)),
        resizeQuality: 'high',
      })
      : original;
    const image = (removeBackground && removingFlatBackground(resized)) || resized;

    // The celebrate hop needs headroom; tiny images are pixel art and stay crisp.
    const headroom = mood === 'celebrate' ? 18 : 6;
    const scale = Math.min((CANVAS - 12) / image.width, (CANVAS - 4 - headroom) / image.height);
    const width = image.width * scale, height = image.height * scale;
    const pose = { x: (CANVAS - width) / 2, y: CANVAS - 4 - height, width, height };
    const pixelArt = Math.max(image.width, image.height) <= 64;

    const canvas = new OffscreenCanvas(CANVAS, CANVAS);
    const context = canvas.getContext('2d', { willReadFrequently: true });
    const [count, delay] = TIMING[mood] ?? TIMING.idle;
    const frames = [];
    for (let index = 0; index < count; index++) {
      frames.push(render(context, image, pose, motion(mood, index, count, pose), pixelArt));
    }
    const { palette, frames: indexed } = quantize(frames);
    return encodeGIF(CANVAS, CANVAS, palette, indexed, delay);
  }

  window.PetGIFMaker = { gifBytes, MOODS: ['idle', 'focus', 'rest', 'celebrate'] };
})();
