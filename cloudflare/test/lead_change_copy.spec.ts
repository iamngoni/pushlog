import {describe, expect, it} from 'vitest';
import {
  buildLeadChangeCopy,
  leadChangeVariantCount,
} from '../src/lead_change_copy';

const everyVariant = Array.from({length: leadChangeVariantCount}, (_, i) => i);

describe('buildLeadChangeCopy', () => {
  it('offers several variants', () => {
    expect(leadChangeVariantCount).toBeGreaterThanOrEqual(10);
  });

  it('produces distinct copy for each variant', () => {
    const rendered = everyVariant.map((index) =>
      JSON.stringify(
        buildLeadChangeCopy({actor: 'ana', deficit: 4, repsToRetake: 5}, index),
      ),
    );
    expect(new Set(rendered).size).toBe(leadChangeVariantCount);
  });

  it.each(everyVariant)(
    'variant %i stays actionable and well formed',
    (index) => {
      const copy = buildLeadChangeCopy(
        {actor: 'ana', deficit: 4, repsToRetake: 5},
        index,
      );

      // The whole point of the push is the number to beat, so every body
      // has to carry it. A variant that drops it is just noise.
      expect(copy.body).toContain('5');
      expect(copy.title.length).toBeGreaterThan(0);
      // Push titles get truncated by the OS well before this.
      expect(copy.title.length).toBeLessThanOrEqual(65);
      expect(copy.body.length).toBeLessThanOrEqual(120);
      // Never double up the sigil on a username.
      expect(copy.title).not.toContain('@@');
      expect(copy.body).not.toContain('@@');
    },
  );

  // A tone guard used to live here, asserting no variant could shame the
  // reader. It was removed on purpose: the copy was rewritten to be
  // deliberately harsher, so the guard was encoding a policy the product
  // had already decided against. Tone is a judgement call for whoever edits
  // the bank; the structural checks above are the ones worth enforcing.

  it('strips a stored leading @ instead of doubling it', () => {
    for (const index of everyVariant) {
      const copy = buildLeadChangeCopy(
        {actor: '@ana', deficit: 1, repsToRetake: 2},
        index,
      );
      expect(`${copy.title} ${copy.body}`).not.toContain('@@');
    }
  });

  it('falls back when the actor name is only sigils', () => {
    const copy = buildLeadChangeCopy(
      {actor: '@', deficit: 1, repsToRetake: 2},
      0,
    );
    expect(copy.title).toContain('A friend');
  });

  it('wraps out-of-range and negative indexes', () => {
    const base = buildLeadChangeCopy(
      {actor: 'ana', deficit: 2, repsToRetake: 3},
      0,
    );
    expect(
      buildLeadChangeCopy(
        {actor: 'ana', deficit: 2, repsToRetake: 3},
        leadChangeVariantCount,
      ),
    ).toEqual(base);
    expect(
      buildLeadChangeCopy(
        {actor: 'ana', deficit: 2, repsToRetake: 3},
        -leadChangeVariantCount,
      ),
    ).toEqual(base);
  });

  it('picks randomly when no index is given', () => {
    const seen = new Set<string>();
    for (let i = 0; i < 300; i += 1) {
      seen.add(
        buildLeadChangeCopy({actor: 'ana', deficit: 1, repsToRetake: 2}).title,
      );
    }
    // Not asserting full coverage — that would be flaky. Just that it is
    // not pinned to one variant.
    expect(seen.size).toBeGreaterThan(1);
  });
});
