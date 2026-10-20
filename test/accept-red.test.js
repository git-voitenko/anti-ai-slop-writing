// Acceptance probe P2 (ci-protection.md): a deliberately failing test so that `verify` is red; the PR must not merge.
import test from 'node:test';
import assert from 'node:assert/strict';

test('acceptance probe: verify must be red', () => {
  assert.equal(1, 2, 'intentional failure for the Mode A acceptance probe');
});
