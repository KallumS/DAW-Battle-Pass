// The picture in the README: `node ableton/window.js` redraws ableton/window.png.
// Some progress: tracks made and XP earned.
require('./kit/test/picture.js')(__dirname, { bundle: 'DAWBattlePass.js', w: 900, h: 169,
  go(d) { d.ctx.game('progress', '$state', '$session', 'tracks', 999, {}); d.ctx.game('addXp', '$state', '$session', 800, 'x'); d.ctx.read(); } });
