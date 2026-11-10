// Local Firestore Rules emulator only; never connects to production.
// Dependencies and launch instructions: docs/story_data_management_spec.md.
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, collection, setDoc, updateDoc, deleteDoc, getDoc, getDocs,
  query, where, orderBy, documentId, limit, startAfter,
} = require('firebase/firestore');

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^127\.0\.0\.1:\d+$/.test(host)) {
  throw new Error('FIRESTORE_EMULATOR_HOST must be an explicit local 127.0.0.1 port.');
}
const [hostname, port] = host.split(':');
const library = {
  schemaVersion: 'yorisoi-story-data-v1',
  publicationStatus: 'approved', language: 'ja-JP',
};
const published = {
  emotion: 'happy', petType: 'dog', language: 'ja-JP',
  isActive: true, humanApproved: true,
  approvalStatus: 'approved_text', audioStatus: 'ready',
};

// Exact equality/order/limit contract of FirebaseStorySource.queryForEmotion.
function candidates(db, options = {}) {
  const filters = { ...published };
  if (options.omit) delete filters[options.omit];
  if (options.override) Object.assign(filters, options.override);
  const constraints = Object.entries(filters).map(([key, value]) => where(key, '==', value));
  constraints.push(orderBy('displayOrder'), orderBy(documentId()));
  if (options.cursor) constraints.push(startAfter(...options.cursor));
  if (!options.noLimit) constraints.push(limit(options.limit ?? 10));
  return query(collection(db, 'stories'), ...constraints);
}

test('Yorisoi story rules: local compilation and access/query contract', async (t) => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-yorisoi-rules',
    firestore: {
      host: hostname, port: Number(port),
      rules: readFileSync(resolve(__dirname, '../firestore/story.rules'), 'utf8'),
    },
  });
  const admin = async (action) => env.withSecurityRulesDisabled(async (context) => action(context.firestore()));
  const released = async (value) => admin(async (db) => {
    const ref = doc(db, 'storyLibraries/current');
    return value === null ? deleteDoc(ref) : setDoc(ref, value);
  });
  try {
    await env.clearFirestore();
    await admin(async (db) => {
      await setDoc(doc(db, 'storyLibraries/current'), library);
      for (let n = 1; n <= 3; n++) {
        await setDoc(doc(db, `stories/happy_dog_00${n}`), {
          ...published, displayOrder: n, storyId: `happy_dog_00${n}`,
        });
      }
      const variants = {
        draft: { humanApproved: false, approvalStatus: 'draft' },
        inactive: { isActive: false },
        pending_audio: { audioStatus: 'in_review' },
        unapproved: { humanApproved: false },
        rejected: { approvalStatus: 'rejected' },
        wrong_language: { language: 'en-US' },
        lonely: { emotion: 'lonely', petType: 'cat' },
      };
      for (const [id, edit] of Object.entries(variants)) {
        await setDoc(doc(db, `stories/${id}`), { ...published, displayOrder: 5, ...edit });
      }
      const missing = { ...published, displayOrder: 6 };
      delete missing.humanApproved;
      await setDoc(doc(db, 'stories/missing_approval'), missing);
      await setDoc(doc(db, 'storyDrafts/private'), { text: 'local fixture only' });
      await setDoc(doc(db, 'storyRevisions/private/revisions/r001'), { text: 'local fixture only' });
    });
    const signed = env.authenticatedContext('local-test-user').firestore();
    const anonymous = env.unauthenticatedContext().firestore();

    await t.test('signed-in user reads library and released story', async () => {
      await assertSucceeds(getDoc(doc(signed, 'storyLibraries/current')));
      await assertSucceeds(getDoc(doc(signed, 'stories/happy_dog_001')));
    });
    await t.test('repository query succeeds, ordered Happy records only', async () => {
      const result = await assertSucceeds(getDocs(candidates(signed)));
      assert.deepEqual(result.docs.map((d) => d.id), ['happy_dog_001', 'happy_dog_002', 'happy_dog_003']);
    });
    await t.test('repository document-ID cursor pagination succeeds', async () => {
      const result = await assertSucceeds(getDocs(candidates(signed, { cursor: [1, 'happy_dog_001'] })));
      assert.deepEqual(result.docs.map((d) => d.id), ['happy_dog_002', 'happy_dog_003']);
    });
    await t.test('valid filtered query may return zero records', async () => {
      const result = await assertSucceeds(getDocs(candidates(signed, { override: { emotion: 'sad', petType: 'cat' } })));
      assert.equal(result.size, 0);
    });
    await t.test('unauthenticated library, story and collection reads denied', async () => {
      await assertFails(getDoc(doc(anonymous, 'storyLibraries/current')));
      await assertFails(getDoc(doc(anonymous, 'stories/happy_dog_001')));
      await assertFails(getDocs(candidates(anonymous)));
    });
    for (const id of ['draft', 'inactive', 'pending_audio', 'unapproved', 'rejected', 'wrong_language', 'missing_approval']) {
      await t.test(`direct unpublished/malformed get denied: ${id}`, async () => {
        await assertFails(getDoc(doc(signed, `stories/${id}`)));
      });
    }
    for (const field of ['isActive', 'humanApproved', 'approvalStatus', 'audioStatus', 'language']) {
      await t.test(`query missing ${field} constraint denied`, async () => {
        await assertFails(getDocs(candidates(signed, { omit: field })));
      });
    }
    await t.test('unfiltered query, missing limit and limit above 10 denied', async () => {
      await assertFails(getDocs(query(collection(signed, 'stories'), limit(10))));
      await assertFails(getDocs(candidates(signed, { noLimit: true })));
      await assertFails(getDocs(candidates(signed, { limit: 11 })));
    });
    await t.test('library collection listing denied', async () => {
      await assertFails(getDocs(collection(signed, 'storyLibraries')));
    });
    for (const value of [null, { ...library, publicationStatus: 'draft' },
      { ...library, schemaVersion: 'unknown' }, { publicationStatus: 'approved' }]) {
      await t.test(`missing/draft/invalid release gate denies stories: ${JSON.stringify(value)}`, async () => {
        try {
          await released(value);
          await assertFails(getDoc(doc(signed, 'stories/happy_dog_001')));
          await assertFails(getDocs(candidates(signed)));
          // Repository can still inspect draft metadata and show an empty result.
          if (value !== null) await assertSucceeds(getDoc(doc(signed, 'storyLibraries/current')));
        } finally { await released(library); }
      });
    }
    await t.test('all client create/update/delete and publication writes denied', async () => {
      await assertFails(setDoc(doc(signed, 'stories/new'), published));
      await assertFails(updateDoc(doc(signed, 'stories/happy_dog_001'), { isActive: false }));
      await assertFails(deleteDoc(doc(signed, 'stories/happy_dog_001')));
      await assertFails(setDoc(doc(signed, 'storyLibraries/current'), library));
    });
    await t.test('private drafts, revisions and unrelated paths denied', async () => {
      await assertFails(getDoc(doc(signed, 'storyDrafts/private')));
      await assertFails(getDoc(doc(signed, 'storyRevisions/private/revisions/r001')));
      await assertFails(getDoc(doc(signed, 'unrelated/private')));
    });
  } finally {
    await env.clearFirestore();
    await env.cleanup();
  }
});
