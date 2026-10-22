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
        case tape(TapeStyle)
        case stroke(DrawStroke)
    }

    var id: UUID
    var kind: Kind
    var offsetX: Double
    var offsetY: Double
    var scale: Double
    var rotationDegrees: Double
    var format: TextFormat?
}

struct StoredPage: Codable {
    var background: MatBackground
    var paper: MatPaper
    var items: [StoredItem]
}

struct StoredGlobals: Codable {
    var stickers: [String]
    var guideHistory: [GuideSet]
}

struct StoredLibrary: Codable {
    var journals: [Journal]
    var activeJournalID: UUID?
}

private struct LegacyBoard: Codable {
    var background: MatBackground
    var paper: MatPaper
    var items: [StoredItem]
    var stickers: [String]
    var guideHistory: [GuideSet]?
}

@MainActor
final class MatStore {
    static let shared = MatStore()

    private let directory: URL
    private let legacyDirectory: URL
    private(set) var migratedPageID: UUID?
    private var names: [ObjectIdentifier: String] = [:]
    private var retained: [String: UIImage] = [:]

    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }
    private var pagesDirectory: URL { directory.appendingPathComponent("pages", isDirectory: true) }
    private var thumbsDirectory: URL { directory.appendingPathComponent("thumbs", isDirectory: true) }
    private var libraryFile: URL { directory.appendingPathComponent("journals.json") }
    private var globalsFile: URL { directory.appendingPathComponent("globals.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("Journals", isDirectory: true)
        legacyDirectory = base.appendingPathComponent("Board", isDirectory: true)
        if CommandLine.arguments.contains("-resetBoard") {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: legacyDirectory)
        }
        for url in [imagesDirectory, pagesDirectory, thumbsDirectory] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: libraryFile.path) {
            migratedPageID = migrateLegacyBoard()
        }
    }

    private func pageFile(_ id: UUID) -> URL { pagesDirectory.appendingPathComponent("\(id.uuidString).json") }
    private func thumbFile(_ id: UUID) -> URL { thumbsDirectory.appendingPathComponent("\(id.uuidString).png") }

    // MARK: Library

    func loadLibrary() -> StoredLibrary? {
        guard let data = try? Data(contentsOf: libraryFile) else { return nil }
        return try? JSONDecoder().decode(StoredLibrary.self, from: data)
    }

    func saveLibrary(_ library: StoredLibrary) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: libraryFile, options: .atomic)
    }

    /// Moves the old single-board save into the new layout as one page.
    func migrateLegacyBoard() -> UUID? {
        let legacyFile = legacyDirectory.appendingPathComponent("board.json")
        guard FileManager.default.fileExists(atPath: legacyFile.path),
              let data = try? Data(contentsOf: legacyFile),
              let board = try? JSONDecoder().decode(LegacyBoard.self, from: data) else { return nil }

        let legacyImages = legacyDirectory.appendingPathComponent("images", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: legacyImages.path)) ?? []
        for file in files {
            let target = imagesDirectory.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: target.path) {
                try? FileManager.default.copyItem(at: legacyImages.appendingPathComponent(file), to: target)
            }
        }

        let pageID = UUID()
        let page = StoredPage(background: board.background, paper: board.paper, items: board.items)
        if let pageData = try? JSONEncoder().encode(page) {
            try? pageData.write(to: pageFile(pageID), options: .atomic)
        }
        let globals = StoredGlobals(stickers: board.stickers, guideHistory: board.guideHistory ?? [])
        if let globalsData = try? JSONEncoder().encode(globals) {
            try? globalsData.write(to: globalsFile, options: .atomic)
        }
        let archived = legacyDirectory.deletingLastPathComponent().appendingPathComponent("Board.migrated", isDirectory: true)
        try? FileManager.default.removeItem(at: archived)
        try? FileManager.default.moveItem(at: legacyDirectory, to: archived)
        return pageID
    }

    // MARK: Saving

    private func imageName(for image: UIImage) -> String {
        if let existing = names[ObjectIdentifier(image)], retained[existing] === image {
            return existing
        }
        let fresh = UUID().uuidString + ".png"
        names[ObjectIdentifier(image)] = fresh
        retained[fresh] = image
        if let data = image.pngData() {
            try? data.write(to: imagesDirectory.appendingPathComponent(fresh), options: .atomic)
        }
        return fresh
    }

    func saveAll(_ model: MatModel) {
        if let pageID = model.pageID {
            let items = model.items.map { item -> StoredItem in
                let kind: StoredItem.Kind
                switch item.kind {
                case .sticker(let image): kind = .image(imageName(for: image))
                case .emoji(let emoji): kind = .emoji(emoji)
                case .symbol(let symbol, let color): kind = .symbol(symbol, color)
                case .text(let text): kind = .text(text)
                case .tape(let style): kind = .tape(style)
                case .stroke(let stroke): kind = .stroke(stroke)
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
            let page = StoredPage(background: model.background, paper: model.paper, items: items)
            if let data = try? JSONEncoder().encode(page) {
                try? data.write(to: pageFile(pageID), options: .atomic)
            }
        }

        let globals = StoredGlobals(stickers: model.stickers.map { imageName(for: $0) }, guideHistory: model.guideHistory)
        if let data = try? JSONEncoder().encode(globals) {
            try? data.write(to: globalsFile, options: .atomic)
        }
        pruneImages()
    }

    func deletePage(_ id: UUID) {
        try? FileManager.default.removeItem(at: pageFile(id))
        try? FileManager.default.removeItem(at: thumbFile(id))
        pruneImages()
    }

    private func pruneImages() {
        var used: Set<String> = []
        let decoder = JSONDecoder()
        let pageFiles = (try? FileManager.default.contentsOfDirectory(at: pagesDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in pageFiles where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), let page = try? decoder.decode(StoredPage.self, from: data) else { continue }
            for item in page.items {
                if case .image(let name) = item.kind { used.insert(name) }
            }
        }
        if let data = try? Data(contentsOf: globalsFile), let globals = try? decoder.decode(StoredGlobals.self, from: data) {
            used.formUnion(globals.stickers)
        }
        let onDisk = (try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)) ?? []
        for file in onDisk where !used.contains(file) {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(file))
        }
        names = names.filter { used.contains($0.value) }
        retained = retained.filter { used.contains($0.key) }
    }

    // MARK: Loading

    private func loadImage(_ name: String, cache: inout [String: UIImage]) -> UIImage? {
        if let cached = cache[name] { return cached }
        guard let loaded = UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(name).path) else { return nil }
        cache[name] = loaded
        retained[name] = loaded
        names[ObjectIdentifier(loaded)] = name
        return loaded
    }

    func loadGlobals(into model: MatModel) {
        guard let data = try? Data(contentsOf: globalsFile),
              let globals = try? JSONDecoder().decode(StoredGlobals.self, from: data) else { return }
        var cache: [String: UIImage] = [:]
        model.stickers = globals.stickers.compactMap { loadImage($0, cache: &cache) }
        model.guideHistory = globals.guideHistory
    }

    func loadPage(_ id: UUID, into model: MatModel) {
        guard let data = try? Data(contentsOf: pageFile(id)),
              let page = try? JSONDecoder().decode(StoredPage.self, from: data) else { return }
        var cache: [String: UIImage] = [:]
        model.background = page.background
        model.paper = page.paper
        model.items = page.items.compactMap { stored in
            let kind: MatItem.Kind
            switch stored.kind {
            case .image(let name):
                guard let loaded = loadImage(name, cache: &cache) else { return nil }
                kind = .sticker(loaded)
            case .emoji(let emoji): kind = .emoji(emoji)
            case .symbol(let symbol, let color): kind = .symbol(symbol, color)
            case .text(let text): kind = .text(text)
            case .tape(let style): kind = .tape(style)
            case .stroke(let stroke): kind = .stroke(stroke)
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

    // MARK: Thumbnails

    func saveThumbnail(_ png: Data, for id: UUID) {
        try? png.write(to: thumbFile(id), options: .atomic)
    }

    func thumbnail(for id: UUID) -> UIImage? {
        UIImage(contentsOfFile: thumbFile(id).path)
    }
}
