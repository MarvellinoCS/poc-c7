import ImageIO
import UIKit.UIGestureRecognizerSubclass
import PhotosUI
import SwiftUI

struct MatItem: Identifiable {
    enum Kind {
        case sticker(UIImage)
        case emoji(String)
        case symbol(String, ShapeColor)
        case text(String)
        case tape(TapeStyle)
        case stroke(DrawStroke)
    }

    var id = UUID()
    var kind: Kind
    var offset = CGSize.zero
    var scale: CGFloat = 1
    var rotation = Angle.zero
    var format = TextFormat()

    var readout: String {
        var text = "x=\(Int(offset.width.rounded())) y=\(Int(offset.height.rounded())) s=\(String(format: "%.2f", scale)) r=\(Int(rotation.degrees.rounded()))"
        if case .text(let content) = kind {
            let align = TextAlign.allCases.firstIndex(of: format.align) ?? 0
            text += " b=\(format.bold ? 1 : 0) i=\(format.italic ? 1 : 0) u=\(format.underline ? 1 : 0) st=\(format.strike ? 1 : 0)"
            text += " sz=\(Int(format.style.size)) al=\(align) bl=\(content.hasPrefix("• ") ? 1 : 0)"
        }
        return text
    }
}

enum TextStyle: String, CaseIterable, Codable, Identifiable {
    case title
    case heading
    case subheading
    case body

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var size: CGFloat {
        switch self {
        case .title: 34
        case .heading: 26
        case .subheading: 20
        case .body: 18
        }
    }

    var previewSize: CGFloat {
        switch self {
        case .title: 22
        case .heading: 19
        case .subheading: 15
        case .body: 15
        }
    }

    var weight: Font.Weight {
        switch self {
        case .title, .heading: .bold
        case .subheading: .semibold
        case .body: .regular
        }
    }
}

enum TextTint: String, CaseIterable, Codable, Identifiable {
    case ink
    case red
    case orange
    case green
    case blue
    case purple
    case pink

    var id: String { rawValue }

    var title: String { self == .ink ? "Default" : rawValue.capitalized }

    func color(automatic: Color) -> Color {
        switch self {
        case .ink: automatic
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }
}

enum TextHighlight: String, CaseIterable, Codable, Identifiable {
    case yellow
    case green
    case pink
    case blue

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .yellow: Color.yellow.opacity(0.5)
        case .green: Color.green.opacity(0.4)
        case .pink: Color.pink.opacity(0.4)
        case .blue: Color.blue.opacity(0.35)
        }
    }
}

enum TextAlign: String, CaseIterable, Codable {
    case leading
    case center
    case trailing

    var alignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var symbol: String {
        switch self {
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }

    var next: TextAlign {
        switch self {
        case .leading: .center
        case .center: .trailing
        case .trailing: .leading
        }
    }
}

struct TextFormat: Codable, Equatable, Hashable {
    var style = TextStyle.body
    var bold = false
    var italic = false
    var underline = false
    var strike = false
    var tint = TextTint.ink
    var highlight: TextHighlight?
    var align = TextAlign.leading
}

struct FormattedText: ViewModifier {
    let format: TextFormat
    let color: Color

    private var font: Font {
        let base = Font.system(size: format.style.size, weight: format.bold ? .bold : format.style.weight)
        return format.italic ? base.italic() : base
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .underline(format.underline)
            .strikethrough(format.strike)
            .foregroundStyle(color)
            .multilineTextAlignment(format.align.alignment)
            .background(format.highlight?.color ?? .clear)
    }
}

enum MatPaper: String, CaseIterable, Identifiable, Codable {
    case grid
    case dots
    case lines
    case plain

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .grid: "square.grid.3x3"
        case .dots: "circle.grid.3x3"
        case .lines: "line.3.horizontal"
        case .plain: "square"
        }
    }
}

enum MatBackground: String, CaseIterable, Identifiable, Codable {
    case white
    case cream
    case mint
    case sky
    case blush
    case ink

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .white: Color(white: 0.98)
        case .cream: Color(red: 0.98, green: 0.95, blue: 0.88)
        case .mint: Color(red: 0.86, green: 0.96, blue: 0.91)
        case .sky: Color(red: 0.86, green: 0.92, blue: 0.99)
        case .blush: Color(red: 0.99, green: 0.89, blue: 0.91)
        case .ink: Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }
}

struct PaperView: View {
    let style: MatPaper
    let background: MatBackground

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            let line = background == .ink ? Color.white.opacity(0.09) : Color.black.opacity(0.07)
            switch style {
            case .grid:
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(line), lineWidth: 1)
            case .lines:
                var path = Path()
                var y: CGFloat = spacing
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(line), lineWidth: 1)
            case .dots:
                var path = Path()
                var y: CGFloat = spacing
                while y < size.height {
                    var x: CGFloat = spacing
                    while x < size.width {
                        path.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                        x += spacing
                    }
                    y += spacing
                }
                context.fill(path, with: .color(line.opacity(1.8)))
            case .plain:
                break
            }
        }
        .background(background.color)
    }
}

@Observable
@MainActor
final class MatModel {
    var items: [MatItem] = []
    var stickers: [UIImage] = []
    var selection: UUID?
    var touchOwner: UUID?
    var guides: [String] = []
    var guideHistory: [GuideSet] = []
    var sizes: [UUID: CGSize] = [:]
    var editingID: UUID?
    var background = MatBackground.white
    var paper = MatPaper.grid
    private var history: [[MatItem]] = []
    private let store: MatStore?
    private var saveTask: Task<Void, Never>?
    var pageID: UUID?
    var onPersisted: ((UUID) -> Void)?

