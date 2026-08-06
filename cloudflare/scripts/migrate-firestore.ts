import {createHash, randomUUID} from 'node:crypto';

import {applicationDefault, getApps, initializeApp} from 'firebase-admin/app';
import {
  type DocumentData,
  type Firestore,
  getFirestore,
} from 'firebase-admin/firestore';

type JsonPrimitive = boolean | number | string | null;
type JsonValue = JsonPrimitive | JsonValue[] | {[key: string]: JsonValue};
type JsonObject = {[key: string]: JsonValue};

interface SourceDocument {
  path: string;
  data: JsonObject;
  checksum: string;
}

interface Inventory {
  documents: SourceDocument[];
  userIds: string[];
  summary: Record<string, number>;
}

interface D1Statement {
  sql: string;
  params?: unknown[];
}

interface D1Result {
  success: boolean;
  results?: Array<Record<string, unknown>>;
  error?: string;
}

interface D1Envelope {
  success: boolean;
  errors?: Array<{message?: string}>;
  result?: D1Result[];
}

interface D1Credentials {
  accountId: string;
  databaseId: string;
  apiToken: string;
}

interface PendingFriendRequest {
  senderUid: string;
  receiverUid: string;
  incoming?: SourceDocument;
  outgoing?: SourceDocument;
}

const firebaseProjectId = process.env.FIREBASE_PROJECT_ID ?? 'pushlog-app';
const knownRootCollections = [
  'users',
  'publicProfiles',
  'friendStats',
  'usernames',
] as const;
const knownUserSubcollections = [
  'friends',
  'incomingFriendRequests',
  'outgoingFriendRequests',
  'privateState',
  'pushTokens',
  'notifications',
] as const;
const d1BatchSize = 50;

async function main(): Promise<void> {
  const args = new Set(process.argv.slice(2));
  if (args.has('--help')) {
    printHelp();
    return;
  }
  const apply = args.has('--apply');
  const reconcile = args.has('--reconcile');
  const unknown = [...args].filter(
    (arg) => !['--apply', '--reconcile'].includes(arg),
  );
  if (unknown.length > 0) {
    throw new Error(`Unknown argument: ${unknown.join(', ')}`);
  }

  const firestore = firestoreClient();
  const inventory = await inventoryFirestore(firestore);
  printInventory(inventory);

  if (!apply && !reconcile) {
    console.log('Dry run only. No D1 data was changed.');
    return;
  }

  const d1 = new D1Client(d1Credentials());
  if (apply) {
    await applyInventory(d1, inventory);
  }
  if (reconcile) {
    await reconcileInventory(d1, inventory);
  }
}

function firestoreClient(): Firestore {
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId: firebaseProjectId});
  }
  return getFirestore();
}

async function inventoryFirestore(firestore: Firestore): Promise<Inventory> {
  const rootGroups = await Promise.all(
    knownRootCollections.map(async (collection) => ({
      collection,
      documents: await readCollection(firestore, collection),
    })),
  );
  const rootDocuments = rootGroups.flatMap((group) => group.documents);
  const userIds = new Set<string>();
  for (const document of rootDocuments) {
    const [collection, documentId] = document.path.split('/');
    if (
      collection === 'users' ||
      collection === 'publicProfiles' ||
      collection === 'friendStats'
    ) {
      userIds.add(documentId);
    }
    if (collection === 'usernames') {
      const uid = stringValue(document.data.uid);
      if (uid != null) userIds.add(uid);
    }
  }

  const subcollectionDocuments = (
    await Promise.all(
      [...userIds].map(async (uid) =>
        Promise.all(
          knownUserSubcollections.map((collection) =>
            readCollection(firestore, `users/${uid}/${collection}`),
          ),
        ),
      ),
    )
  ).flat(2);

  for (const document of subcollectionDocuments) {
    const parts = document.path.split('/');
    if (parts[0] !== 'users' || parts.length !== 4) continue;
    if (
      parts[2] === 'friends' ||
      parts[2] === 'incomingFriendRequests' ||
      parts[2] === 'outgoingFriendRequests'
    ) {
      userIds.add(parts[3]);
    }
  }

  const documents = [...rootDocuments, ...subcollectionDocuments].sort(
    (left, right) => left.path.localeCompare(right.path),
  );
  return {
    documents,
    userIds: [...userIds].sort(),
    summary: summarize(documents, userIds.size),
  };
}

