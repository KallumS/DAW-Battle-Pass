import Foundation

/// Every word list the rewards are made from. Read `tools/demo` output
/// (the "Demo" test prints every kind at every rarity) before and after
/// changing one.
enum W {
  // Stories -------------------------------------------------------------------

  static let subjects = [
    "a woman who inherits a bookshop she never knew existed",
    "two rivals stuck in the same lift", "a wedding planner who has stopped believing in love",
    "a letter delivered forty years late", "a perfume that brings back one memory",
    "the last day of a summer job", "a ghost who haunts a vintage clothes shop",
    "a heist at a fashion show", "a friendship tested by a road trip",
    "a woman who can hear what objects remember", "an author whose characters start emailing her",
    "a secret recipe that splits a family in two", "a dress that changes the life of whoever wears it",
    "a small town with one enormous secret", "a dating app for ghosts",
    "a florist who reads the meaning in every bouquet", "sisters who haven't spoken in ten years",
    "a makeup artist on a film set where everyone lies", "a midnight train that only stops for the lost",
    "an apology written far too late", "the person who finds your lost diary",
    "a masquerade ball where nobody is who they claim", "a bakery that sells second chances",
    "a detective who solves crimes through what people wear", "a holiday romance that refuses to end",
    "a house that rearranges itself overnight", "the understudy's big night",
    "a portrait that ages instead of its owner", "an influencer stranded somewhere with no signal",
    "a librarian with a dangerous past", "a witch who runs a skincare brand",
    "a family reunion with a stranger at the table", "a time traveller stuck in one Tuesday",
    "a con artist who falls for her mark", "two pen pals who finally meet",
    "a celebrity's assistant who knows too much", "the last bookshop on Earth",
    "a bride who wakes up the morning after the wedding in the wrong city",
    "a lighthouse keeper's final night", "a mother and daughter who swap lives for a week",
  ]

  static let moods = ["bittersweet", "cosy", "menacing", "playful", "melancholy", "hopeful",
    "defiant", "dreamy", "tense", "nostalgic", "wry", "romantic", "eerie", "chaotic", "tender",
    "glamorous", "haunting", "warm", "sharp-tongued", "feverish"]

  static let settings = ["in a rainy Paris apartment", "at a seaside hotel out of season",
    "in a department store after closing", "on an overnight train across Europe",
    "in a crumbling country house", "backstage at Fashion Week", "in a 24-hour launderette",
    "at a vineyard during the harvest", "on a space station", "in a snowed-in ski lodge",
    "in a tiny village bakery", "at a school reunion", "on a yacht off the Amalfi coast",
    "in a Victorian bathhouse", "in a hospital at 3am", "in a bridal boutique",
    "at an airport during a strike", "in a London flat share", "in a lighthouse during a storm",
    "at a masked ball", "in a botanical garden's glasshouse", "on a film set"]

  static let narrators = ["the villain", "a cat", "the house itself", "a wedding dress",
    "the best friend", "an unreliable mother", "a ghost", "a lipstick", "a teenager",
    "the town gossip", "a diary", "a stranger on the train", "the dog", "her future self"]

  static let twists = ["the narrator has been lying all along",
    "the love interest is the rival's brother", "the letter was never meant for her",
    "it all happens in a single night", "the victim planned everything",
    "the mentor is the villain", "they have met before, in another life",
    "the happy ending is a dream", "the story is told backwards",
    "the best friend wrote the anonymous notes", "the inheritance is a debt",
    "the ghost doesn't know she's dead", "the town isn't on any map",
    "the wedding was a cover for something else", "the two sisters are the same woman"]

  static let clues = ["a missing earring", "a train ticket", "a smudged signature",
    "a song on the radio", "a lipstick mark on a glass", "a recipe card", "a pressed flower",
    "a wrong number", "a borrowed coat", "a receipt from a hotel"]

  static let reveals = ["the wedding toast", "the reading of the will", "the final chapter",
    "a phone call at midnight", "the last page of a diary", "a dinner party", "the hen do"]

