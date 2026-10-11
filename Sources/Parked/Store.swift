import Foundation

struct ParkedItem: Identifiable, Equatable {
    let id: String          // file basename, e.g. 2026-10-10_143012
    var question: String
    var answer: String
    let created: Date
    let app: String?
    let imageName: String?
    let folder: URL

    var fileURL: URL { folder.appendingPathComponent(id + ".md") }
    var imageURL: URL? { imageName.map { folder.appendingPathComponent($0) } }
}

/// Questions live as plain Markdown files (+ PNG screenshots) in ~/Documents/Parked Questions.
/// Finished ones are moved to the Done subfolder rather than deleted.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var items: [ParkedItem] = []

    let root: URL
    let doneDir: URL

    private let iso = ISO8601DateFormatter()
    private let idFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
    static let topicsFileName = "Topics.md"
    private static let answerMarker = "\n\n## Answer\n\n"

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("Parked Questions", isDirectory: true)
        doneDir = root.appendingPathComponent("Done", isDirectory: true)
        try? FileManager.default.createDirectory(at: doneDir, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let loaded = files
            .filter { $0.pathExtension == "md" && $0.lastPathComponent != Store.topicsFileName }
            .compactMap { parse($0) }
            .sorted { $0.created < $1.created }
        if loaded != items { items = loaded }
    }

    func add(question: String, screenshot: URL?, app: String?) {
        let now = Date()
        var id = idFormatter.string(from: now)
        var n = 2
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(id + ".md").path) {
            id = idFormatter.string(from: now) + "-\(n)"
            n += 1
        }

        var imageName: String?
        if let screenshot, FileManager.default.fileExists(atPath: screenshot.path) {
            let name = id + ".png"
            do {
                try FileManager.default.moveItem(at: screenshot, to: root.appendingPathComponent(name))
                imageName = name
            } catch {
                NSLog("Parked: couldn't save screenshot: \(error)")
            }
        }

        let item = ParkedItem(id: id, question: question, answer: "", created: now,
                              app: app, imageName: imageName, folder: root)
        write(item)
        items.append(item)
    }

    func updateAnswer(_ item: ParkedItem, answer: String) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].answer = answer
        write(items[i])
    }

    func markDone(_ item: ParkedItem) {
        let fm = FileManager.default
        try? fm.moveItem(at: item.fileURL, to: doneDir.appendingPathComponent(item.id + ".md"))
        if let img = item.imageURL, let name = item.imageName {
            try? fm.moveItem(at: img, to: doneDir.appendingPathComponent(name))
        }
        items.removeAll { $0.id == item.id }
    }

    // MARK: - File format

    private func write(_ item: ParkedItem) {
        var s = "---\ncreated: \(iso.string(from: item.created))\n"
        if let app = item.app { s += "app: \(app)\n" }
        if let img = item.imageName { s += "image: \(img)\n" }
        s += "---\n\n\(item.question)"
        if let img = item.imageName { s += "\n\n![](\(img))" }
        if !item.answer.isEmpty { s += Self.answerMarker + item.answer }
        s += "\n"
        try? s.write(to: item.fileURL, atomically: true, encoding: .utf8)
    }

    private func parse(_ url: URL) -> ParkedItem? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var meta: [String: String] = [:]
        var body = text

        if text.hasPrefix("---\n"), let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) {
            let header = text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound]
            for line in header.split(separator: "\n") {
                if let colon = line.firstIndex(of: ":") {
                    let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                    let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    meta[key] = value
                }
            }
            body = String(text[end.upperBound...])
        }

        var question = body
        var answer = ""
        if let r = body.range(of: Self.answerMarker) {
            question = String(body[..<r.lowerBound])
            answer = String(body[r.upperBound...])
        }
        if let img = meta["image"] {
            question = question.replacingOccurrences(of: "![](\(img))", with: "")
        }

        let id = url.deletingPathExtension().lastPathComponent
        let created = meta["created"].flatMap { iso.date(from: $0) }
            ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
            ?? Date()

        return ParkedItem(
            id: id,
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
            created: created,
            app: meta["app"],
            imageName: meta["image"],
            folder: url.deletingLastPathComponent()
        )
    }
}
