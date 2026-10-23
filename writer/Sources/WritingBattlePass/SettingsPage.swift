import SwiftUI
import AppKit
import PassCore

/// Her name, which apps count, the idle time, sounds, starting at login,
/// and the shop's treats - names and prices - which are hers to change.
struct SettingsPage: View {
  @ObservedObject var model: Model
  @State private var newName = ""
  @State private var newPrice = "1000"

  /// Writing apps the Mac might have, by their usual names, for the list.
  static let knownNames: [String: String] = [
    "com.microsoft.Word": "Microsoft Word", "com.apple.iWork.Pages": "Pages",
    "com.literatureandlatte.scrivener3": "Scrivener", "com.literatureandlatte.Scrivener": "Scrivener",
    "com.ulyssesapp.mac": "Ulysses", "pro.writer.mac": "iA Writer", "net.shinyfrog.bear": "Bear",
    "com.apple.Notes": "Notes", "com.apple.TextEdit": "TextEdit", "md.obsidian": "Obsidian",
    "com.google.Chrome.app.docs": "Google Docs (app)", "abnerworks.Typora": "Typora", "com.reedsy.studio": "Reedsy",
    "com.google.Chrome": "Google Chrome", "com.apple.Safari": "Safari",
  ]

  var body: some View {
    let st = model.st
    VStack(alignment: .leading, spacing: 16) {
      Panel {
        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text: "You")
          HStack {
            Text("Name").frame(width: 120, alignment: .leading)
            TextField("Your name", text: Binding(get: { model.st.profile.name },
                                                  set: { v in model.act { $0.st.profile.name = String(v.prefix(30)) } }))
              .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
          }
        }
      }