async function readCollection(
  firestore: Firestore,
  path: string,
): Promise<SourceDocument[]> {
  const snapshot = await firestore.collection(path).get();
  return snapshot.docs.map((document) => {
    const data = toJsonObject(document.data());
    return {
      path: document.ref.path,
      data,
      checksum: checksum(data),
    };
  });
}

function summarize(
  documents: SourceDocument[],
  userCount: number,
): Record<string, number> {
  const summary: Record<string, number> = {
    sourceDocuments: documents.length,
    users: userCount,
    workoutSnapshots: 0,
    workoutSessions: 0,
    dailyScores: 0,
    friendLinks: 0,
    incomingRequests: 0,
    outgoingRequests: 0,
    devices: 0,
    notifications: 0,
  };
  for (const document of documents) {
    if (/^users\/[^/]+\/privateState\/workout$/.test(document.path)) {
      summary.workoutSnapshots += 1;
      const sessions = document.data.sessions;
      const dayTotals = document.data.dayTotals;
      summary.workoutSessions += Array.isArray(sessions) ? sessions.length : 0;
      summary.dailyScores += isObject(dayTotals)
        ? Object.keys(dayTotals).length
        : 0;
    } else if (/^users\/[^/]+\/friends\//.test(document.path)) {
      summary.friendLinks += 1;
    } else if (/\/incomingFriendRequests\//.test(document.path)) {
      summary.incomingRequests += 1;
    } else if (/\/outgoingFriendRequests\//.test(document.path)) {
      summary.outgoingRequests += 1;
    } else if (/\/pushTokens\//.test(document.path)) {
      summary.devices += 1;
    } else if (/\/notifications\//.test(document.path)) {
      summary.notifications += 1;
    }
  }
  return summary;
}

function printInventory(inventory: Inventory): void {
  console.log(`Firestore project: ${firebaseProjectId}`);
  for (const [label, count] of Object.entries(inventory.summary)) {
    console.log(`${label}: ${count}`);
  }
}

