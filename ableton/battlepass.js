/* DAW Battle Pass as a Max for Live device.
 *
 * The game is reascripts/bp_game.lua, bp_loot.lua and bp_theory.lua,
 * unchanged, on Middaw's Lua 5.4 runtime, driven through Middaw's host the
 * way Middaw's own Battle Pass window drives it (passStart, passCall,
 * passGet, passNotices, passSave). What bp_watch.lua does in REAPER is done
 * here with the Live Object Model: every second the game is told whether
 * anyone is there (something in the set changed, or Live is playing or
 * recording), and every two seconds the set is compared with what was seen
 * last - new tracks, clips, devices, notes in the clip being edited, locators
 * and recorded clips - and each becomes the game's event.
 *
 * The game is the musician's, not the set's: it is saved in a file beside
 * the device (DAW Battle Pass save.txt) as well as with the set, and the
 * newer of the two is used.
 *
 * Expects, before it: UI, Live, MiddawHost, DEVICE = { files }.
 * Outlets: 0 MIDI bytes (MIDI passes through), 1 the state to [pattr].
 */
inlets = 1;
outlets = 2;
mgraphics.init();
mgraphics.relative_coords = 0;
mgraphics.autofill = 0;

var H = MiddawHost;
H.init(function (p) { return DEVICE.files[p] === undefined ? null : DEVICE.files[p]; }, function (s) { post(s + '\n'); });
function call(method, args) {
  var r = JSON.parse(H.call(method, args === undefined ? '' : JSON.stringify(args)));
  if (!r.ok) throw new Error(r.error);
  return r.value;
}
function game(fn) { return call('passCall', { fn: fn, args: Array.prototype.slice.call(arguments, 1) }); }
function get(path) { return call('passGet', { path: path }); }
function epoch() { return Math.floor(Date.now() / 1000); }

var P = {
  started: false, t0: Date.now(), scope: 'daily', status: '', lastChange: 0, seen: null, saved: '', fileSaved: '',
  tier: 0, frac: 0, level: 1, xp: 0, need: 200, coins: 0, quests: [], crates: [], rarity: [], tokens: {}, checkin: false
};
function clock() { return (Date.now() - P.t0) / 1000; }
function say(s) { P.status = s || ''; }

// --------------------------------------------------------------- saving --
function savePath() {
  try {
    var fp = typeof patcher !== 'undefined' && patcher.filepath ? String(patcher.filepath) : '';
    if (!fp) return null;
    return fp.replace(/[^\/:]*$/, '') + 'DAW Battle Pass save.txt';
  } catch (e) { return null; }
}
function readFileText(path) {
  try {
    var f = new File(path, 'read');
    if (!f.isopen) return null;
    var out = '';
    while (f.position < f.eof) out += f.readstring(Math.min(16384, f.eof - f.position));
    f.close();
    return out || null;
  } catch (e) { return null; }
}
function writeFileText(path, text) {
  try {
    var f = new File(path, 'write', 'TEXT');
    if (!f.isopen) return false;
    f.eof = 0;
    for (var i = 0; i < text.length; i += 16384) f.writestring(text.slice(i, i + 16384));
    f.close();
    return true;
  } catch (e) { return false; }
}
// The saved game with the most time in it: the file's, or the set's.
function newer(a, b) {
  function active(s) { var m = /active\s*=\s*([\d.]+)/.exec(s || ''); return m ? +m[1] : -1; }
  return active(a) >= active(b) ? a : b;
}
function save(force) {
  if (!P.started) return;
  var s = call('passSave');
  if (s !== P.saved || force) { P.saved = s; outlet(1, 'set', s); }
  var path = savePath();
  if (path && s !== P.fileSaved && writeFileText(path, s)) P.fileSaved = s;
}

