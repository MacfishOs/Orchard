import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import { afterEach, beforeEach, it, mock } from "node:test";

import { APPLE_DEVELOPER_TOKEN_SECONDS } from "../src/apple.js";
import worker from "../src/index.js";

const NOW = 1792022400;
const PATH = "/apple/developer-token";
const CREDENTIALS = ["APPLE_MUSIC_TEAM_ID", "APPLE_MUSIC_KEY_ID", "APPLE_MUSIC_PRIVATE_KEY"];

let env, publicKey, rateKeys, rateAllowed;

function call({ method = "GET", path = PATH, headers = {} } = {}) {
  return worker.fetch(new Request(`https://account.test${path}`, {
    method, headers: { "cf-connecting-ip": "203.0.113.7", ...headers },
  }), env);
}

function assertSignature(token, key = publicKey) {
  const parts = token.split(".");
  assert.equal(parts.length, 3);
  const signature = Buffer.from(parts[2], "base64url");
  assert.equal(signature.length, 64);
  assert.equal(verify("sha256", Buffer.from(`${parts[0]}.${parts[1]}`), {
    key, dsaEncoding: "ieee-p1363",
  }, signature), true);
}

beforeEach(() => {
  mock.method(Date, "now", () => NOW * 1000);
  const keys = generateKeyPairSync("ec", {
    namedCurve: "prime256v1", privateKeyEncoding: { type: "pkcs8", format: "pem" },
  });
  publicKey = keys.publicKey;
  rateKeys = [];
  rateAllowed = true;
  env = {
    APPLE_MUSIC_TEAM_ID: "TEAM123456",
    APPLE_MUSIC_KEY_ID: "KEY1234567",
    APPLE_MUSIC_PRIVATE_KEY: keys.privateKey,
    AUTH_LIMITER: { async limit({ key }) {
      rateKeys.push(key);
      return { success: rateAllowed };
    } },
  };
});

afterEach(() => mock.restoreAll());

it("issues an Apple ES256 developer token without an Orchard session or database", async () => {
  const response = await call();
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  const body = await response.json();
  assert.deepEqual(Object.keys(body).sort(), ["developer_token", "expires_at"]);
  assert.equal(body.expires_at, NOW + APPLE_DEVELOPER_TOKEN_SECONDS);
  const [header, claims] = body.developer_token.split(".").slice(0, 2).map(part => JSON.parse(Buffer.from(part, "base64url")));
  assert.deepEqual(header, { alg: "ES256", kid: env.APPLE_MUSIC_KEY_ID });
  assert.deepEqual(claims, { iss: env.APPLE_MUSIC_TEAM_ID, iat: NOW, exp: body.expires_at });
  assert.equal(claims.exp - claims.iat, 3600);
  assertSignature(body.developer_token);
});

it("accepts PEM newlines from Wrangler secrets and quoted dotenv values", async () => {
  const pem = env.APPLE_MUSIC_PRIVATE_KEY;
  for (const value of [pem.replace(/\n/g, "\\n"), pem.replace(/\n/g, "\r\n")]) {
    env.APPLE_MUSIC_PRIVATE_KEY = value;
    const response = await call();
    assert.equal(response.status, 200);
    assertSignature((await response.json()).developer_token);
  }
});

it("trims configuration whitespace", async () => {
  for (const name of CREDENTIALS) env[name] = ` \n${env[name]}\n `;
  const response = await call();
  assert.equal(response.status, 200);
  const body = await response.json();
  assertSignature(body.developer_token);
  assert.equal(JSON.parse(Buffer.from(body.developer_token.split(".")[0], "base64url")).kid, "KEY1234567");
});

it("ignores caller-supplied signing claims and configuration", async () => {
  const response = await call({ path: `${PATH}?exp=9999999999&iss=attacker&kid=attacker&alg=none` });
  assert.equal(response.status, 200);
  const body = await response.json();
  const [header, claims] = body.developer_token.split(".").slice(0, 2).map(part => JSON.parse(Buffer.from(part, "base64url")));
  assert.deepEqual(header, { alg: "ES256", kid: "KEY1234567" });
  assert.deepEqual(claims, { iss: "TEAM123456", iat: NOW, exp: NOW + 3600 });
  assertSignature(body.developer_token);
});

it("returns unavailable when any Apple credential is missing, including after issuing a token", async () => {
  assert.equal((await call()).status, 200);
  for (const name of CREDENTIALS) {
    const original = env[name];
    for (const missing of [undefined, "", " \n "]) {
      env[name] = missing;
      const response = await call();
      assert.equal(response.status, 503);
      assert.equal(response.headers.get("cache-control"), "no-store");
      assert.deepEqual(await response.json(), {
        error: "apple_music_unavailable", error_description: "Apple Music is unavailable",
      });
    }
    env[name] = original;
  }
});

it("rejects malformed Team IDs and Key IDs", async () => {
  for (const name of CREDENTIALS.slice(0, 2)) {
    const original = env[name];
    for (const invalid of ["short", "ABCDEFGHIJK", "lowercase1", "INVALID!12"]) {
      env[name] = invalid;
      const response = await call();
      assert.equal(response.status, 503);
      assert.equal((await response.json()).error, "apple_music_unavailable");
    }
    env[name] = original;
  }
});

it("rejects malformed keys and other curves without exposing key material", async () => {
  const errors = mock.method(console, "error", () => {});
  const { privateKey } = generateKeyPairSync("ec", {
    namedCurve: "secp384r1", privateKeyEncoding: { type: "pkcs8", format: "pem" },
  });
  for (const pem of ["secret-invalid-pem", "-----BEGIN PRIVATE KEY-----\n!!!!\n-----END PRIVATE KEY-----", privateKey]) {
    env.APPLE_MUSIC_PRIVATE_KEY = pem;
    const response = await call();
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {
      error: "apple_music_unavailable", error_description: "Apple Music is unavailable",
    });
  }
  assert.equal(errors.mock.calls.length, 3);
  for (const call of errors.mock.calls) {
    assert.deepEqual(call.arguments, ['{"event":"apple_music_signing_failed"}']);
  }
});

it("sanitizes signing failures", async () => {
  const errors = mock.method(console, "error", () => {});
  mock.method(crypto.subtle, "sign", async () => { throw new Error(env.APPLE_MUSIC_PRIVATE_KEY); });
  const response = await call();
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: "apple_music_unavailable", error_description: "Apple Music is unavailable",
  });
  assert.deepEqual(errors.mock.calls[0].arguments, ['{"event":"apple_music_signing_failed"}']);
});

it("uses a separate Apple rate-limit bucket per Cloudflare IP", async () => {
  assert.equal((await call()).status, 200);
  assert.equal((await call({ headers: { "cf-connecting-ip": "203.0.113.8" } })).status, 200);
  assert.deepEqual(rateKeys, ["apple:203.0.113.7", "apple:203.0.113.8"]);
});

it("rejects rate-limited requests before signing", async () => {
  rateAllowed = false;
  const sign = mock.method(crypto.subtle, "sign", async () => { throw new Error("must not sign"); });
  const response = await call();
  assert.equal(response.status, 429);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal((await response.json()).error, "slow_down");
  assert.equal(sign.mock.calls.length, 0);
});

it("supports local development without a rate-limit binding", async () => {
  delete env.AUTH_LIMITER;
  assert.equal((await call()).status, 200);
});

it("only issues tokens through GET", async () => {
  for (const method of ["POST", "PUT", "DELETE"]) {
    assert.equal((await call({ method })).status, 404);
  }
  assert.deepEqual(rateKeys, []);
});