async function applyInventory(
  d1: D1Client,
  inventory: Inventory,
): Promise<void> {
  const runId = randomUUID();
  const now = new Date().toISOString();
  await d1.execute([
    {
      sql: `INSERT INTO migration_runs (
        run_id, source, mode, started_at, source_document_count, summary_json
      ) VALUES (?, 'firestore', 'backfill', ?, ?, ?)`,
      params: [
        runId,
        now,
        inventory.documents.length,
        stableStringify(inventory.summary),
      ],
    },
  ]);

  const byPath = new Map(
    inventory.documents.map((document) => [document.path, document]),
  );
  const userStatements = inventory.userIds.map((uid) => {
    const privateDocument = byPath.get(`users/${uid}`);
    const publicDocument = byPath.get(`publicProfiles/${uid}`);
    const privateData = privateDocument?.data ?? {};
    const publicData = publicDocument?.data ?? {};
    return {
      sql: `INSERT INTO users (
        uid, email, display_name, photo_url, username, username_lower,
        private_json, public_json, created_at, updated_at, migrated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(uid) DO UPDATE SET
        email = excluded.email,
        display_name = excluded.display_name,
        photo_url = excluded.photo_url,
        username = excluded.username,
        username_lower = excluded.username_lower,
        private_json = excluded.private_json,
        public_json = excluded.public_json,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        migrated_at = excluded.migrated_at`,
      params: [
        uid,
        stringValue(privateData.email),
        firstString(privateData.displayName, publicData.displayName),
        firstString(privateData.photoUrl, publicData.photoUrl),
        firstString(privateData.username, publicData.username),
        firstString(privateData.usernameLower, publicData.usernameLower),
        stableStringify(privateData),
        stableStringify(publicData),
        firstString(privateData.createdAt, publicData.createdAt),
        firstString(privateData.updatedAt, publicData.updatedAt) ?? now,
        now,
      ],
    } satisfies D1Statement;
  });
  await d1.execute(userStatements);

  const ordinaryStatements: D1Statement[] = [];
  const workoutDocuments: Array<{uid: string; document: SourceDocument}> = [];
  const pendingRequests = new Map<string, PendingFriendRequest>();

  for (const document of inventory.documents) {
    const parts = document.path.split('/');
    const [collection, documentId] = parts;
    if (collection === 'usernames') {
      const uid = stringValue(document.data.uid);
      if (uid == null) continue;
      ordinaryStatements.push({
        sql: `INSERT INTO username_claims (
          username_lower, uid, username, source_json, updated_at
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(username_lower) DO UPDATE SET
          uid = excluded.uid,
          username = excluded.username,
          source_json = excluded.source_json,
          updated_at = excluded.updated_at`,
        params: [
          documentId,
          uid,
          stringValue(document.data.username),
          stableStringify(document.data),
          stringValue(document.data.updatedAt) ?? now,
        ],
      });
    } else if (collection === 'friendStats') {
      ordinaryStatements.push(friendStatsStatement(documentId, document, now));
    } else if (collection === 'users' && parts.length === 4) {
      const uid = documentId;
      const subcollection = parts[2];
      const subdocumentId = parts[3];
      if (subcollection === 'privateState' && subdocumentId === 'workout') {
        workoutDocuments.push({uid, document});
      } else if (subcollection === 'friends') {
        ordinaryStatements.push({
          sql: `INSERT INTO friend_links (
            owner_uid, friend_uid, added_at, source_json, migrated_at
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(owner_uid, friend_uid) DO UPDATE SET
            added_at = excluded.added_at,
            source_json = excluded.source_json,
            migrated_at = excluded.migrated_at`,
          params: [
            uid,
            subdocumentId,
            stringValue(document.data.addedAt),
            stableStringify(document.data),
            now,
          ],
        });
      } else if (subcollection === 'incomingFriendRequests') {
        const key = `${subdocumentId}:${uid}`;
        const request =
          pendingRequests.get(key) ??
          {senderUid: subdocumentId, receiverUid: uid};
        request.incoming = document;
        pendingRequests.set(key, request);
      } else if (subcollection === 'outgoingFriendRequests') {
        const key = `${uid}:${subdocumentId}`;
        const request =
          pendingRequests.get(key) ??
          {senderUid: uid, receiverUid: subdocumentId};
        request.outgoing = document;
        pendingRequests.set(key, request);
      } else if (subcollection === 'pushTokens') {
        ordinaryStatements.push(deviceStatement(uid, subdocumentId, document, now));
      } else if (subcollection === 'notifications') {
        ordinaryStatements.push(
          notificationStatement(uid, subdocumentId, document, now),
        );
      }
    }
  }

  for (const request of pendingRequests.values()) {
    const incoming = request.incoming?.data;
    const outgoing = request.outgoing?.data;
    ordinaryStatements.push({
      sql: `INSERT INTO friend_requests (
        sender_uid, receiver_uid, status, incoming_json, outgoing_json,
        created_at, updated_at, migrated_at
      ) VALUES (?, ?, 'pending', ?, ?, ?, ?, ?)
      ON CONFLICT(sender_uid, receiver_uid) DO UPDATE SET
        status = 'pending',
        incoming_json = excluded.incoming_json,
        outgoing_json = excluded.outgoing_json,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        migrated_at = excluded.migrated_at`,
      params: [
        request.senderUid,
        request.receiverUid,
        incoming == null ? null : stableStringify(incoming),
        outgoing == null ? null : stableStringify(outgoing),
        firstString(incoming?.createdAt, outgoing?.createdAt),
        now,
        now,
      ],
    });
  }

  await d1.execute(ordinaryStatements);
  for (const workout of workoutDocuments) {
    await importWorkout(d1, workout.uid, workout.document, now);
  }

  const ledgerStatements = inventory.documents.map(
    (document): D1Statement => ({
      sql: `INSERT INTO migration_ledger (
        source_path, source_checksum, run_id, imported_at
      ) VALUES (?, ?, ?, ?)
      ON CONFLICT(source_path) DO UPDATE SET
        source_checksum = excluded.source_checksum,
        run_id = excluded.run_id,
        imported_at = excluded.imported_at`,
      params: [document.path, document.checksum, runId, now],
    }),
  );
  await d1.execute(ledgerStatements);
  await d1.execute([
    {
      sql: `UPDATE migration_runs
        SET completed_at = ?, imported_document_count = ?
        WHERE run_id = ?`,
      params: [new Date().toISOString(), inventory.documents.length, runId],
    },
  ]);
  console.log(`D1 backfill complete: ${inventory.documents.length} documents.`);
}

