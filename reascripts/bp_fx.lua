--[[ DAW Battle Pass - the moving parts.

     Pure Lua. The particles, the numbers that float up, the toasts that slide
     in, the flash and the shake: positions and lifetimes, worked out here and
     drawn by the window. Nothing in this file touches REAPER or ImGui, so
     tests/test_fx.lua can run a thousand frames of it.

     Particle kinds:
       spark    - a dot that flies out and fades
       confetti - a little spinning card that falls
       coin     - flies to the coin counter, and bumps it on arrival
       ring     - a circle that grows and fades
       star     - a twinkle that stays put
]]

local F = {}

F.ease = {
  outCubic = function(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end,
  inCubic = function(t) t = math.max(0, math.min(1, t)); return t * t * t end,
  inOut = function(t) t = math.max(0, math.min(1, t)); return -(math.cos(math.pi * t) - 1) / 2 end,
  outBack = function(t)
    t = math.max(0, math.min(1, t))
    local c1 = 1.70158
    return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
  end,
  outElastic = function(t)
    t = math.max(0, math.min(1, t))
    if t == 0 or t == 1 then return t end
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
  end,
}

-- Moves a shown value towards the real one, quickly at first: the XP bar and
-- the coin counter roll rather than jump.
function F.approach(cur, target, dt, speed)
  local k = 1 - math.exp(-(speed or 8) * dt)
  local v = cur + (target - cur) * k
  if math.abs(target - v) < 0.01 then return target end
  return v
end

F.MAX_PARTICLES = 700
F.CONFETTI = { 0xFF3FA4FF, 0x3D8EFFFF, 0x3FCF6EFF, 0xFF8A1CFF, 0xA45CFFFF, 0xFFF200FF, 0xDDE1E7FF }

function F.new(rnd)
  return { particles = {}, floaters = {}, toasts = {}, shake = 0, flash = 0, flashCol = 0xFFFFFFFF,
           bumps = {}, t = 0, rnd = rnd or math.random }
end

local function add(fx, p)
  if #fx.particles >= F.MAX_PARTICLES then table.remove(fx.particles, 1) end
  fx.particles[#fx.particles + 1] = p
end

-- n sparks out of a point. o: col (or cols), speed, life, size, up (an
-- upward kick), gravity.
function F.burst(fx, x, y, n, o)
  o = o or {}
  local rnd = fx.rnd
  for _ = 1, n do
    local a = rnd() * math.pi * 2
    local sp = (o.speed or 260) * (0.3 + 0.7 * rnd())
    local life = (o.life or 0.9) * (0.6 + 0.4 * rnd())
    add(fx, { kind = o.kind or "spark", x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp - (o.up or 0),
              life = life, max = life, size = (o.size or 3) * (0.6 + 0.8 * rnd()),
              col = o.cols and o.cols[math.floor(rnd() * #o.cols) + 1] or (o.col or 0xFFFFFFFF),
              grav = o.gravity or 0, rot = rnd() * math.pi * 2, vr = (rnd() - 0.5) * 12 })
  end
end

function F.confetti(fx, x, y, n, spread)
  F.burst(fx, x, y, n, { kind = "confetti", cols = F.CONFETTI, speed = spread or 420, up = 220,
                         life = 2.2, size = 5, gravity = 520 })
end

function F.ring(fx, x, y, col, size, life)
  add(fx, { kind = "ring", x = x, y = y, vx = 0, vy = 0, life = life or 0.7, max = life or 0.7,
            size = size or 80, col = col or 0xFFFFFFFF, grav = 0, rot = 0, vr = 0 })
end

function F.twinkle(fx, x, y, col, size)
  local life = 0.5 + fx.rnd() * 0.6
  add(fx, { kind = "star", x = x, y = y, vx = 0, vy = -10, life = life, max = life,
            size = size or 5, col = col or 0xFFFFFFFF, grav = 0, rot = 0, vr = 0 })
end

-- Coins that fly from (x, y) to (tx, ty) after a short scatter; each one that
-- lands bumps `bump`.
function F.coins(fx, x, y, n, tx, ty, bump)
  local rnd = fx.rnd
  for i = 1, math.min(n, 40) do
    local a = rnd() * math.pi * 2
    local sp = 120 + rnd() * 220
    add(fx, { kind = "coin", x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp - 150,
              life = 3, max = 3, size = 5 + rnd() * 2, col = 0xFFC83DFF, grav = 0,
              tx = tx, ty = ty, delay = 0.25 + i * 0.03, bump = bump or "coins", rot = 0, vr = 0 })
  end
end

function F.floater(fx, text, x, y, col, big)
  fx.floaters[#fx.floaters + 1] = { text = text, x = x, y = y, col = col or 0xFFFFFFFF,
                                    life = 1.6, max = 1.6, big = big or false }
end

-- t: { text, sub, icon, rarity, life }
function F.toast(fx, t)
  t.life = t.life or 4.5
  t.max = t.life
  t.age = 0
  fx.toasts[#fx.toasts + 1] = t
  while #fx.toasts > 5 do table.remove(fx.toasts, 1) end
end

function F.flash(fx, amount, col)
  fx.flash = math.max(fx.flash, amount or 0.6)
  fx.flashCol = col or 0xFFFFFFFF
end

function F.shake(fx, amount) fx.shake = math.max(fx.shake, amount or 8) end

function F.bump(fx, what) fx.bumps[what] = 1 end

function F.update(fx, dt)
  fx.t = fx.t + dt
  local keep = {}
  for _, p in ipairs(fx.particles) do
    p.life = p.life - dt
    if p.kind == "coin" then
      if p.delay > 0 then
        p.delay = p.delay - dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.vx, p.vy = p.vx * (1 - 3 * dt), p.vy * (1 - 3 * dt)
      else
        local dx, dy = p.tx - p.x, p.ty - p.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 12 then
          p.life = 0
          fx.bumps[p.bump] = 1
        else
          local sp = math.min(1600, 300 + (3 - p.life) * 900)
          p.x = p.x + dx / d * math.min(d, sp * dt)
          p.y = p.y + dy / d * math.min(d, sp * dt)
        end
      end
    else
      p.vy = p.vy + p.grav * dt
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
      if p.kind == "spark" then p.vx, p.vy = p.vx * (1 - 2.2 * dt), p.vy * (1 - 2.2 * dt) end
      if p.kind == "confetti" then p.vx = p.vx * (1 - 1.2 * dt) end
      p.rot = p.rot + p.vr * dt
    end
    if p.life > 0 then keep[#keep + 1] = p end
  end
  fx.particles = keep

  local fl = {}
  for _, f in ipairs(fx.floaters) do
    f.life = f.life - dt
    f.y = f.y - 38 * dt
    if f.life > 0 then fl[#fl + 1] = f end
  end
  fx.floaters = fl

  local ts = {}
  for _, t in ipairs(fx.toasts) do
    t.age = t.age + dt
    if t.age < t.max then ts[#ts + 1] = t end
  end
  fx.toasts = ts

  fx.shake = math.max(0, fx.shake - dt * 30)
  fx.flash = math.max(0, fx.flash - dt * 2.2)
  for k, v in pairs(fx.bumps) do
    v = v - dt * 4
    fx.bumps[k] = v > 0 and v or nil
  end
end

-- How far the window should be shaken this frame.
function F.shakeOffset(fx)
  if fx.shake <= 0 then return 0, 0 end
  return (fx.rnd() - 0.5) * fx.shake, (fx.rnd() - 0.5) * fx.shake
end

-- A colour 0xRRGGBBAA with its alpha scaled - arithmetic, not bit operators,
-- the way the sister repos do it, keeping the colour bytes untouched.
function F.alpha(col, a)
  local base = col - col % 256
  local al = col % 256
  return base + math.max(0, math.min(255, math.floor(al * a + 0.5)))
end

-- Two colours mixed, t = 0 the first, 1 the second.
function F.mix(c1, c2, t)
  local function ch(c, shift) return math.floor(c / shift) % 256 end
  local out = 0
  for _, shift in ipairs({ 16777216, 65536, 256, 1 }) do
    local a, b = ch(c1, shift), ch(c2, shift)
    out = out + math.floor(a + (b - a) * t + 0.5) * shift
  end
  return out
end

-- A colour from hue, saturation and value (0..1 each), opaque.
function F.hsv(h, s, v)
  h = (h % 1) * 6
  local i = math.floor(h)
  local f = h - i
  local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return math.floor(r * 255 + 0.5) * 16777216 + math.floor(g * 255 + 0.5) * 65536 + math.floor(b * 255 + 0.5) * 256 + 255
end

return F