// -------------------------------------------------------------- the game --
function start(savedFromSet) {
  if (P.started) return;
  var path = savePath(), fromFile = path ? readFileText(path) : null;
  var saved = fromFile && savedFromSet ? newer(fromFile, savedFromSet) : (fromFile || savedFromSet || null);
  call('passStart', { epoch: epoch(), clock: clock(), saved: saved });
  P.started = true;
  P.seen = scan();
  read();
}
function read() {
  P.tier = get('pass.tier') || 0;
  P.frac = Math.min(1, (get('pass.secs') || 0) / (call('passConst', { name: 'TIER_SECONDS' }) || 900));
  P.level = Math.max(1, get('level') || 1);
  P.xp = Math.floor(get('xp') || 0);
  P.need = game('levelNeed', P.level);
  P.coins = Math.floor(get('coins') || 0);
  P.quests = get(P.scope + '.quests') || [];
  if (!Array.isArray(P.quests)) P.quests = Object.keys(P.quests).map(function (k) { return P.quests[k]; });
  var c = get('inv.crates') || [];
  P.crates = Array.isArray(c) ? c : Object.keys(c).map(function (k) { return c[k]; });
  P.tokens = get('inv.tokens') || {};
  P.checkin = !!game('checkinAvailable', '$state', epoch());
  if (!P.rarity.length) P.rarity = (call('passConst', { name: 'RARITY', module: 'loot' }) || []).map(function (r) { return r.name; });
}
function drain() {
  (call('passNotices') || []).forEach(function (n) {
    if (n.kind === 'tier') say('Battle Pass: tier ' + get('pass.tier') + ' unlocked.');
    else if (n.kind === 'level') say('Level ' + get('level') + ' — a crate is waiting.');
    else if (n.kind === 'quest') say('Quest done: ' + (n.text || n.name || '') + '.');
    else if (n.kind === 'claim') say('Claimed: ' + (n.coins || 0) + ' coins, ' + (n.xp || 0) + ' XP.');
    else if (n.kind === 'crate') say('Opened a crate: ' + (n.drops ? (Array.isArray(n.drops) ? n.drops.length : Object.keys(n.drops).length) : 0) + ' things.');
    else if (n.kind === 'season') say('A new season of the Battle Pass has started.');
    else if (n.kind === 'toast' && n.text) say(n.text + (n.sub ? ' — ' + n.sub : ''));
  });
}

// ------------------------------------------------------------ the watch --
// The set as counts and names, cheap enough to read every two seconds.
function api(path) { return new LiveAPI(null, path); }
function one(a, p) { var v = a.get(p); return Array.isArray(v) ? v[0] : v; }
function scan() {
  var s = { tracks: 0, clips: 0, devices: {}, cues: 0, notes: 0, recorded: 0 };
  try {
    var song = api('live_set'), n = song.getcount('tracks');
    s.tracks = n;
    s.cues = song.getcount('cue_points');
    for (var t = 0; t < n; t++) {
      var tp = 'live_set tracks ' + t, track = api(tp);
      var slots = track.getcount('clip_slots');
      for (var k = 0; k < slots; k++) if (+one(api(tp + ' clip_slots ' + k), 'has_clip')) s.clips++;
      s.clips += track.getcount('arrangement_clips');
      var nd = track.getcount('devices');
      for (var d = 0; d < nd; d++) {
        var dev = api(tp + ' devices ' + d);
        s.devices[dev.id] = { name: String(one(dev, 'name') || ''), instrument: +one(dev, 'type') === 1 };
      }
    }
    var c = Live.clipNotes();
    s.notes = c ? c.notes.length : 0;
    s.clip = c ? c.name : null;
  } catch (e) { /* not in Live */ }
  return s;
}
function watch() {
  var now = scan(), was = P.seen, changed = false;
  P.seen = now;
  if (!was) return;
  function ev(kind, n, info) {
    if (n <= 0) return;
    changed = true;
    game('event', '$state', '$session', kind, n, info || {});
  }
  ev('track', now.tracks - was.tracks);
  ev('item', now.clips - was.clips);
  ev('marker', now.cues - was.cues);
  if (now.clip === was.clip) ev('notes', now.notes - was.notes);
  Object.keys(now.devices).forEach(function (id) {
    if (was.devices[id]) return;
    var d = now.devices[id];
    ev('fx', 1, { name: d.name, norm: d.name.toLowerCase(), instrument: d.instrument });
  });
  var song = Live.song();
  if (song.playing && isRecording() && now.clips > was.clips) ev('take', now.clips - was.clips);
  if (changed) { game('event', '$state', '$session', 'edit', 1, {}); P.lastChange = Date.now(); }
}
function isRecording() {
  try { var s = api('live_set'); return !!+one(s, 'record_mode') || !!+one(s, 'session_record'); } catch (e) { return false; }
}

var ticks = 0;
function tick() {
  if (!P.started) return;
  var song = Live.song(), rec = isRecording();
  var signals = { input: Date.now() - P.lastChange < 90000 || song.playing, playing: song.playing, recording: rec && song.playing, project: 'Live Set' };
  game('tick', '$state', '$session', clock(), epoch(), signals);
  game('refresh', '$state', '$session', epoch(), {});
  game('checkAchievements', '$state', '$session');
  if (ticks % 2 === 0) watch();
  if (ticks % 30 === 0) save();
  ticks++;
  drain();
  read();
  mgraphics.redraw();
}

// ------------------------------------------------------------- actions --
function act(fn) {
  var args = Array.prototype.slice.call(arguments, 1);
  try { game.apply(null, [fn].concat(args)); } catch (e) { say(String(e.message || e)); }
  drain(); read(); save(); mgraphics.redraw();
}

// ------------------------------------------------------------ messages --
var timer = null, pendingSet = null;
function bang() {
  start(pendingSet);
  if (!timer) { timer = new Task(tick, this); timer.interval = 1000; timer.repeat(); }
  mgraphics.redraw();
}
function restore(text) {
  var s = String(text);
  if (!P.started) { pendingSet = s; return; }
}
function msg_int(b) { outlet(0, b); }

