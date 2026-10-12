/*
 * Copyright (C) 2026 SFG545
 *
 * This file is part of Orchard.
 *
 * Orchard is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Orchard is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

import { concatBytes, hexToBytes, writeU16, writeU24 } from '../../src/bytes.js';
import { QOBUZ_CMAF_UUIDS } from '../../src/cmaf.js';

function writeU32(data, offset, value) {
  new DataView(data.buffer).setUint32(offset, value, false);
}

function box(type, ...parts) {
  const content = concatBytes(parts);
  const header = new Uint8Array(8);
  writeU32(header, 0, 8 + content.length);
  header.set([...type].map((character) => character.charCodeAt(0)), 4);
  return concatBytes([header, content]);
}

export function initSegment(lengths) {
  const flac = new Uint8Array(42);
  flac.set([0x66, 0x4c, 0x61, 0x43]);
  writeU24(flac, 5, 34);
  writeU16(flac, 8, 4096);
  writeU16(flac, 10, 4096);
  const packed = (44100n << 44n) | (1n << 41n) | (15n << 36n) | BigInt(lengths.length * 4096);
  new DataView(flac.buffer).setBigUint64(18, packed, false);
  const length = new Uint8Array(2);
  writeU16(length, 0, flac.length);
  const table = new Uint8Array(3 + lengths.length * 8);
  writeU16(table, 1, lengths.length);
  lengths.forEach((size, index) => {
    writeU32(table, 3 + index * 8, size);
    writeU32(table, 7 + index * 8, 4096);
  });
  return box('uuid', hexToBytes(QOBUZ_CMAF_UUIDS.init), new Uint8Array(26), length, flac, table);
}

export function audioSegment(frames, tail = new Uint8Array()) {
  const descriptor = new Uint8Array(12 + frames.length * 24);
  writeU32(descriptor, 4, 8 + 16 + descriptor.length + 8);
  descriptor[8] = 16;
  writeU24(descriptor, 9, frames.length);
  frames.forEach(({ data, flags = 0, iv = new Uint8Array(16) }, index) => {
    const offset = 12 + index * 24;
    writeU32(descriptor, offset, data.length);
    writeU16(descriptor, offset + 6, flags);
    descriptor.set(iv, offset + 8);
  });
  return concatBytes([
    box('uuid', hexToBytes(QOBUZ_CMAF_UUIDS.segment), descriptor),
    box('mdat', ...frames.map(({ data }) => data), tail)
  ]);
}

export function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

export const response = (data, status = 200) => ({
  ok: status === 200, status, arrayBuffer: async () => data
});
