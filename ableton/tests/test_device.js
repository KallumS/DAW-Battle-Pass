/* The Max for Live device, run in Node on a pretend Max and a pretend Live.
 *   python3 ableton/kit/build.py ableton/device.json && node --test ableton/tests/ */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { load, liveSet } = require('../kit/test/max.js');

const BUNDLE = path.join(__dirname, '..', 'DAWBattlePass.js');
function device(opts) {
  const d = load(BUNDLE, Object.assign({ width: 900, height: 169 }, opts || {}));
  d.send('bang');
  d.run(1000);
  d.get = (p) => d.ctx.get(p);
  return d;
}

test('the game starts, and shows its tier, level, coins and three daily quests', () => {
  const d = device();
  const t = d.texts();
  assert.ok(t.includes('Tier 0') && t.includes('Level 1'), t.join(' | '));
  assert.strictEqual(d.ctx.P.quests.length, 3);
  assert.ok(t.some((s) => /min$/.test(s)), 'time quests read in minutes');
});

test('time spent playing fills the tier', () => {
  const set = liveSet({ song: { is_playing: 1 } });
  const d = device({ set });
  d.run(120000);
  assert.ok(d.get('stats.active') >= 100, 'active ' + d.get('stats.active'));
  assert.ok(d.ctx.P.frac > 0.1, 'the tier moved: ' + d.ctx.P.frac);
});

test('what is done in the set becomes the game’s events', () => {
  const set = liveSet({ scenes: 2 });
  const d = device({ set });
  set.song.fns.create_midi_track(-1);
  set.slots[0].fns.create_clip(4);
  set.tracks[0].kids.devices.push(set.clip(1, [], { name: 'Operator', type: 1 }));
  d.run(3000);
  assert.strictEqual(d.get('stats.tracks'), 1, 'a track');
  assert.strictEqual(d.get('stats.items'), 1, 'a clip');
  assert.strictEqual(d.get('stats.fx'), 1, 'a device');
  assert.ok(d.get('xp') > 0);
});

test('Check In pays once a day', () => {
  const d = device();
  const before = d.ctx.P.coins;
  d.click('Check In');
  assert.ok(d.ctx.P.coins > before || d.get('inv.tokens.reroll') > 1 || d.get('checkin.total') === 1, 'checked in');
  assert.strictEqual(d.get('checkin.total'), 1);
  assert.ok(d.texts().includes('Checked In Today'));
});

test('a finished quest is claimed, and a level’s crate opened', () => {
  const d = device();
  d.ctx.game('progress', '$state', '$session', 'tracks', 999, {});
  d.ctx.game('progress', '$state', '$session', 'minutes', 99999, {});
  d.ctx.read();
  const done = d.ctx.P.quests.findIndex((q) => q.done);
  assert.ok(done >= 0, 'a quest is done');
  d.click('Claim');
  d.ctx.read();
  assert.ok(d.ctx.P.quests[done].claimed, 'claimed');
  d.ctx.game('addXp', '$state', '$session', 5000, 'test');
  d.ctx.read();
  assert.ok(d.ctx.P.crates.some((n) => n > 0), 'a crate for the levels');
  const crates = d.ctx.P.crates.reduce((a, b) => a + b, 0);
  d.click('Open');
  assert.strictEqual(d.ctx.P.crates.reduce((a, b) => a + b, 0), crates - 1);
});

test('the game is kept in a file beside the device, and comes back in another set', () => {
  const disk = {};
  const d = device({ disk, filepath: '/Lib/DAW Battle Pass.amxd' });
  d.click('Check In');
  d.run(31000);
  assert.ok(disk['/Lib/DAW Battle Pass save.txt'], 'saved beside the device');
  const e = device({ disk, filepath: '/Lib/DAW Battle Pass.amxd' });
  assert.strictEqual(e.get('checkin.total'), 1, 'the check-in came back');
});