// --------------------------------------------------------------- paint --
function bar(x, y, w, h, frac, col) {
  UI.round(x, y, w, h, 3, UI.C.sunken);
  if (frac > 0) UI.round(x, y, Math.max(4, w * Math.min(1, frac)), h, 3, col || UI.C.accent);
}
function paint() {
  var sz = (typeof box !== 'undefined' && box.rect) ? [box.rect[2] - box.rect[0], box.rect[3] - box.rect[1]] : [900, 169];
  var W = sz[0], Ht = sz[1];
  UI.begin(mgraphics);
  UI.rect(0, 0, W, Ht, UI.C.ground);
  UI.text(P.status || 'DAW Battle Pass — make music to unlock tiers', 6, 1, W - 12, 16, UI.C.dim, 10, 0);
  if (!P.started) return;
  // the pass, the level, the coins
  UI.text('Tier ' + P.tier, 6, 20, 120, 14, UI.C.text, 11, 0, true);
  UI.text(Math.floor((1 - P.frac) * 15) + ' min to the next', 100, 20, 106, 14, UI.C.dim, 9, 2);
  bar(6, 36, 200, 8, P.frac);
  UI.text('Level ' + P.level, 6, 50, 120, 14, UI.C.text, 11, 0, true);
  UI.text(P.xp + ' / ' + P.need + ' XP', 100, 50, 106, 14, UI.C.dim, 9, 2);
  bar(6, 66, 200, 8, P.xp / Math.max(1, P.need), UI.C.control);
  UI.text(P.coins + ' coins · ' + (P.tokens.reroll || 0) + ' rerolls', 6, 80, 200, 14, UI.C.label, 10, 0);
  UI.button(P.checkin ? 'Check In' : 'Checked In Today', 6, 100, 200, 20, false, function () { act('checkin', '$state', '$session', epoch()); }, P.checkin);
  UI.button('Use a Boost (' + (P.tokens.boost || 0) + ')', 6, 126, 200, 20, false, function () { act('useBoost', '$state', '$session'); }, (P.tokens.boost || 0) > 0);

  // the quests
  var qx = 216, qw = W - qx - 252;
  UI.button('Daily', qx, 20, 70, 18, P.scope === 'daily', function () { P.scope = 'daily'; read(); mgraphics.redraw(); });
  UI.button('Weekly', qx + 74, 20, 70, 18, P.scope === 'weekly', function () { P.scope = 'weekly'; read(); mgraphics.redraw(); });
  P.quests.slice(0, 4).forEach(function (q, i) {
    var y = 44 + i * 30;
    UI.rect(qx, y, qw, 26, UI.C.raised);
    if (q.claimed) UI.rect(qx, y, 3, 26, UI.C.accent);
    UI.text(q.text || '', qx + 8, y, qw - 170, 26, q.claimed ? UI.C.dim : UI.C.text, 10, 0);
    var timed = q.kind === 'minutes' || q.kind === 'session';   // counted in seconds, read in minutes
    var have = Math.min(q.progress || 0, q.target), of = q.target;
    UI.text(timed ? Math.floor(have / 60) + ' / ' + Math.round(of / 60) + ' min' : Math.floor(have) + ' / ' + of, qx + qw - 160, y, 70, 26, UI.C.dim, 9, 2);
    var bx = qx + qw - 82;
    if (q.claimed) UI.text('Claimed', bx, y + 4, 76, 18, UI.C.dim, 10, 1);
    else if (q.done) UI.button('Claim', bx, y + 4, 76, 18, true, function () { act('claimQuest', '$state', '$session', P.scope, i + 1); });
    else UI.button('Reroll', bx, y + 4, 76, 18, false, function () { act('reroll', '$state', '$session', P.scope, i + 1); }, !!game('canReroll', '$state', P.scope));
  });

  // the crates
  var cx = W - 244;
  UI.text('Crates', cx, 20, 230, 16, UI.C.text, 11, 0, true);
  var row = 0;
  P.crates.forEach(function (n, r) {
    if (!(n > 0) || row >= 4) return;
    var y = 40 + row * 24; row++;
    UI.text((P.rarity[r] || 'Crate') + ' × ' + n, cx, y, 150, 20, UI.C.label, 10, 0);
    UI.button('Open', cx + 160, y, 70, 20, false, function () { act('openCrate', '$state', '$session', r + 1); });
  });
  if (!row) UI.text('None yet. Each level brings one.', cx, 40, 236, 20, UI.C.dim, 10, 0);
}
function onclick(x, y) { if (UI.click(x, y)) mgraphics.redraw(); }
function ondrag(x, y, but) { UI.dragTo(x, y, !!but); }
