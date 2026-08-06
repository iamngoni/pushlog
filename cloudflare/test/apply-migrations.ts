import {env} from 'cloudflare:workers';
import {applyD1Migrations} from 'cloudflare:test';
import {beforeAll} from 'vitest';

import type {Env} from '../src/env';

interface TestEnv extends Env {
  TEST_MIGRATIONS: Parameters<typeof applyD1Migrations>[1];
}

beforeAll(async () => {
  const testEnv = env as unknown as TestEnv;
  await applyD1Migrations(testEnv.DB, testEnv.TEST_MIGRATIONS);
});
