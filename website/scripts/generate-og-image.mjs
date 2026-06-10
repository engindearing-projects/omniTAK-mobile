#!/usr/bin/env node
/**
 * Regenerates public/og-image.png (1200x630) from the Engindearing brand kit.
 *
 * Brand: Emerald #3E9E66, Indigo #1A1267, dark og background #1A1A1A
 * (see ~/engindearing/brand/README.md). Mark source: public/brand/crt_mark_white.svg.
 *
 * Requires librsvg's rsvg-convert on PATH (brew install librsvg).
 * Usage: node scripts/generate-og-image.mjs
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const W = 1200;
const H = 630;

const EMERALD = "#3E9E66";
const INDIGO = "#1A1267";
const DARK = "#1A1A1A";

const work = mkdtempSync(join(tmpdir(), "og-image-"));
try {
  // Render the white CRT mark to PNG so it can be data-URI embedded.
  const markPng = join(work, "mark.png");
  execFileSync("rsvg-convert", [
    "-h", "300",
    "-o", markPng,
    join(root, "public", "brand", "crt_mark_white.svg"),
  ]);
  const markB64 = readFileSync(markPng).toString("base64");

  const mono = "Menlo, 'JetBrains Mono', 'DejaVu Sans Mono', monospace";

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <radialGradient id="indigoGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="${INDIGO}" stop-opacity="0.85"/>
      <stop offset="55%" stop-color="${INDIGO}" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="${INDIGO}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="${DARK}"/>

  <!-- subtle indigo glow, lower right -->
  <circle cx="1080" cy="560" r="460" fill="url(#indigoGlow)"/>

  <!-- faint grid -->
  <g stroke="${EMERALD}" stroke-width="1" opacity="0.07">
    ${Array.from({ length: 19 }, (_, i) => `<line x1="${(i + 1) * 60}" y1="0" x2="${(i + 1) * 60}" y2="${H}"/>`).join("\n    ")}
    ${Array.from({ length: 10 }, (_, i) => `<line x1="0" y1="${(i + 1) * 60}" x2="${W}" y2="${(i + 1) * 60}"/>`).join("\n    ")}
  </g>

  <!-- emerald accent rail -->
  <rect x="0" y="0" width="14" height="${H}" fill="${EMERALD}"/>

  <!-- CRT mark -->
  <image x="78" y="110" width="232" height="223" href="data:image/png;base64,${markB64}"/>

  <!-- wordmark -->
  <text x="80" y="410" font-family="${mono}" font-size="64" font-weight="bold" fill="#FFFFFF" letter-spacing="1">OmniTAK</text>

  <!-- tagline -->
  <text x="80" y="478" font-family="${mono}" font-size="40" font-weight="bold" fill="${EMERALD}">Open-source TAK client for iOS + Android</text>

  <!-- subline -->
  <text x="80" y="534" font-family="${mono}" font-size="26" fill="#C9C9C9">Live on the App Store &#183; Apache 2.0 &#183; by Engindearing</text>

  <!-- url -->
  <text x="80" y="586" font-family="${mono}" font-size="22" fill="#8A8A8A">omnitak.engindearing.soy</text>
</svg>`;

  const svgPath = join(work, "og.svg");
  writeFileSync(svgPath, svg);
  execFileSync("rsvg-convert", [
    "-w", String(W),
    "-h", String(H),
    "-o", join(root, "public", "og-image.png"),
    svgPath,
  ]);
  console.log("wrote public/og-image.png");
} finally {
  rmSync(work, { recursive: true, force: true });
}