    init(persistent: Bool = true) {
        if persistent {
            let store = MatStore.shared
            self.store = store
            store.loadGlobals(into: self)
        } else {
            store = nil
        }
    }

    func openPage(_ id: UUID) {
        if pageID != nil {
            saveNow()
        }
        saveTask?.cancel()
        clearPage()
        store?.loadPage(id, into: self)
        pageID = id
    }

    func detachPage() {
        saveTask?.cancel()
        pageID = nil
        clearPage()
    }

    private func clearPage() {
        items = []
        history = []
        selection = nil
        editingID = nil
        touchOwner = nil
        guides = []
        sizes = [:]
        formatOpen = false
        background = .white
        paper = .grid
    }

    func saveThumbnail(_ png: Data) {
        guard let pageID else { return }
        store?.saveThumbnail(png, for: pageID)
    }

    var signature: Int {
        var hasher = Hasher()
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.offset.width)
            hasher.combine(item.offset.height)
            hasher.combine(item.scale)
            hasher.combine(item.rotation.degrees)
            if case .text(let text) = item.kind {
                hasher.combine(text)
                hasher.combine(item.format)
            }
        }
        hasher.combine(stickers.count)
        hasher.combine(guideHistory.count)
        hasher.combine(background)
        hasher.combine(paper)
        return hasher.finalize()
    }

    func scheduleSave() {
        guard store != nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        store?.saveAll(self)
        if let pageID {
            onPersisted?(pageID)
        }
    }

    var canUndo: Bool { !history.isEmpty }

    func checkpoint() {
        history.append(items)
        if history.count > 40 {
            history.removeFirst()
        }
    }

    func undo() {
        guard let previous = history.popLast() else { return }
        items = previous
        selection = nil
        editingID = nil
    }

    func recordGuides(_ questions: [String], feeling: Feeling?, need: Need?, usedModel: Bool) {
        guides = questions
        guard !questions.isEmpty, let feeling, let need else { return }
        guideHistory.insert(
            GuideSet(feeling: feeling.rawValue, need: need.rawValue, questions: questions, usedModel: usedModel),
            at: 0
        )
        if guideHistory.count > 20 {
            guideHistory.removeLast(guideHistory.count - 20)
        }
    }

    func clear() {
        guard !items.isEmpty else { return }
        checkpoint()
        items = []
        selection = nil
        editingID = nil
    }

    func addSticker(_ image: UIImage) {
        stickers.append(image)
        place(.sticker(image))
    }

    func place(_ kind: MatItem.Kind) {
        checkpoint()
        var item = MatItem(kind: kind)
        item.offset = CGSize(width: .random(in: -60...60), height: .random(in: -80...80))
        items.append(item)
        selection = item.id
    }

    func placeTape(_ style: TapeStyle) {
        place(.tape(style))
        if let index = items.indices.last {
            items[index].rotation = .degrees(.random(in: -8...8))
        }
    }

    func addStroke(_ canvasPoints: [CGPoint], canvas: CGSize, width: CGFloat, color: PenColor) {
        guard let made = DrawStroke.make(from: canvasPoints, width: width, color: color) else { return }
        checkpoint()
        var item = MatItem(kind: .stroke(made.stroke))
        item.offset = CGSize(width: made.center.x - canvas.width / 2, height: made.center.y - canvas.height / 2)
        items.append(item)
    }

    func addText() {
        place(.text(""))
    }

    func beginEditing(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), case .text = item.kind else { return }
        if editingID != id {
            checkpoint()
        }
        selection = id
        editingID = id
    }

    func updateText(_ id: UUID, to text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].kind = .text(text)
    }

    func finishEditing() {
        editingID = nil
    }

    var formatOpen = false
    var focusTick = 0

    enum ListKind {
        case bullet
        case dash
        case numbered
    }

    private var textIndex: Int? {
        guard let id = editingID ?? selection,
              let index = items.firstIndex(where: { $0.id == id }),
              case .text = items[index].kind else { return nil }
        return index
    }

    var currentFormat: TextFormat? {
        textIndex.map { items[$0].format }
    }

    func updateFormat(_ change: (inout TextFormat) -> Void) {
        guard let index = textIndex else { return }
        checkpoint()
        change(&items[index].format)
    }

    private static func split(_ line: String) -> (indent: String, marker: String, body: String) {
        let indent = String(line.prefix(while: { $0 == " " }))
        let rest = String(line.dropFirst(indent.count))
        for marker in ["• ", "– "] where rest.hasPrefix(marker) {
            return (indent, marker, String(rest.dropFirst(marker.count)))
        }
        let digits = rest.prefix(while: { $0.isNumber })
        if !digits.isEmpty, rest.dropFirst(digits.count).hasPrefix(". ") {
            let marker = String(rest.prefix(digits.count + 2))
            return (indent, marker, String(rest.dropFirst(marker.count)))
        }
        return (indent, "", rest)
    }

    func applyList(_ kind: ListKind) {
        guard let index = textIndex, case .text(let text) = items[index].kind else { return }
        checkpoint()
        let lines = text.components(separatedBy: "\n").map(Self.split)
        let allMatch = lines.allSatisfy { part in
            switch kind {
            case .bullet: part.marker == "• "
            case .dash: part.marker == "– "
            case .numbered: part.marker.hasSuffix(". ") && part.marker != "• " && part.marker != "– "
            }
        }
        let rebuilt = lines.enumerated().map { number, part -> String in
            let marker: String
            switch kind {
            case .bullet: marker = "• "
            case .dash: marker = "– "
            case .numbered: marker = "\(number + 1). "
            }
            return part.indent + (allMatch ? "" : marker) + part.body
        }
        items[index].kind = .text(rebuilt.joined(separator: "\n"))
    }

    func indent(_ delta: Int) {
        guard let index = textIndex, case .text(let text) = items[index].kind else { return }
        checkpoint()
        let lines = text.components(separatedBy: "\n").map { line -> String in
            if delta > 0 {
                return "    " + line
            }
            let spaces = min(4, line.prefix(while: { $0 == " " }).count)
            return String(line.dropFirst(spaces))
        }
        items[index].kind = .text(lines.joined(separator: "\n"))
    }

    var selectedIsText: Bool {
        guard let selection, let item = items.first(where: { $0.id == selection }) else { return false }
        if case .text = item.kind { return true }
        return false
    }

    func contains(_ item: MatItem, point: CGPoint, canvas: CGSize, lift: (MatItem) -> CGFloat = { _ in 0 }) -> Bool {
        guard let size = sizes[item.id] else { return false }
        let center = CGPoint(
            x: canvas.width / 2 + item.offset.width,
            y: canvas.height / 2 + item.offset.height + lift(item)
        )
        let dx = point.x - center.x
        let dy = point.y - center.y
        let angle = -item.rotation.radians
        let x = (dx * cos(angle) - dy * sin(angle)) / item.scale
        let y = (dx * sin(angle) + dy * cos(angle)) / item.scale
        let slop = 10 / max(item.scale, 0.3)
        if case .stroke(let stroke) = item.kind {
            return stroke.distance(to: CGPoint(x: x, y: y)) <= stroke.width / 2 + 14 / max(item.scale, 0.3)
        }
        return abs(x) <= size.width / 2 + slop && abs(y) <= size.height / 2 + slop
    }

    func item(at point: CGPoint, canvas: CGSize, lift: (MatItem) -> CGFloat = { _ in 0 }) -> UUID? {
        var order = Array(items.reversed())
        if let editingID, let index = order.firstIndex(where: { $0.id == editingID }) {
            order.insert(order.remove(at: index), at: 0)
        }
        return order.first { contains($0, point: point, canvas: canvas, lift: lift) }?.id
    }

    func touchBegan(_ id: UUID) {
        guard touchOwner == nil else { return }
        if editingID != nil && editingID != id {
            finishEditing()
        }
        touchOwner = id
        selection = id
    }

    func touchEnded(_ id: UUID) {
        if touchOwner == id {
            touchOwner = nil
        }
    }

    func deleteSelected() {
        guard let selection else { return }
        checkpoint()
        items.removeAll { $0.id == selection }
        self.selection = nil
    }

    func bringSelectedToFront() {
        guard let selection, let index = items.firstIndex(where: { $0.id == selection }) else { return }
        checkpoint()
        items.append(items.remove(at: index))
    }
}