  static let firstLines = [
    "The dress arrived three days after the funeral, with a note in my sister's handwriting.",
    "Nobody in Little Brantham had ever seen a woman eat a whole cake alone, until Thursday.",
    "I was fired at 9:14, engaged by 11:30 and arrested before lunch.",
    "The house had been waiting for her, and it was not a patient house.",
    "My mother kept three secrets, and I found the first one in her make-up bag.",
    "It was the kind of party where everyone was pretending to be someone richer.",
    "The last thing I expected to find in lost property was my own name.",
    "On the morning of her fortieth birthday, Margot decided to become a thief.",
    "Every summer the sea gave something back; this year it was a man.",
    "There are two kinds of people at a wedding: guests and suspects.",
    "The bookshop closed for good on a Tuesday, which seemed unfair to Tuesdays.",
    "She had practised the apology for eleven years and still got it wrong.",
    "We were not, strictly speaking, allowed on the roof.",
    "The lipstick was called Scandal, and it lived up to its name.",
    "By the time the train stopped, there was one passenger fewer than when it started.",
    "Grandma's recipe book had one page glued shut.",
    "I had been dead for six days and nobody had noticed.",
    "The invitation said black tie; it didn't say anyone would die.",
    "It rained for forty days, and on the forty-first, she opened the shop.",
    "Love, said my aunt, is mostly paperwork.",
    "The first time I saw her, she was stealing my umbrella.",
    "Everyone in the village knew the Fairfax girls were trouble, which was half right.",
    "The wedding was off, the caterers were paid, and someone had to eat four hundred vol-au-vents.",
    "I found the letters the summer I turned thirty-five, under the floorboards of my own bedroom.",
    "Some women collect shoes; my sister collected husbands.",
  ]

  static let lastLines = ["And that, as far as anyone knows, was the end of it.",
    "She never wore red again.", "The shop is still there, if you know where to look.",
    "I kept the dress.", "We never did find out who sent the flowers.",
    "In the morning, the house was quiet.", "It was, all things considered, a very good wedding."]

  // People --------------------------------------------------------------------

  static let firstNames = ["Margot", "Iris", "Delphine", "Nell", "Ottilie", "Rosa", "Harriet",
    "Cleo", "June", "Vivian", "Esme", "Bea", "Saoirse", "Imogen", "Priya", "Lena", "Maud",
    "Frankie", "Theo", "Felix", "Jonah", "Rafe", "Kit", "Hugo", "Sol", "Arlo", "Ezra",
    "Benedict", "Malik", "Luca", "Ines", "Yara", "Clemence", "Odette", "Marguerite", "Tallulah"]

  /// For blurbs, whose heroine is "she".
  static let herNames = ["Margot", "Iris", "Delphine", "Nell", "Ottilie", "Rosa", "Harriet", "Cleo",
    "June", "Vivian", "Esme", "Bea", "Saoirse", "Imogen", "Priya", "Lena", "Maud", "Frankie",
    "Ines", "Yara", "Clemence", "Odette", "Marguerite", "Tallulah"]

  static let surnames = ["Ashworth", "Blackwood", "Vale", "Okafor", "Lindqvist", "Marchetti",
    "Fairfax", "Holloway", "Nakamura", "Quill", "Devereux", "Pemberton", "Castell", "Moreau",
    "Whitlock", "Achebe", "Sinclair", "Hartley", "Bellamy", "Rosewood", "Calloway", "Laurent"]

  static let jobs = ["florist", "forensic accountant", "wedding singer", "perfumer", "jewel thief",
    "art restorer", "lighthouse keeper", "makeup artist", "midwife", "tarot reader", "barrister",
    "pastry chef", "vintage dealer", "museum night guard", "ghostwriter", "stylist to the rich",
    "estate agent", "librarian", "marine biologist", "fashion editor", "con artist", "nurse",
    "vicar", "bridal seamstress", "private detective", "sommelier"]

  static let wants = ["wants to be forgiven", "wants the old life back", "wants to win at any cost",
    "wants to be left alone", "wants to find out who the real father is", "wants revenge, politely",
    "wants one perfect day", "wants to be taken seriously", "wants to leave town for good",
    "wants the truth, whatever it costs", "wants to fall in love before forty",
    "wants to buy back the family house"]

  static let secrets = ["can't swim, and has never told a soul", "is secretly married",
    "wrote the anonymous letters", "has a twin nobody knows about", "once stole a painting",
    "once faked a death", "is in love with the best friend's husband",
    "has been living under a false name", "still writes letters to a dead mother",
    "knows who started the fire", "won the lottery and told no one"]

