/**
 * Exercises authenticated Worker routes against a disposable local D1.
 * Production Firebase verification remains untouched; the test-only verifier
 * exists solely in the feature-gated integration Worker build.
 */

import assert from "node:assert/strict";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawn, spawnSync } from "node:child_process";

const port = 8791;
const baseUrl = `http://127.0.0.1:${port}`;
const stateDirectory = ".wrangler/integration-state";
const config = join(stateDirectory, "wrangler.toml");

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", stdio: "pipe" });
  if (result.status !== 0) {
    throw new Error(`${command} failed:\n${result.stdout}\n${result.stderr}`);
  }
}

async function waitUntilReady(process) {
  for (let attempt = 0; attempt < 120; attempt += 1) {
    if (process.exitCode !== null) {
      throw new Error(`Wrangler exited before becoming ready (${process.exitCode}).`);
    }
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
    } catch {
      // The socket is expected to reject while Wrangler builds the Worker.
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error("Wrangler did not become ready within 60 seconds.");
}

function auth(uid) {
  return { authorization: `Bearer test:${uid}` };
}

async function request(path, {
  uid,
  method = "GET",
  body,
  headers = {},
  expectedStatus = 200,
} = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      ...(uid ? auth(uid) : {}),
      ...(body ? { "content-type": "application/json" } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  assert.equal(response.status, expectedStatus, `${method} ${path}`);
  if (expectedStatus === 304) {
    assert.equal(response.headers.get("cache-control"), "private, no-cache");
  } else {
    assert.equal(response.headers.get("x-content-type-options"), "nosniff");
    assert.equal(response.headers.get("cache-control"), "no-store");
  }
  const text = await response.text();
  return {
    response,
    body: text ? JSON.parse(text) : null,
  };
}

rmSync(stateDirectory, { force: true, recursive: true });
mkdirSync(stateDirectory, { recursive: true });
const projectDirectory = process.cwd();
writeFileSync(config, `
# Generated local-only configuration. It is kept under ignored disposable state.
name = "pushlog-api-integration"
main = "${join(projectDirectory, "src/entry.mjs")}"
compatibility_date = "2026-08-06"
compatibility_flags = ["nodejs_compat"]

[vars]
FIREBASE_PROJECT_ID = "pushlog-app"
ENVIRONMENT = "integration"

[[d1_databases]]
binding = "DB"
database_name = "pushlog-integration"
database_id = "150fa67b-ecf6-4833-a10a-2be0816e7678"
migrations_dir = "${join(projectDirectory, "migrations")}"

[build]
command = "cd ${projectDirectory} && ./scripts/install-worker-build.sh && worker-build --release --features integration-test-auth"
`);
run("wrangler", [
  "d1",
  "migrations",
  "apply",
  "pushlog-integration",
  "--local",
  "--persist-to",
  stateDirectory,
  "--config",
  config,
]);

const wrangler = spawn("wrangler", [
  "dev",
  "--local",
  "--port",
  String(port),
  "--persist-to",
  stateDirectory,
  "--config",
  config,
], { stdio: ["ignore", "pipe", "pipe"] });

let serverOutput = "";
wrangler.stdout.on("data", (chunk) => { serverOutput += chunk; });
wrangler.stderr.on("data", (chunk) => { serverOutput += chunk; });

try {
  await waitUntilReady(wrangler);

  await request("/v1/profile", { expectedStatus: 401 });
  await request("/health", { method: "POST", expectedStatus: 405 });

  for (const uid of ["alice", "bob", "charlie"]) {
    const profile = await request("/v1/profile", { uid });
    assert.equal(profile.body.profile.uid, uid);
    await request("/v1/profile/username", {
      uid,
      method: "PUT",
      body: { username: uid },
    });
  }

  const invalidUsername = await request("/v1/profile/username", {
    uid: "alice",
    method: "PUT",
    body: { username: "!" },
    expectedStatus: 422,
  });
  assert.equal(invalidUsername.body.error.code, "invalid_username");
  const oversizedBody = await request("/v1/profile/username", {
    uid: "alice",
    method: "PUT",
    body: { username: "a".repeat(1_000_001) },
    expectedStatus: 413,
  });
  assert.equal(oversizedBody.body.error.code, "request_too_large");
  await request("/v1/friend-requests?direction=sideways", {
    uid: "alice",
    expectedStatus: 422,
  });
  await request("/v1/workout-snapshot", {
    uid: "charlie",
    expectedStatus: 404,
  });

  const search = await request("/v1/users/search?q=bo", { uid: "alice" });
  assert.deepEqual(search.body.profiles.map((profile) => profile.uid), ["bob"]);

  await request("/v1/friend-requests", {
    uid: "alice",
    method: "POST",
    body: { receiverUid: "bob" },
    expectedStatus: 201,
  });
  const incoming = await request("/v1/friend-requests?direction=incoming", { uid: "bob" });
  assert.deepEqual(incoming.body.requests.map((profile) => profile.uid), ["alice"]);
  await request("/v1/friend-requests/accept", {
    uid: "bob",
    method: "POST",
    body: { requesterUid: "alice" },
  });
  const friends = await request("/v1/friends?dayKey=2026-08-06&weekKey=2026-08-03", {
    uid: "alice",
  });
  assert.deepEqual(friends.body.friends.map((profile) => profile.uid), ["bob"]);

  const selfRequest = await request("/v1/friend-requests", {
    uid: "alice",
    method: "POST",
    body: { receiverUid: "alice" },
    expectedStatus: 422,
  });
  assert.equal(selfRequest.body.error.code, "invalid_friend");
  await request("/v1/friend-requests", {
    uid: "alice",
    method: "POST",
    body: { receiverUid: "charlie" },
    expectedStatus: 201,
  });
  await request("/v1/friend-requests/cancel", {
    uid: "alice",
    method: "POST",
    body: { receiverUid: "charlie" },
    expectedStatus: 204,
  });
  await request("/v1/friend-requests", {
    uid: "charlie",
    method: "POST",
    body: { receiverUid: "alice" },
    expectedStatus: 201,
  });
  await request("/v1/friend-requests/decline", {
    uid: "alice",
    method: "POST",
    body: { requesterUid: "charlie" },
    expectedStatus: 204,
  });

  const token = "integration-device-token";
  await request("/v1/devices", {
    uid: "alice",
    method: "PUT",
    body: { token, platform: "windows" },
    expectedStatus: 422,
  });
  await request("/v1/devices", {
    uid: "alice",
    method: "PUT",
    body: { token, platform: "ios" },
  });
  await request("/v1/devices", {
    uid: "alice",
    method: "DELETE",
    body: { token },
    expectedStatus: 204,
  });

  const snapshot = {
    dayTotals: { "2026-08-06": 12 },
    sessions: [{
      id: "session-1",
      date: "2026-08-06T08:00:00.000Z",
      reps: 12,
      source: "manual",
      duration: 1_000_000,
      averageRepDuration: 83_333,
      manualAdjustments: 0,
      effortScore: null,
    }],
    preferences: {},
    updatedAt: "2026-08-06T08:00:00.000Z",
    lastSyncedAt: null,
  };
  const bobSnapshot = structuredClone(snapshot);
  bobSnapshot.dayTotals["2026-08-06"] = 5;
  bobSnapshot.sessions[0].id = "session-bob-1";
  bobSnapshot.sessions[0].reps = 5;
  bobSnapshot.sessions[0].source = "live";
  bobSnapshot.sessions[0].manualAdjustments = 2;
  bobSnapshot.sessions[0].effortScore = 8;
  bobSnapshot.sessions[0].latestHeartRate = 142.5;
  bobSnapshot.sessions[0].activeCalories = 18.75;
  const charlieSnapshot = structuredClone(snapshot);
  charlieSnapshot.dayTotals["2026-08-06"] = 25;
  charlieSnapshot.sessions[0].id = "session-charlie-1";
  charlieSnapshot.sessions[0].reps = 25;
  await request("/v1/workout-snapshot", {
    uid: "charlie",
    method: "PUT",
    body: {
      snapshot: charlieSnapshot,
      clientContext: { dayKey: "2026-08-06", weekKey: "2026-08-03" },
    },
    expectedStatus: 202,
  });
  // Charlie is already ahead when Bob adds them. Alice subsequently passes
  // Bob pairwise but remains second on Bob's three-person leaderboard.
  await request("/v1/friend-requests", {
    uid: "charlie",
    method: "POST",
    body: { receiverUid: "bob" },
    expectedStatus: 201,
  });
  await request("/v1/friend-requests/accept", {
    uid: "bob",
    method: "POST",
    body: { requesterUid: "charlie" },
  });
  await request("/v1/workout-snapshot", {
    uid: "bob",
    method: "PUT",
    body: {
      snapshot: bobSnapshot,
      clientContext: { dayKey: "2026-08-06", weekKey: "2026-08-03" },
    },
    expectedStatus: 202,
  });
  const friendActivity = await request("/v1/friends/bob", { uid: "alice" });
  assert.equal(friendActivity.body.profile.uid, "bob");
  assert.equal(friendActivity.body.profile.email, undefined);
  assert.deepEqual(friendActivity.body.dayTotals, { "2026-08-06": 5 });
  assert.equal(friendActivity.body.sessions[0].source, "live");
  assert.equal(friendActivity.body.sessions[0].effortScore, 8);
  assert.equal(friendActivity.body.sessions[0].latestHeartRate, 142.5);
  assert.equal(friendActivity.body.sessions[0].activeCalories, 18.75);
  assert.equal(friendActivity.body.preferences, undefined);
  const hiddenFriendActivity = await request("/v1/friends/alice", {
    uid: "charlie",
    expectedStatus: 404,
  });
  assert.equal(hiddenFriendActivity.body.error.code, "friend_not_found");
  assert.ok(hiddenFriendActivity.response.headers.get("x-request-id"));
  await request("/v1/workout-snapshot", {
    uid: "alice",
    method: "PUT",
    body: {
      snapshot,
      clientContext: { dayKey: "2026-08-06", weekKey: "2026-08-03" },
    },
    expectedStatus: 202,
  });
  const unchanged = await request("/v1/workout-snapshot", {
    uid: "alice",
    method: "PUT",
    body: {
      snapshot,
      clientContext: { dayKey: "2026-08-06", weekKey: "2026-08-03" },
    },
  });
  assert.equal(unchanged.body.status, "unchanged");
  const stored = await request("/v1/workout-snapshot", { uid: "alice" });
  assert.deepEqual(stored.body.snapshot, snapshot);
  const etag = stored.response.headers.get("etag");
  assert.ok(etag);
  await request("/v1/workout-snapshot", {
    uid: "alice",
    headers: { "if-none-match": etag },
    expectedStatus: 304,
  });

  const malformedSnapshot = await request("/v1/workout-snapshot", {
    uid: "alice",
    method: "PUT",
    body: { snapshot: { dayTotals: [], sessions: [] } },
    expectedStatus: 422,
  });
  assert.equal(malformedSnapshot.body.error.code, "invalid_snapshot");

  let bobNotifications;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    bobNotifications = await request("/v1/notifications", { uid: "bob" });
    if (bobNotifications.body.notifications.length === 1) break;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  assert.equal(bobNotifications.body.notifications.length, 1);
  const rankAwareCopy = [
    bobNotifications.body.notifications[0].title,
    bobNotifications.body.notifications[0].body,
  ].join(" ");
  assert.match(rankAwareCopy, /#2\b/, "actor should be second behind Charlie");
  assert.match(rankAwareCopy, /#3\b/, "recipient should drop to third");
  assert.match(rankAwareCopy, /8 reps\b/, "copy should retain the pairwise catch-up gap");
  assert.doesNotMatch(rankAwareCopy, /first place|the lead|leader|top spot|crown/i);
  await request("/v1/notifications", {
    uid: "bob",
    method: "POST",
    body: {
      notificationIds: [bobNotifications.body.notifications[0].notificationId],
    },
  });

  run("wrangler", [
    "d1",
    "execute",
    "pushlog-integration",
    "--local",
    "--persist-to",
    stateDirectory,
    "--config",
    config,
    "--command",
    `INSERT INTO notification_events (
      uid, notification_id, type, title, body, source_sync_id,
      delivery_status, payload_json, created_at
    ) VALUES
      ('bob', 'delivered-push', 'engagement_reminder', 'Delivered',
       'Already presented by FCM', 'delivered-source', 'delivered', '{}',
       '2026-08-06T09:00:00.000Z'),
      ('bob', 'pending-push', 'engagement_reminder', 'Pending',
       'FCM delivery is still in flight', 'pending-source', 'pending', '{}',
       '2026-08-06T09:00:30.000Z'),
      ('bob', 'failed-fallback', 'engagement_reminder', 'Fallback',
       'FCM failed, so polling may present this', 'failed-source', 'failed', '{}',
       '2026-08-06T09:01:00.000Z');`,
  ]);
  const fallbackNotifications = await request("/v1/notifications", { uid: "bob" });
  assert.deepEqual(
    fallbackNotifications.body.notifications.map(({ notificationId }) => notificationId),
    ["failed-fallback"],
    "polling must omit delivered and in-flight push notifications",
  );
  await request("/v1/notifications", { uid: "alice" });
  await request("/v1/notifications", {
    uid: "alice",
    method: "POST",
    body: { notificationIds: [] },
    expectedStatus: 422,
  });
  await request("/v1/notifications", {
    uid: "alice",
    method: "POST",
    body: { notificationIds: ["missing-but-valid"] },
  });

  const report = await request("/v1/reports", {
    uid: "alice",
    method: "POST",
    body: { reportedUid: "bob", reason: "safety_concern" },
    expectedStatus: 201,
  });
  assert.equal(report.body.status, "reported_and_blocked");
  const friendsAfterBlock = await request(
    "/v1/friends?dayKey=2026-08-06&weekKey=2026-08-03",
    { uid: "alice" },
  );
  assert.deepEqual(friendsAfterBlock.body.friends, []);
  const blockedFriendActivity = await request("/v1/friends/bob", {
    uid: "alice",
    expectedStatus: 404,
  });
  assert.equal(blockedFriendActivity.body.error.code, "friend_not_found");
  const searchAfterBlock = await request("/v1/users/search?q=bo", { uid: "alice" });
  assert.deepEqual(searchAfterBlock.body.profiles, []);
  const blockedRequest = await request("/v1/friend-requests", {
    uid: "bob",
    method: "POST",
    body: { receiverUid: "alice" },
    expectedStatus: 403,
  });
  assert.equal(blockedRequest.body.error.code, "connection_blocked");

  await request("/v1/friends", {
    uid: "alice",
    method: "DELETE",
    body: { friendUid: "bob" },
    expectedStatus: 204,
  });
  await request("/v1/account", {
    uid: "alice",
    method: "DELETE",
    expectedStatus: 204,
  });

  console.log("Worker integration routes passed.");
} catch (error) {
  console.error(serverOutput);
  throw error;
} finally {
  wrangler.kill("SIGTERM");
  await new Promise((resolve) => {
    if (wrangler.exitCode !== null) resolve();
    else wrangler.once("exit", resolve);
  });
}
