import Foundation
import SwiftUI

struct Topic: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var done: Bool
}

/// Longer-term "go deeper on this" topics, kept as a Markdown checklist in Parked Questions/Topics.md.
final class TopicStore: ObservableObject {
    static let shared = TopicStore()

    @Published private(set) var topics: [Topic] = []
    var open: [Topic] { topics.filter { !$0.done } }

    private let file = Store.shared.root.appendingPathComponent(Store.topicsFileName)

    private init() { reload() }

    func reload() {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return }
        topics = text.split(separator: "\n").compactMap { line in
            if line.hasPrefix("- [ ] ") { return Topic(title: String(line.dropFirst(6)), done: false) }
            if line.lowercased().hasPrefix("- [x] ") { return Topic(title: String(line.dropFirst(6)), done: true) }
            return nil
        }
    }

    func add(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        topics.append(Topic(title: t, done: false))
        save()
    }

    func markDone(_ topic: Topic) {
        guard let i = topics.firstIndex(where: { $0.id == topic.id }) else { return }
        topics[i].done = true
        save()
    }

    func delete(_ topic: Topic) {
        topics.removeAll { $0.id == topic.id }
        save()
    }

    private func save() {
        var s = "# Topics to revisit\n\n"
        for t in topics { s += "- [\(t.done ? "x" : " ")] \(t.title)\n" }
        try? s.write(to: file, atomically: true, encoding: .utf8)
    }
}

struct TopicsView: View {
    @ObservedObject var store = TopicStore.shared
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Add a topic, e.g. Michaelis–Menten equation", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit {
                    store.add(draft)
                    draft = ""
                }
                .padding(12)

            Divider()

            if store.open.isEmpty {
                Text("Nothing here yet. Add topics you want to understand more deeply.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.open) { topic in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(topic.title)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Button { withAnimation { store.markDone(topic) } } label: {
                                    Image(systemName: "checkmark.circle").font(.title3)
                                }
                                .buttonStyle(.borderless)
                                .help("Done: I've revisited this")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contextMenu {
                                Button("Delete", role: .destructive) { store.delete(topic) }
                            }
                            Divider()
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    })
                }
                .modifier(FitHeight(max: 480))
            }
        }
        .onAppear { fieldFocused = true }
    }
}

/// Sizes a ScrollView to its measured content (reported via ContentHeightKey), up to `max`.
struct FitHeight: ViewModifier {
    let max: CGFloat
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(height: min(Swift.max(height, 40), max))
            .onPreferenceChange(ContentHeightKey.self) { height = $0 }
    }
}