struct MatItemView: View {
    let item: MatItem
    let isSelected: Bool
    let isEditing: Bool
    let showPlaceholder: Bool
    let lift: CGFloat
    let textColor: Color
    let focusTick: Int
    let onTouchBegan: () -> Void
    let onTouchEnded: () -> Void
    let onTap: () -> Void
    let onSize: (CGSize) -> Void
    let onTextChange: (String) -> Void
    let onEdit: () -> Void

    @GestureState private var isTouching = false
    @FocusState private var isFocused: Bool

    var body: some View {
        content
            .padding(6)
            .contentShape(hitShape)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize($0) }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
            .scaleEffect(item.scale)
            .rotationEffect(item.rotation)
            .offset(x: item.offset.width, y: item.offset.height + lift)
            .animation(.easeOut(duration: 0.2), value: lift)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouching) { _, state, _ in state = true },
                including: isEditing ? .none : .all
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { onEdit() },
                including: isEditing ? .none : .all
            )
            .simultaneousGesture(
                TapGesture().onEnded { onTap() },
                including: isEditing ? .none : .all
            )
            .onChange(of: isTouching) {
                if isTouching {
                    onTouchBegan()
                } else {
                    onTouchEnded()
                }
            }
            .onChange(of: focusTick) {
                if isEditing {
                    isFocused = true
                }
            }
    }

    private var hitShape: AnyShape {
        if case .stroke(let stroke) = item.kind {
            let reach = StrokeStyle(lineWidth: stroke.width + 24, lineCap: .round, lineJoin: .round)
            return AnyShape(stroke.path(offsetBy: 6).strokedPath(reach))
        }
        return AnyShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .tape(let style):
            TapeView(style: style)
        case .stroke(let stroke):
            StrokeView(stroke: stroke)
        case .sticker(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 170)
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: 64))
        case .symbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: 64))
                .foregroundStyle(color.color)
        case .text(let text):
            let format = item.format
            let color = format.tint.color(automatic: textColor)
            if isEditing {
                Text(text.isEmpty ? "Type here" : text + " ")
                    .modifier(FormattedText(format: format, color: color))
                    .opacity(0)
                    .overlay {
                        TextField(
                            text: Binding(get: { text }, set: onTextChange),
                            prompt: Text("Type here").foregroundStyle(color.opacity(0.45)),
                            axis: .vertical
                        ) {
                            EmptyView()
                        }
                        .focused($isFocused)
                        .modifier(FormattedText(format: format, color: color))
                        .onAppear { isFocused = true }
                    }
            } else if text.isEmpty {
                if showPlaceholder {
                    Text("Double-tap to type")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(textColor.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            } else {
                Text(text)
                    .modifier(FormattedText(format: format, color: color))
            }
        }
    }
}

struct ExportedMat: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MatView: View {
    enum Panel {
        case paper
        case sticker
        case deco
        case washi
        case draw
    }

