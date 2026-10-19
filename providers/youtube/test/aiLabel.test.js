import assert from 'node:assert/strict';
import test from 'node:test';
import { loadAiLabel, parseAiLabel } from '../src/integrations/aiLabel.js';

function watch({ badges = [], sections = [] } = {}) {
  return {
    contents: { twoColumnWatchNextResults: { results: { results: { contents: [
      { videoPrimaryInfoRenderer: { badges: badges.map((badge) => ({ metadataBadgeRenderer: badge })) } }
    ] } } } },
    engagementPanels: [{ engagementPanelSectionListRenderer: { content: {
      structuredDescriptionContentRenderer: {
        items: sections.map((section) => ({ howThisWasMadeSectionViewModel: section }))
      }
    } } }]
  };
}

const aiBadge = {
  icon: { iconType: 'INFO' },
  label: 'AI',
  accessibilityData: { label: 'AI: Content was made with AI' }
};
const aiSection = {
  sectionTitle: { content: 'How this was made' },
  bodyHeader: { content: 'Made with AI' },
  bodyText: { content: 'Sounds or visuals were altered or fully generated. Learn more' }
};

const original = globalThis.fetch;
test.afterEach(() => { globalThis.fetch = original; });

test('reads the AI badge and the disclosure section', () => {
  assert.equal(parseAiLabel(watch({ badges: [aiBadge], sections: [aiSection] })), true);
  assert.equal(parseAiLabel(watch({ badges: [aiBadge] })), true);
  assert.equal(parseAiLabel(watch({ sections: [aiSection] })), true);
});

test('ignores unlabelled videos and camera provenance', () => {
  assert.equal(parseAiLabel(watch()), false);
  assert.equal(parseAiLabel({}), false);
  assert.equal(parseAiLabel(watch({
    badges: [{ label: '4K' }],
    sections: [{ bodyHeader: { content: 'Captured with a camera' }, bodyText: { content: 'Unaltered.' } }]
  })), false);
});

test('posts an English WEB request and reports failures', async () => {
  const bodies = [];
  globalThis.fetch = async (_url, init) => {
    bodies.push(JSON.parse(init.body));
    return { ok: true, status: 200, json: async () => watch({ badges: [aiBadge] }) };
  };
  assert.deepEqual(await loadAiLabel({ videoId: 'IXXBBMbOH9k' }), { videoId: 'IXXBBMbOH9k', ai: true });
  assert.equal(bodies[0].context.client.clientName, 'WEB');
  assert.equal(bodies[0].context.client.hl, 'en');

  globalThis.fetch = async () => ({ ok: false, status: 503 });
  await assert.rejects(loadAiLabel({ videoId: 'IXXBBMbOH9k' }));
});
