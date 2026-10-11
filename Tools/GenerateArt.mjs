// The addon's art, drawn from scratch: the footer's heart, the eye (white,
// tinted in game) and the icon for the AddOns list. Supersampled,
// uncompressed 32-bit TGA with the origin at the top left.
// Run from the addon's folder with: node Tools/GenerateArt.mjs
import { writeFileSync } from 'node:fs';

// Draws size x size pixels; sample(x, y) gives [r, g, b, a] (0 to 1) at a
// point, taken ss x ss times a pixel and averaged.
function render(name, size, sample, ss = 4) {
  const data = Buffer.alloc(18 + size * size * 4);
  data[2] = 2; // uncompressed true colour
  data.writeUInt16LE(size, 12);
  data.writeUInt16LE(size, 14);
  data[16] = 32;
  data[17] = 0x28; // 8 alpha bits, top-left origin
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < ss; sy++) {
        for (let sx = 0; sx < ss; sx++) {
          const c = sample(x + (sx + .5) / ss, y + (sy + .5) / ss);
          r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
        }
      }
      if (a > 0) { r /= a; g /= a; b /= a; }
      const byte = v => Math.max(0, Math.min(255, Math.round(v * 255)));
      const at = 18 + (y * size + x) * 4;
      data[at] = byte(b);
      data[at + 1] = byte(g);
      data[at + 2] = byte(r);
      data[at + 3] = byte(a / (ss * ss));
    }
  }
  writeFileSync(new URL(`../Media/${name}.tga`, import.meta.url), data);
}

const CLEAR = [0, 0, 0, 0];
const WHITE = [1, 1, 1, 1];

// The heart: the curve (x² + y² - 1)³ = x² y³, filling a 32 pixel square.
function heart(x, y, size) {
  const u = (x - size / 2) / (size * .36);
  const v = -(y - size * .54) / (size * .36);
  const k = u * u + v * v - 1;
  return k * k * k - u * u * v * v * v <= 0;
}
render('Heart', 32, (x, y) => heart(x, y, 32) ? WHITE : CLEAR);

// The eye: an almond outline and a round middle, in a 64 x 40 band
// (rows 12 to 52) of a 64 pixel square, as Eye.lua crops it.
function eye(x, y, left, top, width, height, stroke) {
  const u = (x - left) / width * 2 - 1; // -1 to 1 across
  const v = (y - top) / height * 2 - 1; // -1 to 1 down
  if (Math.abs(u) > 1) return 0;
  const lid = Math.pow(1 - u * u, .8); // the lid's half height at u, 0 to 1
  const edge = Math.abs(Math.abs(v) - lid) * height / 2; // pixels from the lid
  const middle = Math.hypot((x - left - width / 2), (y - top - height / 2)) <= height * .2;
  return edge <= stroke / 2 || middle ? 1 : 0;
}
render('Eye', 64, (x, y) => eye(x, y, 2, 13, 60, 38, 4.2) ? WHITE : CLEAR);

// The icon: the eye in the family purple on a dark rounded square.
const PURPLE = [0xb0 / 255, 0x7d / 255, 0xf0 / 255, 1];
const DARK = [0x0e / 255, 0x10 / 255, 0x14 / 255, 1];
function rounded(x, y, size, radius) {
  const cx = Math.min(Math.max(x, radius), size - radius);
  const cy = Math.min(Math.max(y, radius), size - radius);
  return Math.hypot(x - cx, y - cy) <= radius;
}
render('Icon', 64, (x, y) => {
  if (!rounded(x, y, 64, 12)) return CLEAR;
  if (!rounded(x - 2, y - 2, 60, 10)) return PURPLE;
  return eye(x, y, 8, 20, 48, 24, 3.6) ? PURPLE : DARK;
});