  static let flaws = ["proud", "jealous", "reckless", "a beautiful liar", "too kind", "cowardly",
    "controlling", "vain", "stubborn", "impulsive", "secretive", "a terrible judge of men"]

  static let quirks = ["speaks in questions when nervous", "quotes old films",
    "always wears red lipstick", "collects other people's keys", "hums when lying",
    "never finishes a cup of tea", "counts everything", "names every houseplant",
    "only reads the last page first", "keeps a lipstick in every coat pocket"]

  static let needs = ["to accept some help", "to forgive and be forgiven", "to tell the truth",
    "to stop running", "to be loved exactly as they are", "to let the past go", "to stop apologising"]

  // Places --------------------------------------------------------------------

  static let places = ["a perfume counter in a department store", "an open-air swimming pool in winter",
    "a cramped dressing room", "a seaside guest house", "a bookshop with a secret back room",
    "a wedding marquee", "a Paris hotel suite", "a village fete", "an empty theatre",
    "a hospital chapel", "a rooftop bar", "a country kitchen", "a lost-property office",
    "a vintage boutique", "a cottage on a tidal island", "a ballroom gone to ruin",
    "a ferry crossing", "a florist's cold room"]

  static let times = ["just before dawn", "on New Year's Eve", "in the middle of a heatwave",
    "during a power cut", "the morning after the party", "in 1962", "at closing time",
    "on the longest night of the year", "on the first warm day of spring", "during a wedding"]

  static let smells = ["burnt sugar", "rain on hot pavement", "expensive perfume and cigarette smoke",
    "old paper", "lilies and bleach", "sea salt", "wet wool", "coffee and oranges",
    "candle wax", "fresh bread", "hairspray"]

  static let sounds = ["a dripping tap", "distant church bells", "a radio between stations",
    "someone laughing too loudly", "heels on marble", "gulls", "a dog barking two streets away",
    "a sewing machine", "a kettle coming to the boil", "rain on a skylight"]

  static let oddities = ["a single red glove on the table", "a clock that runs backwards",
    "a fresh bouquet nobody ordered", "a door that's always ajar", "a photograph turned to the wall",
    "footprints that stop in the middle of the room", "a wedding ring in the sugar bowl",
    "a coat still warm on its hook"]

  // Titles --------------------------------------------------------------------

  static let titleNouns = ["Lies", "Roses", "Secrets", "Summer", "Silk", "Salt", "Ashes", "Ink",
    "Glass", "Gold", "Promises", "Letters", "Thorns", "Lanterns", "Weddings", "Shadows", "Lemons",
    "Velvet", "Bones", "Hours", "Sisters", "Strangers", "Pearls", "Oranges", "Wolves", "Sparrows"]
  static let titleSingles = ["Garden", "Bookshop", "Heiress", "Dressmaker", "Lighthouse", "Hotel",
    "Island", "Wedding", "Inheritance", "Summer House", "Perfumer", "Night Train", "Orchard"]
  static let titleAdj = ["Velvet", "Little", "Wicked", "Beautiful", "Burning", "Quiet", "Golden",
    "Hidden", "Lovely", "Broken", "Midnight", "Forgotten", "Scandalous", "Unseen", "Bright",
    "Last", "Secret", "Dangerous"]

  // Talk ----------------------------------------------------------------------

  static let pairs = ["two sisters", "two ex-lovers", "two old school friends", "two rivals",
    "two strangers", "a mother and daughter", "a bride and her ex", "a detective and her suspect",
    "two thieves", "a boss and her assistant", "two widows", "a writer and her editor"]
  static let situations = ["stuck in a lift", "at a funeral buffet", "in a broken-down car",
    "waiting for test results", "at a hen party", "in a police cell", "at 3am in a kitchen",
    "trying on wedding dresses", "on a first date that is going badly", "at a perfume counter",
    "on the last ferry home"]
  static let lines = ["You kept it. All this time, you kept it.",
    "I never said I was sorry. I said I was leaving.", "That's not your coat.",
    "Don't look now, but she's here.", "Is that what you're wearing?",
    "We agreed never to talk about Prague.", "Tell me the truth, or tell me nothing.",
    "I've read your diary. Twice.", "She knows.", "You've changed your perfume.",
    "Whose lipstick is that?", "I'd have done the same, you know. Worse, probably."]
  static let bannedWords = ["love", "sorry", "money", "mother", "wedding", "no", "why", "dead"]

