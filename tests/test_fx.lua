--[[ The moving parts: particles fly and die, coins find the counter, toasts
     come and go, and the colour arithmetic leaves colours alone.

       lua5.4 tests/test_fx.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local C = dofile(HERE .. "/check.lua")
local ok, eq = C.ok, C.eq
local F = dofile(C.SCRIPTS .. "bp_fx.lua")

local seed = 1
local function rnd() seed = (seed * 48271) % 2147483647; return seed / 2147483647 end

local fx = F.new(rnd)
F.burst(fx, 100, 100, 50, { col = 0xFF0000FF })
F.confetti(fx, 100, 100, 50)
F.ring(fx, 100, 100)
F.twinkle(fx, 100, 100)
eq(#fx.particles, 102, "bursts, confetti, rings and twinkles make particles")
for _ = 1, 30 do F.update(fx, 1 / 30) end
ok(#fx.particles > 0, "they live for a while")
local moved = false
for _, p in ipairs(fx.particles) do if p.x ~= 100 or p.y ~= 100 then moved = true end end
ok(moved, "and move")
for _ = 1, 120 do F.update(fx, 1 / 30) end
eq(#fx.particles, 0, "and are gone within a few seconds")

for _ = 1, 20 do F.burst(fx, 0, 0, 100) end
ok(#fx.particles <= F.MAX_PARTICLES, "there are never more than the cap")
fx.particles = {}

F.coins(fx, 0, 0, 10, 500, 20)
local landed = false
for _ = 1, 200 do
  F.update(fx, 1 / 60)
  if fx.bumps.coins then landed = true end
end
ok(landed, "coins fly to the counter and bump it")
eq(#fx.particles, 0, "and vanish when they land")
for _ = 1, 30 do F.update(fx, 1 / 30) end
eq(fx.bumps.coins, nil, "the bump settles")

F.toast(fx, { text = "a" })
F.toast(fx, { text = "b", life = 1 })
eq(#fx.toasts, 2, "toasts queue")
for _ = 1, 40 do F.update(fx, 1 / 30) end
eq(#fx.toasts, 1, "a short toast goes first")
for _ = 1, 200 do F.update(fx, 1 / 30) end
eq(#fx.toasts, 0, "and every toast goes in the end")
for i = 1, 9 do F.toast(fx, { text = tostring(i) }) end
eq(#fx.toasts, 5, "never more than five at once")

F.floater(fx, "+5 XP", 10, 100)
local y0 = fx.floaters[1].y
F.update(fx, 0.5)
ok(fx.floaters[1].y < y0, "floating numbers rise")

F.flash(fx, 0.8)
F.shake(fx, 10)
local sx, sy = F.shakeOffset(fx)
ok(math.abs(sx) <= 5 and math.abs(sy) <= 5, "a shake stays within its size")
for _ = 1, 60 do F.update(fx, 1 / 30) end
eq(fx.flash, 0, "the flash fades")
eq(fx.shake, 0, "the shake settles")

eq(F.alpha(0xFF8800FF, 0.5), 0xFF880080, "alpha halves only the alpha byte")
eq(F.alpha(0x12345678, 1), 0x12345678, "full alpha changes nothing")
eq(F.alpha(0x123456FF, 0), 0x12345600, "zero alpha keeps the colour")
eq(F.mix(0x000000FF, 0xFFFFFFFF, 0), 0x000000FF, "mix at 0 is the first colour")
eq(F.mix(0x000000FF, 0xFFFFFFFF, 1), 0xFFFFFFFF, "mix at 1 is the second")
eq(F.hsv(0, 1, 1), 0xFF0000FF, "hue 0 is red")
eq(F.hsv(1 / 3, 1, 1), 0x00FF00FF, "a third round is green")
eq(F.hsv(0.5, 0, 0.5) % 256, 255, "hsv colours are opaque")

local v = 0
for _ = 1, 60 do v = F.approach(v, 100, 1 / 30, 8) end
ok(v > 99, "approach gets there")
eq(F.approach(99.995, 100, 1 / 30), 100, "and snaps when close")

ok(math.abs(F.ease.outBack(1) - 1) < 1e-9 and math.abs(F.ease.outBack(0)) < 1e-9, "outBack runs 0 to 1")
ok(F.ease.outElastic(1) == 1 and F.ease.outElastic(0) == 0, "outElastic runs 0 to 1")
ok(F.ease.outCubic(2) == 1 and F.ease.outCubic(-1) == 0, "eases clamp their input")

C.done()
