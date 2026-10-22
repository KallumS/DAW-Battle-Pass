import Foundation

/// A kind of writing prompt. `make` returns the prompt's text and the line
/// under it for a rarity. A rarer prompt is a richer one: more parts to the
/// brief, more constraints, more to work with. Poor prompts are the grey junk
/// of the loot table, and know it.
///
/// Add a kind to `Ideas.all` and the window, the vault filters, the demo and
/// the tests pick it up.
public struct IdeaKind {
  public let id: String
  public let label: String
  public let icon: String       // an SF Symbol
  public let weight: Double
  let make: (Dice, Int) -> (String, String)
}

private let P = Rarity.poor, U = Rarity.uncommon, R = Rarity.rare
private let E = Rarity.epic, L = Rarity.legendary, M = Rarity.mythic

public enum Ideas {
  public static let all: [IdeaKind] = [
    IdeaKind(id: "prompt", label: "Story Prompt", icon: "lightbulb", weight: 9) { d, r in
      if r == P { return ("A story about a writer with writer's block.", "Very meta. Very grey.") }
      let mood = d.pick(W.moods)
      let text = articles((r >= U ? "A \(mood) story about " : "A story about ") + d.pick(W.subjects) + ".")
      var sub: [String] = []
      if r < U { sub.append("Mood: \(mood)") }
      if r >= R { sub.append("Set " + d.pick(W.settings)) }
      if r >= E { sub.append("Told by " + d.pick(W.narrators)) }
      if r >= L { sub.append("Twist: " + d.pick(W.twists)) }
      if r >= M { sub.append("Title: " + Ideas.bookTitle(d)) }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "firstline", label: "First Line", icon: "text.quote", weight: 8) { d, r in
      if r == P { return ("\u{201C}It was a dark and stormy night.\u{201D}", "A classic. Some say too classic.") }
      let text = "\u{201C}" + d.pick(W.firstLines) + "\u{201D}"
      var sub = ["Write the next page"]
      if r >= R { sub = ["Write the next 300 words"] }
      if r >= E { sub.append("In " + d.pick(W.povs)) }
      if r >= L { sub.append("Last line: \u{201C}" + d.pick(W.lastLines) + "\u{201D}") }
      if r >= M { sub.append("Genre: " + d.pick(W.genres)) }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "character", label: "Character", icon: "person.crop.circle", weight: 8) { d, r in
      if r == P { return ("Jane Doe, a person.", "Has a face. Probably.") }
      let name = d.pick(W.firstNames) + " " + d.pick(W.surnames)
      let age = d.between(19, 74)
      var text = articles("\(name), \(age), a \(d.pick(W.jobs))")
      if r >= U { text += " who " + d.pick(W.wants) }
      text += "."
      var sub: [String] = []
      if r >= R { sub.append("Secret: " + d.pick(W.secrets)) }
      if r >= E { sub.append("Flaw: " + d.pick(W.flaws)); sub.append("Habit: " + d.pick(W.quirks)) }
      if r >= L { sub.append(articles("Nemesis: " + d.pick(W.firstNames) + " " + d.pick(W.surnames) + ", a " + d.pick(W.jobs))) }
      if r >= M { sub.append("What they need: " + d.pick(W.needs)) }
      if sub.isEmpty { sub.append("Give them a scene today") }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "setting", label: "Setting", icon: "map", weight: 6) { d, r in
      if r == P { return ("A room.", "It has walls. Four, roughly.") }
      let text = cap(articles("a " + d.pick(W.places) + ", " + d.pick(W.times) + "."))
      var sub: [String] = []
      if r >= U { sub.append("Smell: " + d.pick(W.smells)) }
      if r >= R { sub.append("Sound: " + d.pick(W.sounds)) }
      if r >= E { sub.append("Something out of place: " + d.pick(W.oddities)) }
      if r >= L { sub.append("Who walks in: " + d.pick(W.narrators)) }
      if r >= M { sub.append("What happened here: " + d.pick(W.subjects)) }
      if sub.isEmpty { sub.append("Describe it in one paragraph") }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "twist", label: "Plot Twist", icon: "tornado", weight: 6) { d, r in
      if r == P { return ("And then they all woke up.", "Please don't.") }
      let t = d.pick(W.twists)
      let text = "Twist: " + t + "."
      var sub: [String] = ["Work it into what you're writing"]
      if r >= R { sub = ["Foreshadow it with " + d.pick(W.clues)] }
      if r >= E { sub.append("Reveal it at " + d.pick(W.reveals)) }
      if r >= L { sub.append("Then a second twist: " + d.pick(W.twists.filter { $0 != t })) }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "title", label: "Book Title", icon: "book.closed", weight: 7) { d, r in
      if r == P { return ("Untitled Draft \(d.between(2, 9)) (FINAL)", "A title. Technically.") }
      let text = Ideas.bookTitle(d, fancy: r >= R)
      var sub = "A book title"
      if r >= L { sub = "Book one of the " + d.pick(W.titleAdj) + " " + d.pick(W.titleNouns) + " trilogy" }
      if r >= M { sub += ". Tagline: \u{201C}" + d.pick(W.lines) + "\u{201D}" }
      return (text, sub)
    },
    IdeaKind(id: "dialogue", label: "Dialogue Prompt", icon: "bubble.left.and.bubble.right", weight: 6) { d, r in
      if r == P { return ("\u{201C}Hello.\u{201D} \u{201C}Hello.\u{201D}", "Riveting stuff.") }
      let text = cap(d.pick(W.pairs)) + " " + d.pick(W.situations) + ". One of them says: \u{201C}" + d.pick(W.lines) + "\u{201D}"
      var sub: [String] = ["Write what comes next"]
      if r >= R { sub.append("Neither of them says what they mean") }
      if r >= E { sub.append("Nobody may say \u{201C}" + d.pick(W.bannedWords) + "\u{201D}") }
      if r >= L { sub.append("Someone walks in at the worst possible moment") }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "challenge", label: "Writing Challenge", icon: "flag", weight: 6) { d, r in
      if r == P { return ("Write something.", "Anything. Optional.") }
      let n = r >= L ? 3 : (r >= R ? 2 : 1)
      let list = Array(d.shuffled(W.constraints).prefix(n))
      var sub = "Try it in today's writing"
      if r >= E { sub = "Sprint: \(d.pick([15, 20, 25, 30])) minutes, starting now" }
      return (list.joined(separator: ". ") + ".", sub)
    },
    IdeaKind(id: "poem", label: "Poem", icon: "leaf", weight: 5) { d, r in
      if r == P { return ("Roses are red, violets are blue.", "You know the rest.") }
      let top = min(W.poemForms.count, 3 + r)
      let form = W.poemForms[d.between(0, top - 1)]
      let text = articles("A " + form.0.lowercased() + " about " + d.pick(W.poemTopics) + ".")
      var sub = [form.1]
      if r >= R { sub.append("Use the word \u{201C}" + d.pick(W.fancyWords).0 + "\u{201D}") }
      if r >= L { sub.append("End on: \u{201C}" + d.pick(W.lastLines) + "\u{201D}") }
      return (text, sub.joined(separator: ". "))
    },
    IdeaKind(id: "mash", label: "Genre Mash-up", icon: "atom", weight: 5) { d, r in
      if r == P { return ("Fiction x Words", "Genre-defining.") }
      let n = r >= E ? 3 : 2
      let list = Array(d.shuffled(W.genres).prefix(n))
      var sub = "In " + d.pick(W.povs)
      if r >= L { sub += ", " + d.pick(W.pitches) }
      return (list.joined(separator: " x "), sub)
    },
    IdeaKind(id: "penname", label: "Pen Name", icon: "theatermasks", weight: 4) { d, r in
      if r == P { return ("A. Writer", "It's a start.") }
      func one() -> String {
        switch d.between(1, 4) {
        case 1: return d.pick(W.firstNames) + " " + d.pick(W.surnames)
        case 2: return String(d.pick(W.firstNames).prefix(1)) + ". " + String(d.pick(W.firstNames).prefix(1)) + ". " + d.pick(W.surnames)
        case 3: return d.pick(W.firstNames) + " " + d.pick(W.penAdj)
        default: return d.pick(W.penAdj) + " " + d.pick(W.surnames)
        }
      }
      var sub = "For the books you'd never admit to"
      if r >= E { sub = "Or, for the thrillers: " + one() }
      return (one(), sub)
    },
    IdeaKind(id: "word", label: "Word of the Day", icon: "character.book.closed", weight: 5) { d, r in
      if r == P { return ("Nice", "Meaning: nice.") }
      let n = r >= L ? 3 : (r >= R ? 2 : 1)
      let picks = Array(d.shuffled(W.fancyWords).prefix(n))
      let text = picks.map { cap($0.0) }.joined(separator: ", ")
      var sub = picks.map { "\($0.0): \($0.1)" }.joined(separator: ". ")
      sub += n > 1 ? ". Use them all in one paragraph" : ". Use it in today's writing"
      return (text, sub)
    },
    IdeaKind(id: "blurb", label: "Back-Cover Blurb", icon: "text.book.closed", weight: 5) { d, r in
      if r == P { return ("A woman has a problem. She solves it.", "Bestseller material? No.") }
      let name = d.pick(W.firstNames) + " " + d.pick(W.surnames)
      var text = "When " + name + " " + d.pick(W.discoveries)
      if r >= U { text += ", she must " + d.pick(W.goals) + " before " + d.pick(W.stakes) + "." }
      else { text += ", everything changes." }
      var sub: [String] = []
      if r >= R { sub.append(d.pick(W.genres) + " meets " + d.pick(W.genres)) }
      if r >= E { sub.append("Set " + d.pick(W.settings)) }
      if r >= L { sub.append("Twist: " + d.pick(W.twists)) }
      if r >= M { sub.append("Title: " + Ideas.bookTitle(d, fancy: true)) }
      if sub.isEmpty { sub.append("Write the first chapter") }
      return (text, sub.joined(separator: ". "))
    },
  ]