async function importWorkout(
  d1: D1Client,
  uid: string,
  document: SourceDocument,
  now: string,
): Promise<void> {
  const data = document.data;
  const syncId = `firestore-${document.checksum.slice(0, 24)}`;
  const statements: D1Statement[] = [];
  const sessions = Array.isArray(data.sessions) ? data.sessions : [];
  for (const value of sessions) {
    if (!isObject(value)) continue;
    const sessionId = stringValue(value.id);
    const occurredAt = stringValue(value.date);
    if (sessionId == null || occurredAt == null) continue;
    statements.push({
      sql: `INSERT OR REPLACE INTO workout_sessions (
        uid, sync_id, session_id, occurred_at, reps, source,
        duration_us, average_rep_duration_us, manual_adjustments
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      params: [
        uid,
        syncId,
        sessionId,
        occurredAt,
        integerValue(value.reps),
        stringValue(value.source) ?? 'manual',
        nullableInteger(value.duration),
        nullableInteger(value.averageRepDuration),
        integerValue(value.manualAdjustments),
      ],
    });
  }
  if (isObject(data.dayTotals)) {
    for (const [dayKey, reps] of Object.entries(data.dayTotals)) {
      statements.push({
        sql: `INSERT OR REPLACE INTO daily_scores (
          uid, sync_id, day_key, reps
        ) VALUES (?, ?, ?, ?)`,
        params: [uid, syncId, dayKey, integerValue(reps)],
      });
    }
  }
  await d1.execute(statements);
  await d1.execute([
    {
      sql: `INSERT INTO workout_snapshots (
        uid, sync_id, snapshot_json, content_hash, source_updated_at,
        last_synced_at, schema_version, updated_at, migrated_at
      ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
      ON CONFLICT(uid) DO UPDATE SET
        sync_id = excluded.sync_id,
        snapshot_json = excluded.snapshot_json,
        content_hash = excluded.content_hash,
        source_updated_at = excluded.source_updated_at,
        last_synced_at = excluded.last_synced_at,
        schema_version = excluded.schema_version,
        updated_at = excluded.updated_at,
        migrated_at = excluded.migrated_at`,
      params: [
        uid,
        syncId,
        stableStringify(data),
        document.checksum,
        stringValue(data.updatedAt),
        stringValue(data.lastSyncedAt),
        now,
        now,
      ],
    },
    {
      sql: 'DELETE FROM workout_sessions WHERE uid = ? AND sync_id <> ?',
      params: [uid, syncId],
    },
    {
      sql: 'DELETE FROM daily_scores WHERE uid = ? AND sync_id <> ?',
      params: [uid, syncId],
    },
  ]);
}

function friendStatsStatement(
  uid: string,
  document: SourceDocument,
  now: string,
): D1Statement {
  const data = document.data;
  return {
    sql: `INSERT INTO friend_stats (
      uid, today_count, today_key, week_count, week_key, best_day,
      total_all_time, streak, source_json, updated_at, migrated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(uid) DO UPDATE SET
      today_count = excluded.today_count,
      today_key = excluded.today_key,
      week_count = excluded.week_count,
      week_key = excluded.week_key,
      best_day = excluded.best_day,
      total_all_time = excluded.total_all_time,
      streak = excluded.streak,
      source_json = excluded.source_json,
      updated_at = excluded.updated_at,
      migrated_at = excluded.migrated_at`,
    params: [
      uid,
      integerValue(data.todayCount),
      stringValue(data.todayKey),
      integerValue(data.weekCount),
      stringValue(data.weekKey),
      integerValue(data.bestDay),
      integerValue(data.totalAllTime),
      integerValue(data.streak),
      stableStringify(data),
      stringValue(data.updatedAt) ?? now,
      now,
    ],
  };
}

function deviceStatement(
  uid: string,
  tokenId: string,
  document: SourceDocument,
  now: string,
): D1Statement {
  return {
    sql: `INSERT INTO devices (
      uid, token, platform, updated_at, migrated_at
    ) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(uid, token) DO UPDATE SET
      platform = excluded.platform,
      updated_at = excluded.updated_at,
      migrated_at = excluded.migrated_at`,
    params: [
      uid,
      stringValue(document.data.token) ?? tokenId,
      stringValue(document.data.platform),
      stringValue(document.data.updatedAt) ?? now,
      now,
    ],
  };
}

function notificationStatement(
  uid: string,
  notificationId: string,
  document: SourceDocument,
  now: string,
): D1Statement {
  const data = document.data;
  return {
    sql: `INSERT INTO notification_events (
      uid, notification_id, type, title, body, actor_uid, competitor_uid,
      day_key, delivery_status, payload_json, created_at, read_at,
      delivered_at, migrated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(uid, notification_id) DO UPDATE SET
      type = excluded.type,
      title = excluded.title,
      body = excluded.body,
      actor_uid = excluded.actor_uid,
      competitor_uid = excluded.competitor_uid,
      day_key = excluded.day_key,
      delivery_status = excluded.delivery_status,
      payload_json = excluded.payload_json,
      created_at = excluded.created_at,
      read_at = excluded.read_at,
      delivered_at = excluded.delivered_at,
      migrated_at = excluded.migrated_at`,
    params: [
      uid,
      notificationId,
      stringValue(data.type) ?? 'unknown',
      stringValue(data.title),
      stringValue(data.body),
      stringValue(data.actorUid),
      stringValue(data.competitorUid),
      stringValue(data.dayKey),
      stringValue(data.deliveryStatus),
      stableStringify(data),
      stringValue(data.createdAt),
      stringValue(data.readAt),
      stringValue(data.deliveredAt),
      now,
    ],
  };
}

async function reconcileInventory(
  d1: D1Client,
  inventory: Inventory,
): Promise<void> {
  const rows = await d1.select(
    'SELECT source_path, source_checksum FROM migration_ledger ORDER BY source_path',
  );
  const ledger = new Map(
    rows.map((row) => [String(row.source_path), String(row.source_checksum)]),
  );
  const source = new Map(
    inventory.documents.map((document) => [document.path, document.checksum]),
  );
  const missing = [...source.keys()].filter((path) => !ledger.has(path));
  const mismatched = [...source.entries()].filter(
    ([path, checksumValue]) => ledger.get(path) !== checksumValue,
  );
  const extra = [...ledger.keys()].filter((path) => !source.has(path));
  const [counts = {}] = await d1.select(`
    SELECT
      (SELECT COUNT(*) FROM users) AS users,
      (SELECT COUNT(*) FROM workout_snapshots) AS workout_snapshots,
      (SELECT COUNT(*) FROM workout_sessions) AS workout_sessions,
      (SELECT COUNT(*) FROM daily_scores) AS daily_scores,
      (SELECT COUNT(*) FROM friend_links) AS friend_links,
      (SELECT COUNT(*) FROM friend_requests) AS friend_requests,
      (SELECT COUNT(*) FROM devices) AS devices,
      (SELECT COUNT(*) FROM notification_events) AS notification_events
  `);

  console.log(`ledgerMatched: ${source.size - missing.length - mismatched.length}`);
  console.log(`ledgerMissing: ${missing.length}`);
  console.log(`ledgerMismatched: ${mismatched.length}`);
  console.log(`ledgerExtra: ${extra.length}`);
  for (const [tableName, rowCount] of Object.entries(counts)) {
    console.log(`d1.${tableName}: ${String(rowCount)}`);
  }
  if (missing.length > 0 || mismatched.length > 0 || extra.length > 0) {
    throw new Error('Reconciliation failed. Firestore remains the source of truth.');
  }
  console.log('Reconciliation passed. Every Firestore document checksum matches D1.');
}

class D1Client {
  constructor(private readonly credentials: D1Credentials) {}

  async execute(statements: D1Statement[]): Promise<void> {
    for (let index = 0; index < statements.length; index += d1BatchSize) {
      await this.request(statements.slice(index, index + d1BatchSize));
    }
  }

  async select(sql: string, params: unknown[] = []): Promise<Array<Record<string, unknown>>> {
    const results = await this.request([{sql, params}]);
    return results[0]?.results ?? [];
  }

  private async request(statements: D1Statement[]): Promise<D1Result[]> {
    if (statements.length === 0) return [];
    const {accountId, databaseId, apiToken} = this.credentials;
    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/d1/database/${databaseId}/query`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${apiToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          batch: statements.map((statement) => ({
            sql: statement.sql,
            params: statement.params ?? [],
          })),
        }),
      },
    );
    const envelope = (await response.json()) as D1Envelope;
    const results = envelope.result ?? [];
    const failed = results.find((result) => !result.success);
    if (!response.ok || !envelope.success || failed != null) {
      const message =
        failed?.error ??
        envelope.errors?.map((error) => error.message).join('; ') ??
        `D1 request failed with HTTP ${response.status}.`;
      throw new Error(message);
    }
    return results;
  }
}

function d1Credentials(): D1Credentials {
  const accountId = requiredEnv('CLOUDFLARE_ACCOUNT_ID');
  const databaseId = requiredEnv('CLOUDFLARE_D1_DATABASE_ID');
  const apiToken = requiredEnv('CLOUDFLARE_API_TOKEN');
  return {accountId, databaseId, apiToken};
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (value == null || value.length === 0) {
    throw new Error(`${name} is required for D1 apply or reconciliation.`);
  }
  return value;
}

function toJsonObject(value: DocumentData): JsonObject {
  const converted = toJsonValue(value);
  if (!isObject(converted)) throw new Error('Firestore document is not an object.');
  return converted;
}

function toJsonValue(value: unknown): JsonValue {
  if (value == null || typeof value === 'string' || typeof value === 'boolean') {
    return value ?? null;
  }
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(toJsonValue);
  if (value instanceof Uint8Array) {
    return {__type: 'bytes', base64: Buffer.from(value).toString('base64')};
  }
  if (typeof value === 'object') {
    const candidate = value as {
      toDate?: () => Date;
      latitude?: unknown;
      longitude?: unknown;
      path?: unknown;
    };
    if (typeof candidate.toDate === 'function') {
      return candidate.toDate().toISOString();
    }
    if (
      typeof candidate.latitude === 'number' &&
      typeof candidate.longitude === 'number'
    ) {
      return {
        __type: 'geopoint',
        latitude: candidate.latitude,
        longitude: candidate.longitude,
      };
    }
    if (typeof candidate.path === 'string') {
      return {__type: 'reference', path: candidate.path};
    }
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, toJsonValue(item)]),
    );
  }
  return String(value);
}

function checksum(value: JsonValue): string {
  return createHash('sha256').update(stableStringify(value)).digest('hex');
}

function stableStringify(value: unknown): string {
  return JSON.stringify(sortValue(value));
}

function sortValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortValue);
  if (isObject(value)) {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, sortValue(value[key])]),
    );
  }
  return value;
}

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    const result = stringValue(value);
    if (result != null) return result;
  }
  return null;
}

function stringValue(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function integerValue(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : 0;
}

function nullableInteger(value: unknown): number | null {
  return value == null ? null : integerValue(value);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value != null && !Array.isArray(value);
}

function printHelp(): void {
  console.log(`Usage:
  npm run migrate:firestore                  Inventory only; no writes
  npm run migrate:firestore -- --apply       Idempotent Firestore to D1 backfill
  npm run reconcile:firestore                Compare every source checksum

Firebase authentication uses Application Default Credentials.
D1 apply/reconcile also requires CLOUDFLARE_ACCOUNT_ID,
CLOUDFLARE_D1_DATABASE_ID, and CLOUDFLARE_API_TOKEN.`);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
