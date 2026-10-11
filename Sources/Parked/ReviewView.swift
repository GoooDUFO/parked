import AppKit
import ServiceManagement
import SwiftUI

struct ReviewView: View {
    @ObservedObject var store = Store.shared
    let onPark: () -> Void
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var listHeight: CGFloat = 0
    @State private var showingTopics = false
    @ObservedObject private var topics = TopicStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if showingTopics {
                    Button { showingTopics = false } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                        .help("Back to questions")
                    Text("Topics to revisit").font(.headline)
                    Spacer()
                } else {
                    Text("Parked questions").font(.headline)
                    Spacer()
                    Button(action: onPark) { Label("Park", systemImage: "plus") }
                        .help("⌥⌘P")
                }
            }
            .frame(height: 24)
            .padding(12)

            Divider()

            if showingTopics {
                TopicsView()
            } else if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle").font(.system(size: 34)).foregroundStyle(.green)
                    Text("All clear").font(.headline)
                    Text("⌥⌘P to park a question")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                // Size the scroll area to its content so the panel grows and shrinks with the list.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.items) { item in
                            ItemRow(item: item)
                            Divider()
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    })
                }
                .frame(height: min(max(listHeight, 80), 560))
                .onPreferenceChange(ContentHeightKey.self) { listHeight = $0 }
            }

            Divider()

            HStack {
                Button(topics.open.isEmpty ? "Topics" : "Topics (\(topics.open.count))") { showingTopics.toggle() }
                    .fontWeight(showingTopics ? .semibold : .regular)
                Button("Open folder") { NSWorkspace.shared.open(store.root) }
                Toggle("Open at login", isOn: $openAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: openAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            NSLog("Parked: login item change failed: \(error)")
                            openAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .padding(10)
        }
        .frame(width: 340)
    }
}

struct ItemRow: View {
    let item: ParkedItem
    @State private var answer: String
    @State private var showAnswer: Bool
    @State private var flash: String?

    init(item: ParkedItem) {
        self.item = item
        _answer = State(initialValue: item.answer)
        _showAnswer = State(initialValue: !item.answer.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if let url = item.imageURL, let img = NSImage(contentsOf: url) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                        .onTapGesture { copyImage(url) }
                        .help("Drag into Claude, or click to copy the image")
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.question).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button { withAnimation { Store.shared.markDone(item) } } label: {
                    Image(systemName: "checkmark.circle").font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Done (moves it to the Done folder)")
            }

            HStack(spacing: 12) {
                Button("Copy for Claude", action: copyQuestion)
                Button(showAnswer ? "Hide answer" : "Add answer") { showAnswer.toggle() }
                if !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Copy as card", action: copyCard)
                        .help("Copies “question >> answer” for RemNote")
                }
                Spacer()
                if let flash { Text(flash).font(.caption).foregroundStyle(.green) }
            }
            .buttonStyle(.borderless)
            .font(.callout)

            if showAnswer {
                TextField("Paste the gist of the answer…", text: $answer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...8)
                    .onChange(of: answer) { _, new in Store.shared.updateAnswer(item, answer: new) }
            }
        }
        .padding(12)
    }

    private var subtitle: String {
        let when = item.created.formatted(.relative(presentation: .named))
        return [when, item.app].compactMap { $0 }.joined(separator: " · ")
    }

    private func copyQuestion() {
        // One clipboard item carrying both the text and the image, so apps that accept both get both.
        let entry = NSPasteboardItem()
        entry.setString(item.question, forType: .string)
        if let url = item.imageURL, let png = try? Data(contentsOf: url) {
            entry.setData(png, forType: .png)
        }
        setClipboard { $0.writeObjects([entry]) }
        show("Copied")
    }

    private func copyCard() {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        setClipboard { $0.setString("\(item.question) >> \(a)", forType: .string) }
        show("Card copied")
    }

    private func copyImage(_ url: URL) {
        guard let img = NSImage(contentsOf: url) else { return }
        setClipboard { $0.writeObjects([img]) }
        show("Image copied")
    }

    private func setClipboard(_ write: (NSPasteboard) -> Void) {
        let pb = NSPasteboard.general
        pb.clearContents()
        write(pb)
    }

    private func show(_ message: String) {
        flash = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if flash == message { flash = nil } }
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