  // Craft ---------------------------------------------------------------------

  static let constraints = ["Write 300 words without the letter e", "Write the scene in dialogue only",
    "Write it in the second person", "Keep it in the present tense",
    "Every sentence must be under ten words", "Use all five senses on one page",
    "End every paragraph with a question", "Write a scene with no adjectives", "Tell it as a list",
    "Write a letter that is never sent", "Make the weather a character", "Write it as a recipe",
    "No dialogue at all", "Plant a lie the reader spots before the characters do",
    "Write exactly 100 words", "Write it as a string of text messages",
    "Describe a room so we know exactly who lives there",
    "Delete your favourite sentence and write a better one", "Use a word you have never used before",
    "Write the ending first", "Give every character a secret", "Open in the middle of an argument",
    "Write from the point of view of an object", "No word may be longer than two syllables"]

  static let poemTopics = ["the first coffee of the day", "a lost earring", "the sea in winter",
    "an old flame", "Sunday mornings", "your favourite lipstick", "a city at night",
    "your grandmother's hands", "the moment before sleep", "a dress you'll never wear",
    "the last day of summer", "a borrowed jumper", "a friend you've lost touch with"]

  /// Forms, simplest first: a rarer poem draws from further down the list.
  static let poemForms: [(String, String)] = [
    ("Haiku", "Three lines: five, seven and five syllables"),
    ("Acrostic", "The first letters spell the subject"),
    ("Limerick", "Five lines, AABBA, and a joke at the end"),
    ("Free verse", "No rhyme or metre, but every line breaks for a reason"),
    ("Cinquain", "Five lines of two, four, six, eight and two syllables"),
    ("Tanka", "Five lines: five, seven, five, seven, seven syllables"),
    ("Ode", "Praise it extravagantly"),
    ("Sonnet", "Fourteen lines, ABAB CDCD EFEF GG, a turn at line nine"),
    ("Pantoum", "Lines two and four of each verse become one and three of the next"),
    ("Ghazal", "Couplets, each ending on the same word"),
    ("Villanelle", "Nineteen lines, two refrains, ABA rhymes throughout"),
  ]

  static let genres = ["Regency Romance", "Cosy Mystery", "Space Opera", "Gothic Horror", "Rom-Com",
    "Literary Fiction", "Thriller", "Fairy Tale Retelling", "Historical Fiction", "Urban Fantasy",
    "Dark Academia", "Domestic Noir", "Magical Realism", "Western", "Cyberpunk", "Epistolary",
    "Heist", "Psychological Thriller", "Southern Gothic", "Paranormal Romance", "Comedy of Manners",
    "Folk Horror", "Spy Thriller", "Coming of Age", "Murder Mystery", "Time-Travel Romance",
    "Dystopia", "Satire", "Fable", "Beach Read", "Ghost Story", "Fantasy Romance"]

  static let povs = ["first person", "close third person", "second person", "omniscient narrator",
    "letters and diary entries", "two alternating narrators"]

  static let pitches = ["for a book club", "for a long-haul flight", "for a rainy weekend",
    "for a beach holiday", "for readers who stay up too late", "for a Christmas bestseller list"]

  static let fancyWords: [(String, String)] = [
    ("petrichor", "the smell of rain on dry earth"),
    ("vellichor", "the strange wistfulness of second-hand bookshops"),
    ("apricity", "the warmth of the sun in winter"),
    ("susurrus", "a whispering or rustling sound"),
    ("limerence", "the giddy, obsessive first stage of being in love"),
    ("hiraeth", "homesickness for a home you can't return to"),
    ("sprezzatura", "studied carelessness; making the difficult look easy"),
    ("crepuscular", "of twilight"),
    ("mellifluous", "sweet and smooth to hear"),
    ("halcyon", "idyllically happy and peaceful, usually of the past"),
    ("lagniappe", "a small extra gift, given for nothing"),
    ("quixotic", "idealistic to an impractical degree"),
    ("palimpsest", "something written over, with traces of the old still showing"),
    ("gossamer", "something light, thin and delicate"),
    ("lambent", "softly glowing or flickering"),
    ("eunoia", "beautiful thinking; goodwill"),
    ("saudade", "a deep, melancholy longing for something absent"),
    ("liminal", "on a threshold; in between"),
    ("sonder", "realising every passer-by has a life as vivid as yours"),
    ("effervescent", "bubbly; vivacious"),
    ("ineffable", "too great to be put into words"),
    ("tenebrous", "dark and shadowy"),
    ("solivagant", "wandering alone"),
    ("frisson", "a sudden thrill of excitement or fear"),
    ("ebullient", "cheerful and full of energy"),
    ("redolent", "fragrant; strongly reminiscent of"),
  ]

