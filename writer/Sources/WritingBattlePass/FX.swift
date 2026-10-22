import SwiftUI

/// Particles, flying coins, floating numbers and rings: positions only,
/// stepped each frame; FXOverlay draws them over the whole window.
final class FXStore {
  struct Particle {
    var x, y, vx, vy: Double
    var life, age: Double
    var size: Double
    var colour: Color
    var spin = 0.0, angle = 0.0
    var gravity = 380.0
    var rect = false
    // A coin flies to a target on an arc.
    var target: CGPoint? = nil
    var start: CGPoint? = nil
  }
  struct Floater { var text: String; var x, y: Double; var age = 0.0; var life = 1.3; var colour: Color }
  struct RingFX { var x, y: Double; var colour: Color; var radius: Double; var age = 0.0; var life: Double }

  var particles: [Particle] = []
  var floaters: [Floater] = []
  var rings: [RingFX] = []
  var last: Date? = nil
  var coinPos = CGPoint(x: 800, y: 40)
  var xpPos = CGPoint(x: 300, y: 50)
  var coinBump = 0.0
  private var seed: UInt64 = 88172645463325252

  var isEmpty: Bool { particles.isEmpty && floaters.isEmpty && rings.isEmpty }

  private func rnd() -> Double {
    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return Double(seed % 1_000_000) / 1_000_000
  }

  static let confettiColours: [Color] = ([0x3FCF6E, 0x3D8EFF, 0xA45CFF, 0xFF8A1C, 0xFF3FA4, 0xFFF200, 0xF7F3F9] as [UInt32]).map { Color(hex: $0) }

  func confetti(at p: CGPoint, count: Int = 60, speed: Double = 380) {
    for _ in 0..<count {
      let a: Double = -Double.pi / 2 + (rnd() - 0.5) * 2.2
      let v: Double = speed * (0.4 + rnd() * 0.8)
      let life: Double = 1.6 + rnd()
      let size: Double = 5 + rnd() * 5
      let colour = FXStore.confettiColours[Int(rnd() * 7) % 7]
      let spin: Double = (rnd() - 0.5) * 14
      particles.append(Particle(x: Double(p.x), y: Double(p.y), vx: cos(a) * v, vy: sin(a) * v, life: life, age: 0,
                                size: size, colour: colour, spin: spin, rect: true))
    }
  }

  func burst(at p: CGPoint, count: Int = 24, colours: [Color], speed: Double = 280, size: Double = 4) {
    for _ in 0..<count {
      let a: Double = rnd() * 2 * .pi
      let v: Double = speed * (0.3 + rnd() * 0.7)
      let life: Double = 0.6 + rnd() * 0.5
      let sz: Double = size * (0.6 + rnd() * 0.8)
      let colour = colours[Int(rnd() * Double(colours.count)) % colours.count]
      particles.append(Particle(x: Double(p.x), y: Double(p.y), vx: cos(a) * v, vy: sin(a) * v, life: life, age: 0,
                                size: sz, colour: colour, gravity: 120))
    }
  }

  func coins(from p: CGPoint, count: Int) {
    for i in 0..<count {
      let a: Double = rnd() * 2 * .pi
      let sx: Double = Double(p.x) + cos(a) * 30 * rnd()
      let sy: Double = Double(p.y) + sin(a) * 30 * rnd()
      let life: Double = 0.7 + Double(i) * 0.025
      particles.append(Particle(x: sx, y: sy, vx: 0, vy: 0, life: life, age: 0,
                                size: 11, colour: Theme.coin, gravity: 0, target: coinPos, start: CGPoint(x: sx, y: sy)))
    }
  }

  func floater(_ text: String, at p: CGPoint, colour: Color) {
    floaters.append(Floater(text: text, x: p.x, y: p.y, colour: colour))
  }

  func ring(at p: CGPoint, colour: Color, radius: Double = 80, life: Double = 0.7) {
    rings.append(RingFX(x: p.x, y: p.y, colour: colour, radius: radius, life: life))
  }

  func step(_ now: Date) {
    let dt = min(0.05, last.map { now.timeIntervalSince($0) } ?? 0.016)
    last = now
    coinBump = max(0, coinBump - dt * 3)
    for i in particles.indices {
      particles[i].age += dt
      if let t = particles[i].target, let s = particles[i].start {
        let k = min(1, particles[i].age / particles[i].life)
        let e = k * k * (3 - 2 * k)
        let sx = Double(s.x), sy = Double(s.y), tx = Double(t.x), ty = Double(t.y)
        let mx = (sx + tx) / 2, my = min(sy, ty) - 120
        let u = 1 - e
        let a = u * u, b = 2 * u * e, c = e * e
        particles[i].x = a * sx + b * mx + c * tx
        particles[i].y = a * sy + b * my + c * ty
        if k >= 1 { coinBump = 1 }
      } else {
        particles[i].vy += particles[i].gravity * dt
        particles[i].vx *= 1 - dt * 0.8
        particles[i].x += particles[i].vx * dt
        particles[i].y += particles[i].vy * dt
        particles[i].angle += particles[i].spin * dt
      }
    }
    particles.removeAll { $0.age >= $0.life }
    for i in floaters.indices { floaters[i].age += dt; floaters[i].y -= 40 * dt }
    floaters.removeAll { $0.age >= $0.life }
    for i in rings.indices { rings[i].age += dt }
    rings.removeAll { $0.age >= $0.life }
  }

  func draw(_ ctx: inout GraphicsContext) {
    for r in rings {
      let k: Double = r.age / r.life
      let rad: Double = r.radius * (0.2 + 0.8 * k)
      let box = CGRect(x: r.x - rad, y: r.y - rad, width: rad * 2, height: rad * 2)
      let lw: Double = 3 * (1 - k) + 1
      ctx.stroke(Path(ellipseIn: box), with: .color(r.colour.opacity(1 - k)), lineWidth: CGFloat(lw))
    }
    for p in particles {
      let fade: Double = min(1, (p.life - p.age) / 0.3)
      if p.target != nil {
        let rect = CGRect(x: p.x - p.size / 2, y: p.y - p.size / 2, width: p.size, height: p.size)
        ctx.fill(Path(ellipseIn: rect), with: .color(Theme.coin))
        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)), with: .color(Theme.coinEdge), lineWidth: 1.5)
      } else if p.rect {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(p.angle))
        c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)), with: .color(p.colour.opacity(fade)))
      } else {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - p.size / 2, y: p.y - p.size / 2, width: p.size, height: p.size)),
                 with: .color(p.colour.opacity(fade)))
      }
    }
    for f in floaters {
      let k = f.age / f.life
      ctx.draw(Text(f.text).font(Theme.ui(15, .heavy)).foregroundColor(f.colour.opacity(1 - k * k)),
               at: CGPoint(x: f.x, y: f.y))
    }
  }
}

/// Draws the FX over the whole window, only while there is something to draw.
struct FXOverlay: View {
  @ObservedObject var model: Model
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: model.fx.isEmpty)) { tl in
      Canvas { ctx, _ in
        let wasBusy = !model.fx.isEmpty
        model.fx.step(tl.date)
        model.fx.draw(&ctx)
        // Done: one more look so the timeline pauses.
        if wasBusy && model.fx.isEmpty {
          model.fx.last = nil
          DispatchQueue.main.async { model.objectWillChange.send() }
        }
      }
    }
    .allowsHitTesting(false)
  }
}
