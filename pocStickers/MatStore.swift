import SwiftUI
import UIKit

enum ShapeColor: String, CaseIterable, Codable {
    case yellow
    case pink
    case orange
    case purple
    case red
    case green
    case blue
    case indigo
    case teal

    var color: Color {
        switch self {
        case .yellow: .yellow
        case .pink: .pink
        case .orange: .orange
        case .purple: .purple
        case .red: .red
        case .green: .green
        case .blue: .blue
        case .indigo: .indigo
        case .teal: .teal
        }
    }
}

struct StoredItem: Codable {
    enum Kind: Codable {
        case image(String)
        case emoji(String)
        case symbol(String, ShapeColor)
        case text(String)
    }

    var id: UUID
    var kind: Kind
    var offsetX: Double
    var offsetY: Double
    var scale: Double
    var rotationDegrees: Double
    var format: TextFormat?
}

struct StoredBoard: Codable {
    var background: MatBackground
    var paper: MatPaper
    var items: [StoredItem]
    var stickers: [String]
    var guideHistory: [GuideSet]?
}

@MainActor
final class MatStore {
    private let directory: URL
    private var names: [ObjectIdentifier: String] = [:]
    private var retained: [String: UIImage] = [:]

    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }
    private var boardFile: URL { directory.appendingPathComponent("board.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("Board", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    func reset() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        names = [:]
        retained = [:]
    }

    func save(_ model: MatModel) {
        var used: Set<String> = []

        func name(for image: UIImage) -> String {
            if let existing = names[ObjectIdentifier(image)], retained[existing] === image {
                used.insert(existing)
                return existing
            }
            let fresh = UUID().uuidString + ".png"
            names[ObjectIdentifier(image)] = fresh
            retained[fresh] = image
            if let data = image.pngData() {
                try? data.write(to: imagesDirectory.appendingPathComponent(fresh), options: .atomic)
            }
            used.insert(fresh)
            return fresh
        }

        let items = model.items.map { item -> StoredItem in
            let kind: StoredItem.Kind
            switch item.kind {
            case .sticker(let image): kind = .image(name(for: image))
            case .emoji(let emoji): kind = .emoji(emoji)
            case .symbol(let symbol, let color): kind = .symbol(symbol, color)
            case .text(let text): kind = .text(text)
            }
            return StoredItem(
                id: item.id,
                kind: kind,
                offsetX: item.offset.width,
                offsetY: item.offset.height,
                scale: item.scale,
                rotationDegrees: item.rotation.degrees,
                format: item.format
            )
        }
        let library = model.stickers.map { name(for: $0) }
        let board = StoredBoard(
            background: model.background,
            paper: model.paper,
            items: items,
            stickers: library,
            guideHistory: model.guideHistory
        )

        guard let data = try? JSONEncoder().encode(board) else { return }
        try? data.write(to: boardFile, options: .atomic)

        let onDisk = (try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)) ?? []
        for file in onDisk where !used.contains(file) {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(file))
        }
        names = names.filter { used.contains($0.value) }
        retained = retained.filter { used.contains($0.key) }
    }

    func load(into model: MatModel) {
        guard let data = try? Data(contentsOf: boardFile),
              let board = try? JSONDecoder().decode(StoredBoard.self, from: data) else { return }

        var cache: [String: UIImage] = [:]
        func image(_ name: String) -> UIImage? {
            if let cached = cache[name] { return cached }
            guard let loaded = UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(name).path) else { return nil }
            cache[name] = loaded
            retained[name] = loaded
            names[ObjectIdentifier(loaded)] = name
            return loaded
        }

        model.background = board.background
        model.paper = board.paper
        model.guideHistory = board.guideHistory ?? []
        model.stickers = board.stickers.compactMap(image)
        model.items = board.items.compactMap { stored in
            let kind: MatItem.Kind
            switch stored.kind {
            case .image(let name):
                guard let loaded = image(name) else { return nil }
                kind = .sticker(loaded)
            case .emoji(let emoji): kind = .emoji(emoji)
            case .symbol(let symbol, let color): kind = .symbol(symbol, color)
            case .text(let text): kind = .text(text)
            }
            return MatItem(
                id: stored.id,
                kind: kind,
                offset: CGSize(width: stored.offsetX, height: stored.offsetY),
                scale: stored.scale,
                rotation: .degrees(stored.rotationDegrees),
                format: stored.format ?? TextFormat()
            )
        }
    }
}