    @Bindable var mat: MatModel
    let onBack: () -> Void
    let onNewSticker: () -> Void

    @State private var panel: Panel?
    @State private var imageItem: PhotosPickerItem?
    @State private var canvasSize = CGSize.zero
    @State private var canvasMinY: CGFloat = 0
    @State private var bodyBottom: CGFloat = 0
    @State private var keyboardTop: CGFloat?
    @State private var panTarget: UUID?
    @State private var pinchTarget: UUID?
    @State private var rotateTarget: UUID?
    @State private var multiTarget: UUID?
    @State private var activeGestures = 0
    @State private var exported: ExportedMat?
    @State private var confirmingClear = false
    @State private var showingInspire = false
    @State private var penColor = PenColor.black
    @State private var penWidth: CGFloat = 5
    @State private var blockedRects: [String: CGRect] = [:]

    private let ink = Color(white: 0.12)
    private let muted = Color(white: 0.55)
    private let emojis = ["⭐️", "❤️", "🔥", "🌈", "🍀", "🎈", "🎵", "🌸", "🍓", "☁️", "⚡️", "🐾", "👑", "💎", "🎀", "🍕"]
    private let shapes: [(String, ShapeColor)] = [
        ("star.fill", .yellow), ("heart.fill", .pink), ("circle.fill", .orange), ("sparkles", .purple),
        ("bolt.fill", .yellow), ("flame.fill", .red), ("leaf.fill", .green), ("cloud.fill", .blue),
        ("moon.fill", .indigo), ("sun.max.fill", .orange), ("music.note", .teal), ("flag.fill", .red)
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack(alignment: .bottom) {
                canvas
                VStack(spacing: 10) {
                    selectionPill
                    panelCard
                }
                .padding(.bottom, 12)
            }
            bottomBar
        }
        .overlay(alignment: .top) {
            if !mat.guides.isEmpty && !mat.formatOpen {
                GuidesCard(
                    questions: mat.guides,
                    onPick: { question in
                        mat.place(.text(question))
                        if let id = mat.selection, let index = mat.items.firstIndex(where: { $0.id == id }) {
                            mat.items[index].offset = CGSize(width: 0, height: -40)
                            mat.items[index].format.align = .center
                        }
                    },
                    onDismiss: { mat.guides = [] }
                )
                .blocksBoardGestures("guides", in: $blockedRects)
                .padding(.top, 52)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bodyBottom = $0 }
        .background(Color.white.ignoresSafeArea())
        .task {
            switch UserDefaults.standard.string(forKey: "panel") {
            case "paper": panel = .paper
            case "sticker": panel = .sticker
            case "deco": panel = .deco
            case "washi": panel = .washi
            case "draw": panel = .draw
            default: break
            }
            if UserDefaults.standard.bool(forKey: "openInspire") {
                try? await Task.sleep(for: .seconds(1))
                showingInspire = true
            }
            if UserDefaults.standard.bool(forKey: "select") {
                mat.selection = mat.items.last?.id
            }
            if let tokens = UserDefaults.standard.string(forKey: "fmt"), let index = mat.items.indices.last {
                let set = Set(tokens.split(separator: ",").map(String.init))
                mat.items[index].format.bold = set.contains("b")
                mat.items[index].format.italic = set.contains("i")
                mat.items[index].format.underline = set.contains("u")
                mat.items[index].format.strike = set.contains("s")
                if set.contains("hl") { mat.items[index].format.highlight = .yellow }
                if set.contains("red") { mat.items[index].format.tint = .red }
                if set.contains("title") { mat.items[index].format.style = .title }
                mat.items[index].kind = .text("Hari ini aku")
            }
            if UserDefaults.standard.bool(forKey: "edit"), let id = mat.items.last?.id {
                mat.beginEditing(id)
                if UserDefaults.standard.bool(forKey: "card") {
                    try? await Task.sleep(for: .seconds(1.5))
                    openFormat()
                }
            }
        }
        .preferredColorScheme(.light)
        .task(id: mat.signature) {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { saveThumbnail() }
        }
        .onDisappear { saveThumbnail() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alignment: .bottom) { editingChrome.ignoresSafeArea(.keyboard, edges: .bottom) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardTop = frame.minY
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardTop = nil
        }
        .onChange(of: imageItem) {
            guard let item = imageItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = Self.downscaled(data) {
                    mat.place(.sticker(image))
                }
                imageItem = nil
            }
        }
        .confirmationDialog("Clear the whole board?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear Board", role: .destructive) { mat.clear() }
        }
        .sheet(item: $exported) { exported in
            VStack(spacing: 16) {
                Image(uiImage: exported.image)
                    .resizable()
                    .scaledToFit()
                ShareLink(
                    item: Image(uiImage: exported.image),
                    preview: SharePreview("My page", image: Image(uiImage: exported.image))
                )
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .presentationDetents([.large])
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
            }
            .accessibilityIdentifier("board-back")
            Button { mat.undo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 18))
            }
            .foregroundStyle(mat.canUndo ? ink : muted.opacity(0.5))
            .disabled(!mat.canUndo)
            Spacer(minLength: 8)
            Button { showingInspire = true } label: {
                Label("Inspire Me", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color(white: 0.4)))
            }
            .accessibilityIdentifier("inspire")
            Spacer(minLength: 8)
            Menu {
                Button("Export Image", systemImage: "square.and.arrow.up", action: export)
                    .disabled(mat.items.isEmpty)
                Button("Clear Board", systemImage: "trash", role: .destructive) { confirmingClear = true }
                    .disabled(mat.items.isEmpty)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18))
            }
            if mat.editingID != nil {
                Button("Done") { mat.finishEditing() }
                    .font(.system(size: 17, weight: .semibold))
            } else {
                Button("Save", action: export)
                    .font(.system(size: 17))
                    .disabled(mat.items.isEmpty)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .sheet(isPresented: $showingInspire) {
            InspireSheet(
                history: mat.guideHistory,
                onPick: { question in
                    showingInspire = false
                    mat.place(.text(question))
                    if let id = mat.selection, let index = mat.items.firstIndex(where: { $0.id == id }) {
                        mat.items[index].offset = CGSize(width: 0, height: -40)
                        mat.items[index].format.align = .center
                    }
                },
                onClose: { showingInspire = false }
            )
        }
    }

    private var canvas: some View {
        GeometryReader { geometry in
            canvasContent(selectable: true)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background {
                    BoardGestures(
                        isEnabled: panel != .draw,
                        blockedRects: Array(blockedRects.values),
                        onPan: handlePan,
                        onPinch: handlePinch,
                        onRotate: handleRotate
                    )
                }
                .onAppear {
                    canvasSize = geometry.size
                    canvasMinY = geometry.frame(in: .global).minY
                }
                .onChange(of: geometry.size) { canvasSize = geometry.size }
                .onChange(of: geometry.frame(in: .global).minY) {
                    canvasMinY = geometry.frame(in: .global).minY
                }
                .overlay {
                    if panel == .draw {
                        DrawLayer(color: penColor, width: penWidth) { points in
                            mat.addStroke(points, canvas: geometry.size, width: penWidth, color: penColor)
                        }
                    }
                }
        }
    }

    private func canvasContent(selectable: Bool) -> some View {
        ZStack {
            PaperView(style: mat.paper, background: mat.background)
                .contentShape(Rectangle())
                .onTapGesture {
                    mat.finishEditing()
                    mat.selection = nil
                    panel = nil
                }
            if mat.items.isEmpty && selectable && mat.guides.isEmpty {
                Text("Tap Sticker, Deco or Text below to start")
                    .font(.system(size: 15))
                    .foregroundStyle(mat.background == .ink ? .white.opacity(0.6) : .black.opacity(0.35))
            }
            Group {
                ForEach(mat.items) { item in
                    MatItemView(
                        item: item,
                        isSelected: selectable && mat.selection == item.id,
                        isEditing: mat.editingID == item.id,
                        showPlaceholder: selectable,
                        lift: selectable ? lift(for: item) : 0,
                        textColor: mat.background == .ink ? .white : .black,
                        focusTick: mat.focusTick,
                        onTouchBegan: { mat.touchBegan(item.id) },
                        onTouchEnded: { mat.touchEnded(item.id) },
                        onTap: { mat.selection = item.id },
                        onSize: { mat.sizes[item.id] = $0 },
                        onTextChange: { mat.updateText(item.id, to: $0) },
                        onEdit: { mat.beginEditing(item.id) }
                    )
                    .zIndex(mat.editingID == item.id ? 1 : 0)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("item-\(mat.items.firstIndex(where: { $0.id == item.id }) ?? -1)")
                    .accessibilityValue(item.readout + " sel=\(mat.selection == item.id ? 1 : 0)")
                }
            }
        }
        .clipped()
    }

    private var bottomBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tab("Paper", active: panel == .paper, action: { toggle(.paper) }) { HatchIcon() }
                tab("Text", active: false, action: {
                    panel = nil
                    mat.addText()
                }) { TextBoxIcon() }
                PhotosPicker(selection: $imageItem, matching: .images) {
                    tabLabel("Image", active: false) {
                        Image(systemName: "photo").font(.system(size: 24))
                    }
                }
                .accessibilityIdentifier("board-tab-image")
                tab("Sticker", active: panel == .sticker, action: { toggle(.sticker) }) {
                    Image(systemName: "face.smiling").font(.system(size: 24))
                }
                tab("Deco", active: panel == .deco, action: { toggle(.deco) }) {
                    Image(systemName: "doc").font(.system(size: 24))
                }
                tab("Washi", active: panel == .washi, action: { toggle(.washi) }) { WashiIcon() }
                tab("Draw", active: panel == .draw, action: { toggle(.draw) }) {
                    Image(systemName: "pencil.tip").font(.system(size: 24))
                }
            }
        }
        .frame(height: 64)
        .background(Color.white)
        .overlay(alignment: .top) { Divider() }
        .accessibilityIdentifier("board-bar")
    }

    private func toggle(_ target: Panel) {
        panel = panel == target ? nil : target
        if panel == .draw {
            mat.finishEditing()
            mat.selection = nil
        }
    }

    private func tab<Icon: View>(
        _ title: String,
        active: Bool,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            tabLabel(title, active: active, icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board-tab-\(title.lowercased())")
    }

    private func tabLabel<Icon: View>(_ title: String, active: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 4) {
            icon()
                .frame(height: 28)
            Text(title).font(.system(size: 11, weight: active ? .semibold : .regular))
        }
        .foregroundStyle(active ? ink : muted)
        .frame(width: 72, height: 64)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var selectionPill: some View {
        if mat.selection != nil && mat.editingID == nil && panel == nil {
            HStack(spacing: 6) {
                if mat.selectedIsText {
                    pillButton("Edit", "pencil", tint: ink) {
                        if let selection = mat.selection {
                            mat.beginEditing(selection)
                        }
                    }
                }
                pillButton("Front", "square.3.layers.3d.top.filled", tint: ink) { mat.bringSelectedToFront() }
                pillButton("Delete", "trash", tint: .red) { mat.deleteSelected() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .blocksBoardGestures("pill", in: $blockedRects)
        }
    }

    private func pillButton(_ title: String, _ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var panelCard: some View {
        if let panel {
            VStack(alignment: .leading, spacing: 10) {
                switch panel {
                case .paper: paperPanel
                case .sticker: stickerPanel
                case .deco: decoPanel
                case .washi: washiPanel
                case .draw: drawPanel
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
            .blocksBoardGestures("panel", in: $blockedRects)
            .padding(.horizontal, 12)
        }
    }

    private var paperPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(MatPaper.allCases) { style in
                    Button { mat.paper = style } label: {
                        VStack(spacing: 4) {
                            Image(systemName: style.symbol)
                                .font(.system(size: 20))
                                .frame(height: 24)
                            Text(style.title).font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(mat.paper == style ? Color(white: 0.92) : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 14) {
                ForEach(MatBackground.allCases) { background in
                    Button { mat.background = background } label: {
                        Circle()
                            .fill(background.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().strokeBorder(
                                    Color.black.opacity(mat.background == background ? 0.8 : 0.15),
                                    lineWidth: mat.background == background ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(ink)
    }

    private var stickerPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: onNewSticker) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 22))
                        Text("New").font(.system(size: 11))
                    }
                    .foregroundStyle(ink)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.94)))
                }
                .buttonStyle(.plain)
                ForEach(Array(mat.stickers.enumerated()), id: \.offset) { _, image in
                    Button { mat.place(.sticker(image)) } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("panel-scroll")
    }

    private var washiPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(TapeStyle.allCases.enumerated()), id: \.element) { index, style in
                    Button { mat.placeTape(style) } label: {
                        TapeView(style: style, width: 104)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tape-\(index)")
                }
            }
        }
        .accessibilityIdentifier("panel-scroll")
    }

    private var drawPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(PenColor.allCases) { pen in
                    Button { penColor = pen } label: {
                        Circle()
                            .fill(pen.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().strokeBorder(
                                    Color.black.opacity(penColor == pen ? 0.85 : 0),
                                    lineWidth: 2.5
                                )
                                .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pen-\(pen.rawValue)")
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                Circle()
                    .fill(penColor.color)
                    .frame(width: max(penWidth, 4), height: max(penWidth, 4))
                    .frame(width: 24, height: 24)
                Slider(value: $penWidth, in: 2...22)
                Button("Done") { panel = nil }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ink)
                    .accessibilityIdentifier("draw-done")
            }
        }
        .foregroundStyle(ink)
    }

    private var decoPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button { mat.place(.emoji(emoji)) } label: {
                        Text(emoji).font(.system(size: 38))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                    Button { mat.place(.symbol(shape.0, shape.1)) } label: {
                        Image(systemName: shape.0)
                            .font(.system(size: 32))
                            .foregroundStyle(shape.1.color)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("panel-scroll")
    }

    private var coveredTop: CGFloat? {
        if mat.formatOpen {
            return bodyBottom - FormatCard.height
        }
        if let keyboardTop {
            return keyboardTop - 64
        }
        return nil
    }

    private func lowestEditOffset(for item: MatItem) -> CGFloat? {
        guard mat.editingID == item.id, let coveredTop else { return nil }
        let limit = coveredTop - canvasMinY - 12
        return limit - 56 * item.scale - canvasSize.height / 2
    }

    private func lift(for item: MatItem) -> CGFloat {
        guard mat.editingID == item.id, coveredTop != nil else { return 0 }
        let halfHeight = 56 * item.scale
        let center = canvasSize.height / 2 + item.offset.height
        guard let lowest = lowestEditOffset(for: item) else { return 0 }
        let needed = lowest - item.offset.height
        guard needed < 0 else { return 0 }
        return max(needed, -(center - halfHeight))
    }

    @ViewBuilder
    private var editingChrome: some View {
        if mat.editingID != nil {
            if mat.formatOpen {
                FormatCard(mat: mat, close: closeFormat)
                    .blocksBoardGestures("card", in: $blockedRects)
                    .transition(.move(edge: .bottom))
            } else {
                formatBar
                    .blocksBoardGestures("bar", in: $blockedRects)
                    .padding(.bottom, formatBarPadding)
            }
        }
    }

    private var formatBarPadding: CGFloat {
        if let keyboardTop {
            return max(bodyBottom - keyboardTop, 0) + 10
        }
        return 64 + 10
    }

    private func openFormat() {
        mat.formatOpen = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func closeFormat() {
        mat.formatOpen = false
        mat.focusTick += 1
    }

    private var formatBar: some View {
        let format = mat.currentFormat ?? TextFormat()
        return HStack(spacing: 2) {
            barButton(id: "format-open", active: false, action: openFormat) {
                Text("Aa").font(.system(size: 20))
            }
            barButton(id: "format-bold", active: format.bold, action: { mat.updateFormat { $0.bold.toggle() } }) {
                Text("B").font(.system(size: 20, weight: .bold))
            }
            barButton(id: "format-italic", active: format.italic, action: { mat.updateFormat { $0.italic.toggle() } }) {
                Text("I").font(.system(size: 22, weight: .regular, design: .serif)).italic()
            }
            barButton(id: "format-underline", active: format.underline, action: { mat.updateFormat { $0.underline.toggle() } }) {
                Text("U").font(.system(size: 20)).underline()
            }
            barButton(id: "format-strike", active: format.strike, action: { mat.updateFormat { $0.strike.toggle() } }) {
                Text("S").font(.system(size: 20)).strikethrough()
            }
            barButton(id: "format-align", active: false, action: { mat.updateFormat { $0.align = $0.align.next } }) {
                Image(systemName: format.align.symbol).font(.system(size: 18))
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(Capsule().fill(Color.white))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
    }

    private func barButton<Label: View>(
        id: String,
        active: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .frame(width: 46, height: 42)
                .background(Circle().fill(active ? Color(white: 0.9) : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func target(at point: CGPoint) -> UUID? {
        let id = mat.item(at: point, canvas: canvasSize, lift: { lift(for: $0) }) ?? mat.touchOwner ?? mat.selection
        if let id, mat.selection != id {
            mat.selection = id
        }
        return id
    }

    private func begin(_ target: UUID?) {
        guard target != nil else { return }
        if activeGestures == 0 {
            mat.checkpoint()
        }
        activeGestures += 1
    }

    private func end(_ target: UUID?) {
        guard target != nil else { return }
        activeGestures = max(0, activeGestures - 1)
    }

    private func handlePan(_ state: UIGestureRecognizer.State, _ delta: CGSize, _ start: CGPoint) {
        switch state {
        case .began:
            panTarget = target(at: start)
            begin(panTarget)
            bakeLift(for: panTarget)
            applyPan(delta)
        case .changed:
            applyPan(delta)
        default:
            end(panTarget)
            panTarget = nil
        }
    }

    private func bakeLift(for id: UUID?) {
        guard let id, let index = mat.items.firstIndex(where: { $0.id == id }) else { return }
        let amount = lift(for: mat.items[index])
        if amount != 0 {
            mat.items[index].offset.height += amount
        }
    }

    private func applyPan(_ delta: CGSize) {
        guard let id = panTarget, let index = mat.items.firstIndex(where: { $0.id == id }) else { return }
        mat.items[index].offset.width += delta.width
        var height = mat.items[index].offset.height + delta.height
        if let lowest = lowestEditOffset(for: mat.items[index]) {
            height = min(height, lowest)
        }
        mat.items[index].offset.height = height
    }

    private func multiTouchTarget(centroid: CGPoint, first: CGPoint?) -> UUID? {
        if let locked = multiTarget, mat.items.contains(where: { $0.id == locked }) {
            return locked
        }
        let lift: (MatItem) -> CGFloat = { lift(for: $0) }
        let points = [first, centroid].compactMap { $0 }
        var chosen: UUID?
        if let selected = mat.items.first(where: { $0.id == mat.selection }),
           points.contains(where: { mat.contains(selected, point: $0, canvas: canvasSize, lift: lift) }) {
            chosen = selected.id
        }
        if chosen == nil {
            for point in points {
                if let hit = mat.item(at: point, canvas: canvasSize, lift: lift) {
                    chosen = hit
                    break
                }
            }
        }
        chosen = chosen ?? mat.touchOwner ?? mat.selection
        multiTarget = chosen
        if let chosen, mat.selection != chosen {
            mat.selection = chosen
        }
        return chosen
    }

    private func finishMultiTouchIfIdle() {
        if pinchTarget == nil && rotateTarget == nil {
            multiTarget = nil
        }
    }

    private func handlePinch(_ state: UIGestureRecognizer.State, _ factor: CGFloat, _ location: CGPoint, _ first: CGPoint?) {
        switch state {
        case .began:
            pinchTarget = multiTouchTarget(centroid: location, first: first)
            begin(pinchTarget)
            applyPinch(factor)
        case .changed:
            applyPinch(factor)
        default:
            end(pinchTarget)
            pinchTarget = nil
            finishMultiTouchIfIdle()
        }
    }

    private func applyPinch(_ factor: CGFloat) {
        guard let id = pinchTarget, let index = mat.items.firstIndex(where: { $0.id == id }) else { return }
        mat.items[index].scale = min(max(mat.items[index].scale * factor, 0.3), 5)
    }

    private func handleRotate(_ state: UIGestureRecognizer.State, _ angle: Angle, _ location: CGPoint, _ first: CGPoint?) {
        switch state {
        case .began:
            rotateTarget = multiTouchTarget(centroid: location, first: first)
            begin(rotateTarget)
            applyRotation(angle)
        case .changed:
            applyRotation(angle)
        default:
            end(rotateTarget)
            rotateTarget = nil
            finishMultiTouchIfIdle()
        }
    }

    private func applyRotation(_ angle: Angle) {
        guard let id = rotateTarget, let index = mat.items.firstIndex(where: { $0.id == id }) else { return }
        mat.items[index].rotation += angle
    }

    private static func downscaled(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private func saveThumbnail() {
        guard mat.pageID != nil, canvasSize.width > 0 else { return }
        let renderer = ImageRenderer(
            content: canvasContent(selectable: false)
                .frame(width: canvasSize.width, height: canvasSize.height)
        )
        renderer.scale = 0.6
        if let data = renderer.uiImage?.pngData() {
            mat.saveThumbnail(data)
        }
    }

    private func export() {
        mat.finishEditing()
        mat.selection = nil
        panel = nil
        let renderer = ImageRenderer(
            content: canvasContent(selectable: false)
                .frame(width: canvasSize.width, height: canvasSize.height)
        )
        renderer.scale = 3
        if let image = renderer.uiImage {
            exported = ExportedMat(image: image)
        }
    }
}

struct FormatCard: View {
    static let height: CGFloat = 280

    @Bindable var mat: MatModel
    let close: () -> Void

    private let ink = Color(white: 0.12)
    private let gold = Color(red: 0.85, green: 0.69, blue: 0.2)
    private let fill = Color(white: 0.94)

    var body: some View {
        let format = mat.currentFormat ?? TextFormat()
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Format").font(.system(size: 20, weight: .semibold))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(fill))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("format-close")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TextStyle.allCases) { style in
                        let selected = format.style == style
                        Button { mat.updateFormat { $0.style = style } } label: {
                            Text(style.title)
                                .font(.system(size: style.previewSize, weight: style.weight))
                                .foregroundStyle(selected ? Color.white : ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(selected ? gold : .clear))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("style-\(style.rawValue)")
                    }
                }
            }

            HStack(spacing: 12) {
                group {
                    toggle(id: "card-bold", on: format.bold, { $0.bold.toggle() }) { Text("B").bold() }
                    toggle(id: "card-italic", on: format.italic, { $0.italic.toggle() }) { Text("I").font(.system(size: 20, design: .serif)).italic() }
                    toggle(id: "card-underline", on: format.underline, { $0.underline.toggle() }) { Text("U").underline() }
                    toggle(id: "card-strike", on: format.strike, { $0.strike.toggle() }) { Text("S").strikethrough() }
                }
                group {
                    Menu {
                        Button("No Highlight") { mat.updateFormat { $0.highlight = nil } }
                        ForEach(TextHighlight.allCases) { highlight in
                            Button(highlight.title) { mat.updateFormat { $0.highlight = highlight } }
                        }
                    } label: {
                        Image(systemName: "highlighter").frame(width: 52, height: 44)
                    }
                    Menu {
                        ForEach(TextTint.allCases) { tint in
                            Button(tint.title) { mat.updateFormat { $0.tint = tint } }
                        }
                    } label: {
                        Circle()
                            .fill(format.tint.color(automatic: .black))
                            .frame(width: 22, height: 22)
                            .frame(width: 52, height: 44)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                group {
                    action(id: "format-list-bullet", symbol: "list.bullet") { mat.applyList(.bullet) }
                    action(id: "format-list-dash", symbol: "list.dash") { mat.applyList(.dash) }
                    action(id: "format-list-number", symbol: "list.number") { mat.applyList(.numbered) }
                }
                group {
                    action(id: "format-outdent", symbol: "decrease.indent") { mat.indent(-1) }
                    action(id: "format-indent", symbol: "increase.indent") { mat.indent(1) }
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) { content() }
            .background(Capsule().fill(fill))
    }

    private func toggle<Label: View>(
        id: String,
        on: Bool,
        _ change: @escaping (inout TextFormat) -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button { mat.updateFormat(change) } label: {
            label()
                .font(.system(size: 18))
                .frame(width: 52, height: 44)
                .background(Capsule().fill(on ? Color(white: 0.84) : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func action(id: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .frame(width: 52, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

struct BlockBoardGestures: ViewModifier {
    let name: String
    @Binding var rects: [String: CGRect]

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rects[name] = $0 }
            .onDisappear { rects[name] = nil }
    }
}

extension View {
    func blocksBoardGestures(_ name: String, in rects: Binding<[String: CGRect]>) -> some View {
        modifier(BlockBoardGestures(name: name, rects: rects))
    }
}

struct BoardGestures: UIViewRepresentable {
    let isEnabled: Bool
    let blockedRects: [CGRect]
    let onPan: (UIGestureRecognizer.State, CGSize, CGPoint) -> Void
    let onPinch: (UIGestureRecognizer.State, CGFloat, CGPoint, CGPoint?) -> Void
    let onRotate: (UIGestureRecognizer.State, Angle, CGPoint, CGPoint?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        context.coordinator.canvas = view
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: HostView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class HostView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.detach()
            guard window != nil else { return }
            var top: UIView = self
            while let next = top.superview, next !== window {
                top = next
            }
            coordinator?.attach(to: top)
        }
    }

    final class TouchDownTracker: UIGestureRecognizer {
        var downPoint: CGPoint?
        weak var canvas: UIView?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = touches.first, let canvas {
                downPoint = touch.location(in: canvas)
            }
            state = .failed
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: BoardGestures
        weak var canvas: UIView?
        private let tracker = TouchDownTracker()

        private weak var host: UIView?
        private lazy var pan: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.maximumNumberOfTouches = 1
            return recognizer
        }()
        private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        private lazy var rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))

        init(_ parent: BoardGestures) {
            self.parent = parent
        }

        func attach(to view: UIView) {
            host = view
            tracker.canvas = canvas
            for recognizer in [tracker, pan, pinch, rotation] as [UIGestureRecognizer] {
                recognizer.delegate = self
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesBegan = false
                recognizer.delaysTouchesEnded = false
                view.addGestureRecognizer(recognizer)
            }
        }

        func detach() {
            guard let host else { return }
            for recognizer in [tracker, pan, pinch, rotation] as [UIGestureRecognizer] {
                host.removeGestureRecognizer(recognizer)
            }
            self.host = nil
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let current = recognizer.location(in: canvas)
            let start = tracker.downPoint ?? CGPoint(x: current.x - translation.x, y: current.y - translation.y)
            parent.onPan(recognizer.state, CGSize(width: translation.x, height: translation.y), start)
            recognizer.setTranslation(.zero, in: recognizer.view)
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            parent.onPinch(recognizer.state, recognizer.scale, recognizer.location(in: canvas), tracker.downPoint)
            recognizer.scale = 1
        }

        @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
            parent.onRotate(recognizer.state, Angle(radians: Double(recognizer.rotation)), recognizer.location(in: canvas), tracker.downPoint)
            recognizer.rotation = 0
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.isEnabled, let canvas else { return false }
            guard canvas.bounds.contains(touch.location(in: canvas)) else { return false }
            let inWindow = touch.location(in: nil)
            return !parent.blockedRects.contains { $0.contains(inWindow) }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