  public static func kind(_ id: String) -> IdeaKind? { all.first { $0.id == id } }

  static func bookTitle(_ d: Dice, fancy: Bool = true) -> String {
    let pat = d.between(1, fancy ? 7 : 3)
    switch pat {
    case 1: return d.pick(W.titleAdj) + " " + d.pick(W.titleNouns)
    case 2: return "The " + d.pick(W.titleAdj) + " " + d.pick(W.titleSingles)
    case 3: return "The " + d.pick(W.titleSingles)
    case 4: return "The " + d.pick(W.titleSingles) + " of " + d.pick(W.titleNouns)
    case 5: return d.pick(W.titleNouns) + " and " + d.pick(W.titleNouns)
    case 6: return "All the " + d.pick(W.titleAdj) + " " + d.pick(W.titleNouns)
    default: return d.pick(W.firstNames) + " and the " + d.pick(W.titleAdj) + " " + d.pick(W.titleSingles)
    }
  }

  public static func make(_ d: Dice, _ kindId: String, _ r: Int) -> Drop {
    let k = kind(kindId) ?? all[0]
    let (text, sub) = k.make(d, r)
    return Drop(type: "idea", rarity: r, name: k.label, icon: k.icon, text: text, sub: sub, kind: k.id)
  }

  public static func randomKind(_ d: Dice) -> String {
    d.weighted(all.map { ($0.weight, $0.id) })
  }
}