  static let discoveries = ["finds a stranger's diary in her handbag", "inherits a crumbling hotel",
    "is mistaken for a famous novelist", "witnesses a murder at a hen party",
    "receives a letter from her future self", "wakes up married to her rival",
    "finds her own obituary in the paper", "is left a perfume shop in Paris by a woman she never met"]
  static let goals = ["find the real author", "save the family business", "clear her name",
    "win back the one who got away", "solve the murder", "pay off a very bad man",
    "find out who she really is"]
  static let stakes = ["the wedding", "the summer ends", "the tide comes in", "her sister finds out",
    "the book goes to print", "midnight on New Year's Eve", "the house is sold"]

  // Pen names -----------------------------------------------------------------

  static let penAdj = ["Scarlett", "Rose", "Grey", "Winter", "Blue", "Black", "Sterling", "Sable"]

  // Cosmetics -----------------------------------------------------------------

  static let titleAdjs = ["Fabulous", "Caffeinated", "Unblocked", "Prolific", "Glamorous", "Midnight",
    "Velvet", "Fearless", "Iconic", "Certified", "Unstoppable", "Elegant", "Chaotic", "Cosy",
    "Legendary", "Award-Winning", "Bestselling", "Brilliant", "Sparkling", "Wicked", "Notorious",
    "Effortless"]
  static let titleRoles = ["Wordsmith", "Plot Witch", "Comma Queen", "Metaphor Maven",
    "Chapter Chaser", "Draft Duchess", "Prose Princess", "Dialogue Darling", "Story Sorceress",
    "Muse Wrangler", "Semicolon Sage", "Ink Goddess", "Page Turner", "Plot Twister",
    "Sentence Stylist", "Character Whisperer", "Simile Siren", "Verse Vixen", "Narrative Ninja",
    "Paragraph Diva", "Cliffhanger Countess"]
  static let titleOf = ["the Last Chapter", "the Blank Page", "the Plot Hole", "the Second Draft",
    "Purple Prose", "Many Notebooks", "the Final Edit", "the Midnight Oil", "the Happy Ending",
    "the Cliffhanger", "the Oxford Comma", "the Red Pen"]

  static let colourWords = ["Rose", "Midnight", "Champagne", "Velvet", "Blush", "Lilac", "Emerald",
    "Ruby", "Pearl", "Coral", "Sapphire", "Amber", "Plum", "Sunset", "Ivory", "Golden"]
  static let bannerThings = ["Swan", "Fox", "Moth", "Peony", "Raven", "Rose", "Crescent", "Butterfly",
    "Cat", "Owl", "Hare", "Lily", "Comet", "Quill", "Siren", "Phoenix"]

  // Legendary and Mythic gear carry a name.
  static let heroines = ["Seraphine", "Odette", "Marguerite", "Ines", "Delphine", "Colette",
    "Rosalind", "Beatrix", "Ottilie", "Clementine", "Vivienne", "Isadora", "Juniper", "Margot",
    "Lucinda", "Celestine", "Anouk", "Perpetua", "Wilhelmina", "Esmeralda"]
  static let epithets = ["Keeper of the Last Chapter", "the Unblocked", "Muse of Midnight",
    "Queen of the Comma", "Breaker of Blank Pages", "the Plot Witch", "Duchess of the Denouement",
    "Bringer of Plot Twists", "the Bestseller", "Heart of the Story", "the Final Draft"]

  static let seasonAdj = ["Velvet", "Midnight", "Golden", "Rose", "Silk", "Moonlit", "Crimson",
    "Ivory", "Honey", "Starlit", "Emerald", "Pearl", "Wild", "Secret", "Paper", "Gilded"]
  static let seasonNoun = ["Chapters", "Pages", "Letters", "Verses", "Drafts", "Stories", "Secrets",
    "Sonnets", "Diaries", "Inkwells", "Plots", "Promises", "Fables", "Endings", "Margins"]
}
