import Foundation

/// Relics: Legendary and Mythic pieces of the wardrobe inspired by famous
/// writers' books (0025) - Poe's raven, the Overlook's caretaker, Sherlock
/// Holmes's deerstalker. Each is a nod, in our own words: a name, a line of
/// flavour, whose work it comes from, and a power that suits it. Stats are
/// rolled as for any other piece of its rarity.
public struct Relic {
  public let slot: String
  public let name: String
  public let flavour: String
  public let author: String
  public let power: String
}

extension Gear {
  public static let relics: [Relic] = [
    // Pens
    Relic(slot: "pen", name: "The Raven's Quill", flavour: "Once upon a midnight dreary, it wrote and wrote.",
          author: "Edgar Allan Poe", power: "second_wind"),
    Relic(slot: "pen", name: "Paul Sheldon's Typewriter", flavour: "The N key is missing. Write anyway - your number one fan is waiting.",
          author: "Stephen King", power: "marathon"),
    Relic(slot: "pen", name: "Bartleby's Ledger Pen", flavour: "It would prefer not to. You may swap one task a day.",
          author: "Herman Melville", power: "fickle"),
    // Headphones
    Relic(slot: "phones", name: "Christine's Car Radio", flavour: "Only plays the oldies, and never quite switches off.",
          author: "Stephen King", power: "deep_focus"),
    Relic(slot: "phones", name: "Lighthouse Keeper's Earmuffs", flavour: "Muffle everything but the next sentence.",
          author: "Virginia Woolf", power: "deep_focus"),
    // Hats
    Relic(slot: "hat", name: "The Nevermore Fedora", flavour: "A black feather in the band. Writer's block? Nevermore.",
          author: "Edgar Allan Poe", power: "collector"),
    Relic(slot: "hat", name: "Deerstalker of Baker Street", flavour: "Eliminate the impossible; whatever remains is your plot.",
          author: "Arthur Conan Doyle", power: "scholar"),
    Relic(slot: "hat", name: "Scrooge's Nightcap", flavour: "Three ghosts of drafts past, present and yet to come.",
          author: "Charles Dickens", power: "midas"),
    Relic(slot: "hat", name: "Ingolstadt Lab Goggles", flavour: "It's alive! The second draft, that is.",
          author: "Mary Shelley", power: "overclock"),
    // Accessories
    Relic(slot: "jewel", name: "The Pendulum Watch", flavour: "Swings a little lower with every deadline.",
          author: "Edgar Allan Poe", power: "marathon"),
    Relic(slot: "jewel", name: "Pemberley Signet Ring", flavour: "A truth universally acknowledged: you will finish this chapter.",
          author: "Jane Austen", power: "midas"),
    Relic(slot: "jewel", name: "Miskatonic Library Card", flavour: "Overdue since 1928. Some books are better left unread.",
          author: "H. P. Lovecraft", power: "collector"),
    // Outfits
    Relic(slot: "outfit", name: "The Overlook Caretaker's Jacket", flavour: "All work and no play - but at least it's work.",
          author: "Stephen King", power: "marathon"),
    Relic(slot: "outfit", name: "Masque of the Red Death", flavour: "Seven rooms, one party, and the door stays shut.",
          author: "Edgar Allan Poe", power: "golden_hour"),
    Relic(slot: "outfit", name: "The Count's Opera Cape", flavour: "Writes best after dark. Never in a mirror.",
          author: "Bram Stoker", power: "second_wind"),
    // Shoes
    Relic(slot: "shoes", name: "The Gunslinger's Boots", flavour: "The writer fled across the desert, and the novel followed.",
          author: "Stephen King", power: "deep_focus"),
    Relic(slot: "shoes", name: "Wuthering Moor Boots", flavour: "Made for wild moors and wilder heartbreak.",
          author: "Emily Brontë", power: "second_wind"),
    // Bags
    Relic(slot: "bag", name: "Castle Rock Messenger Bag", flavour: "Small town, big secrets, room for a manuscript.",
          author: "Stephen King", power: "hoarder"),
    Relic(slot: "bag", name: "Orient Express Valise", flavour: "Everyone on board had a motive.",
          author: "Agatha Christie", power: "hoarder"),
    Relic(slot: "bag", name: "Harker's Travel Satchel", flavour: "Full of journals, letters and garlic.",
          author: "Bram Stoker", power: "scholar"),
    // Desk charms
    Relic(slot: "charm", name: "The Tell-Tale Heart", flavour: "Beats under the floorboards, in time with your typing.",
          author: "Edgar Allan Poe", power: "deep_focus"),
    Relic(slot: "charm", name: "The Gold-Bug", flavour: "A beetle of solid gold, and a cipher only you can read.",
          author: "Edgar Allan Poe", power: "midas"),
    Relic(slot: "charm", name: "Room 237 Key", flavour: "Don't go in. Write about it instead.",
          author: "Stephen King", power: "golden_hour"),
    Relic(slot: "charm", name: "Paper Boat from Derry", flavour: "Floats off down the gutter of every blank page.",
          author: "Stephen King", power: "fickle"),
    Relic(slot: "charm", name: "Hill House Key", flavour: "Whatever walks there walks alone. So do writers.",
          author: "Shirley Jackson", power: "overclock"),
  ]

  /// How often a Legendary or Mythic piece is a relic.
  public static func relicChance(_ r: Int) -> Double {
    r >= Rarity.mythic ? 0.6 : (r >= Rarity.legendary ? 0.4 : 0)
  }
}