      Panel {
        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text: "Counting your typing", right: model.tapRunning ? "On" : "Off")
          if model.tapRunning {
            Label("Letters and words are being counted in your writing apps.", systemImage: "checkmark.circle.fill")
              .foregroundStyle(Theme.rarity(3)).font(Theme.ui(13, .semibold))
          } else {
            Text("To earn XP for every letter, the Mac needs to let this app count key presses: System Settings → Privacy & Security → Input Monitoring → turn on Writing Battle Pass. The clock still runs without it.")
              .font(Theme.ui(12.5)).fixedSize(horizontal: false, vertical: true)
            Button("Allow typing to count") { KeyTap.ask() }.buttonStyle(Pill(on: true))
          }
          Text("Only the number of keys pressed is counted. What you type is never read, kept or sent anywhere.")
            .font(Theme.ui(11.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
      }

      Panel {
        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text: "Writing apps", right: "The clock runs while one of these is in front and you're using it")
          Toggle("Count every app (chats and emails too)", isOn: Binding(get: { model.st.settings.everywhere },
                                                                          set: { v in model.act { $0.st.settings.everywhere = v } }))
            .toggleStyle(.switch)
          ForEach(appRows(), id: \.id) { app in
            HStack {
              Toggle(isOn: Binding(get: { model.st.settings.apps.contains(app.id) }, set: { model.toggleApp(app.id, $0) })) {
                VStack(alignment: .leading, spacing: 1) {
                  Text(app.name).font(Theme.ui(13, .semibold))
                  Text(appNote(app.id)).font(Theme.ui(10.5)).foregroundStyle(Theme.dim)
                }
              }
              .toggleStyle(.switch)
              .disabled(st.settings.everywhere)
            }
          }
          Text("LivingWriter and other writing apps switch on by themselves the first time you use them. Writing in a web browser (Google Docs, LivingWriter online)? Turn the browser on - but then all your browsing counts too.")
            .font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
          if let f = model.front { Text("In front right now: \(f.name)").font(Theme.ui(11.5)).foregroundStyle(Theme.dim) }
        }
      }

      Panel {
        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text: "The clock")
          Stepper(value: Binding(get: { model.st.settings.idle / 60 }, set: { v in model.act { $0.st.settings.idle = max(60, min(1800, v * 60)) } }),
                  in: 1...30, step: 1) {
            Text("Pause after \(Int(st.settings.idle / 60)) minute\(st.settings.idle == 60 ? "" : "s") without writing")
          }
          Toggle("Sounds", isOn: Binding(get: { model.st.settings.sound }, set: { v in model.act { $0.st.settings.sound = v } }))
            .toggleStyle(.switch)
          Toggle("Open when the Mac starts", isOn: Binding(get: { model.st.settings.autostart }, set: { model.setAutostart($0) }))
            .toggleStyle(.switch)
          Text("Closing the window doesn't stop the clock: it carries on from the menu bar (the pencil at the top of the screen). Quit from there to stop it.")
            .font(Theme.ui(11.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
      }

      Panel {
        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text: "Your treats", right: "About 600 coins an hour of writing")
          ForEach(st.rewards) { item in RewardRow(model: model, item: item) }
          HStack {
            TextField("A new treat, e.g. Spa Day Pass", text: $newName).textFieldStyle(.roundedBorder)
            TextField("Price", text: $newPrice).textFieldStyle(.roundedBorder).frame(width: 80)
            Button("Add") {
              let name = newName.trimmingCharacters(in: .whitespaces)
              guard !name.isEmpty else { return }
              model.act { $0.addReward(name: name, price: Int(newPrice) ?? 1000, icon: "gift", desc: "One of your own.") }
              newName = ""
            }
            .buttonStyle(Pill(on: !newName.isEmpty))
          }
          SureButton(label: "Put the treats back as they were") { model.act { $0.resetRewards() } }
        }
      }

      Panel {
        VStack(alignment: .leading, spacing: 8) {
          SectionTitle(text: "Your progress")
          Text(model.saveURL.path).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim).textSelection(.enabled)
          HStack {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.saveURL]) }.buttonStyle(Pill())
            Button("Show the welcome again") { model.stage.insert(StageItem(kind: .welcome), at: 0) }.buttonStyle(Pill())
          }
          Text("Saved every few seconds, with a backup of the one before.").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
        }
      }
    }
    .font(Theme.ui(13))
  }

  func appRows() -> [FrontApp] {
    var ids: [String] = []
    for id in Rules.writingApps + model.st.settings.apps + model.st.settings.seen.keys.sorted() + Watch.runningApps().map(\.id) where !ids.contains(id) {
      ids.append(id)
    }
    let running = Dictionary(Watch.runningApps().map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    let installed = ids.filter { id in
      model.st.settings.apps.contains(id) || running[id] != nil || model.st.settings.seen[id] != nil
        || NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }
    return installed.map { id in
      FrontApp(id: id, name: model.st.settings.seen[id]?.name ?? running[id] ?? SettingsPage.knownNames[id] ?? id)
    }
  }

  func appNote(_ id: String) -> String {
    if let s = model.st.settings.seen[id], s.letters > 0 { return "\(Fmt.num(s.letters)) letters typed here" }
    return id
  }
}

struct RewardRow: View {
  @ObservedObject var model: Model
  let item: ShopItem
  var body: some View {
    HStack(spacing: 8) {
      Icon(name: item.icon, size: 16, colour: Theme.coin)
      TextField("Name", text: Binding(get: { item.name }, set: { v in var i = item; i.name = v; model.act { $0.updateReward(i) } }))
        .textFieldStyle(.roundedBorder)
      TextField("Price", value: Binding(get: { item.price }, set: { v in var i = item; i.price = v; model.act { $0.updateReward(i) } }),
                format: .number)
        .textFieldStyle(.roundedBorder).frame(width: 90)
      Text("coins").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
      let owned = model.st.inv.passes[item.id] ?? 0
      SureButton(label: "Remove", disabled: owned > 0) { model.act { $0.removeReward(item.id) } }
        .help(owned > 0 ? "Redeem the ones you own first" : "Take it out of the shop")
    }
  }
}
