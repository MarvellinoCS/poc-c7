import PhotosUI
import SwiftUI

@Observable
@MainActor
final class StickerViewModel {
    enum Phase {
        case idle
        case processing
        case ready
        case failed(String)
    }

    var phase = Phase.idle
    var preview: UIImage?
    var pngURL: URL?
    var foundSubject = true
    var strokes: [EraseStroke] = []
    var brushRadius: CGFloat = 20

    private let maker = StickerMaker()
    private var sticker: Sticker?

    var isIdle: Bool {
        if case .idle = phase { return true }
        return false
    }

    func reset() {
        phase = .idle
        preview = nil
        pngURL = nil
        sticker = nil
        foundSubject = true
        strokes = []
    }

    func load(_ data: Data) async {
        phase = .processing
        strokes = []
        do {
            let sticker = try await maker.makeSticker(from: data)
            self.sticker = sticker
            foundSubject = sticker.foundSubject
            try await render()
            phase = .ready
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func rerender() async {
        guard sticker != nil else { return }
        do {
            try await render()
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func trimmedSticker() async -> UIImage? {
        guard let sticker else { return nil }
        guard let image = try? await maker.trimmedImage(of: sticker, erasing: strokes) else { return nil }
        return UIImage(cgImage: image)
    }

    func addStroke(viewPoints: [CGPoint], viewSize: CGSize) async {
        guard let canvas = preview?.size, viewSize.width > 0, viewSize.height > 0 else { return }
        let border = StickerMaker.borderWidth
        let points = viewPoints.map { point in
            CGPoint(
                x: point.x / viewSize.width * canvas.width - border,
                y: (1 - point.y / viewSize.height) * canvas.height - border
            )
        }
        strokes.append(EraseStroke(points: points, radius: brushRadius))
        await rerender()
    }

    func undoStroke() async {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        await rerender()
    }

    func resetStrokes() async {
        guard !strokes.isEmpty else { return }
        strokes = []
        await rerender()
    }

    private func render() async throws {
        guard let sticker else { return }
        let cgImage = try await maker.preview(of: sticker, erasing: strokes)
        let png = try await maker.pngData(of: sticker, erasing: strokes)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sticker.png")
        try png.write(to: url)
        preview = UIImage(cgImage: cgImage)
        pngURL = url
    }
}

struct ContentView: View {
    @State private var model = StickerViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var isErasing = false
    @State private var isMoving = false
    @State private var zoom: CGFloat = 1
    @State private var pan = CGSize.zero
    @State private var rotation = Angle.zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var twist = Angle.zero
    @GestureState private var panDrag = CGSize.zero
    @State private var mat = MatModel(persistent: !ContentView.usesTestBoard)
    @State private var library = JournalLibrary(persistent: !ContentView.usesTestBoard)
    @State private var journalFocusID: UUID?
    @State private var journalZoomed = false
    @State private var pagesJournalID: UUID?
    @State private var route = Route.home
    @State private var cameraReturn = Route.home
    @AppStorage("userName") private var userName = ""
    @Environment(\.scenePhase) private var scenePhase

    @State private var guidingTask: Task<Void, Never>?
    @State private var pickedFeeling: Feeling?

    enum Route {
        case home
        case profile
        case journals
        case pages
        case board
        case camera
        case feelings
        case needs
        case guiding
    }

    private static var usesTestBoard: Bool {
        CommandLine.arguments.contains("-autoBoard") || CommandLine.arguments.contains("-autoMat")
    }

    var body: some View {
        Group {
            if !model.isIdle {
                review
            } else {
                switch route {
                case .home:
                    HomeScreen(
                        stickers: mat.stickers,
                        name: userName,
                        onWrite: write,
                        onOpenJournal: { route = .journals },
                        onAddSticker: { openCamera(returningTo: .home) }
                    )
                    .overlay(alignment: .bottom) { tabBar(selected: .home) }
                case .profile:
                    ProfileScreen(name: $userName, stickerCount: mat.stickers.count, itemCount: mat.items.count)
                        .overlay(alignment: .bottom) { tabBar(selected: .profile) }
                case .journals:
                    JournalsScreen(
                        library: library,
                        focusedID: $journalFocusID,
                        zoomed: $journalZoomed,
                        onOpenPage: openLatestPage,
                        onShowPages: { id in
                            pagesJournalID = id
                            route = .pages
                        }
                    )
                    .overlay(alignment: .bottom) {
                        if !journalZoomed {
                            tabBar(selected: .journal)
                        }
                    }
                case .pages:
                    if let journalID = pagesJournalID {
                        PagesScreen(
                            library: library,
                            journalID: journalID,
                            onBack: { route = .journals },
                            onOpen: { openPage($0, in: journalID) },
                            onNew: { openNewPage(in: journalID) }
                        )
                    }
                case .board:
                    MatView(
                        mat: mat,
                        onBack: {
                            mat.saveNow()
                            route = .journals
                        },
                        onNewSticker: { openCamera(returningTo: .board) }
                    )
                case .feelings:
                    FeelingsScreen(
                        initial: pickedFeeling,
                        onCancel: { route = .home },
                        onContinue: { feeling in
                            pickedFeeling = feeling
                            route = .needs
                        }
                    )
                case .needs:
                    NeedsScreen(
                        onBack: { route = .feelings },
                        onContinue: { need in
                            if let feeling = pickedFeeling {
                                startGuides(feeling, need)
                            }
                        }
                    )
                case .guiding:
                    GuidingScreen(onCancel: skipGuides)
                case .camera:
                    CameraScreen(
                        pickerItem: $pickerItem,
                        onCapture: capture,
                        onSample: useSample,
                        onClose: { route = cameraReturn }
                    )
                }
            }
        }
        .preferredColorScheme(model.isIdle && route != .camera ? .light : nil)
        .task {
            mat.onPersisted = { library.touch(pageID: $0) }
            library.onPagesRemoved = { ids in
                if let current = mat.pageID, ids.contains(current) {
                    mat.detachPage()
                }
            }
            let extra = UserDefaults.standard.integer(forKey: "moreJournals")
            if extra > 0 {
                let titles = ["Travel Diary", "Gratitude Log", "Dream Notes"]
                for index in 0..<min(extra, titles.count) {
                    var journal = library.journal(library.addJournal())!
                    journal.title = titles[index]
                    library.update(journal)
                }
                library.setActive(library.journals[0].id)
                journalFocusID = library.journals[0].id
            }
            if UserDefaults.standard.bool(forKey: "zoomJournal") {
                journalFocusID = library.activeJournal?.id
                journalZoomed = true
            }
            switch UserDefaults.standard.string(forKey: "route") {
            case "profile": route = .profile
            case "pages":
                pagesJournalID = library.activeJournal?.id
                if let id = pagesJournalID {
                    _ = library.addPage(to: id)
                    _ = library.addPage(to: id)
                }
                route = .pages
            case "journals": route = .journals
            case "board":
                ensureOpenPage()
                route = .board
            case "feelings": route = .feelings
            case "needs": route = .needs
            case "guiding": route = .guiding
            default: break
            }
            if let name = UserDefaults.standard.string(forKey: "autoFeeling"), let feeling = Feeling(rawValue: name) {
                let need = UserDefaults.standard.string(forKey: "autoNeed").flatMap(Need.init(rawValue:)) ?? .untangle
                startGuides(feeling, need)
            }
            if CommandLine.arguments.contains("-autoBoard") || CommandLine.arguments.contains("-seedBoard") {
                seedBoard()
                return
            }
            guard CommandLine.arguments.contains("-autoSample") else { return }
            if CommandLine.arguments.contains("-autoMat"),
               let data = UIImage(named: "testObject")?.pngData() {
                await model.load(data)
                await finishSticker()
                mat.place(.emoji("⭐️"))
                mat.place(.symbol("heart.fill", .pink))
                mat.place(.text("hello"))
                if CommandLine.arguments.contains("-deselect") {
                    mat.selection = nil
                }
                if CommandLine.arguments.contains("-autoText") {
                    route = .board
                    if let index = mat.items.firstIndex(where: { if case .text = $0.kind { return true } else { return false } }) {
                        mat.items[index].offset = CGSize(width: -90, height: -170)
                        mat.items[index].scale = 1.8
                        mat.selection = mat.items[index].id
                    }
                    if CommandLine.arguments.contains("-startEdit"), let id = mat.selection {
                        try? await Task.sleep(for: .seconds(4))
                        mat.beginEditing(id)
                    }
                }
                return
            }
            useSample()
        }
        .onChange(of: pickerItem) {
            guard let pickerItem else { return }
            Task {
                if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                    await model.load(data)
                }
            }
        }
        .onChange(of: mat.signature) { mat.scheduleSave() }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                mat.saveNow()
            }
        }
        .onChange(of: isErasing) {
            if !isErasing {
                resetView()
            }
        }
    }

    private var review: some View {
        NavigationStack {
            VStack(spacing: 16) {
                stage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Checkerboard())
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if !model.foundSubject {
                    Text("No object found. Try a plainer background and keep the object in view.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if model.preview != nil {
                    eraserTools
                }

                HStack {
                    Button("Retake", systemImage: "camera", action: retake)
                        .buttonStyle(.bordered)
                    Button("Add", systemImage: "plus.square.on.square", action: addToMat)
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.foundSubject)
                    if let url = model.pngURL, model.foundSubject {
                        ShareLink("Save", item: url)
                            .buttonStyle(.bordered)
                    }
                }
                .lineLimit(1)
            }
            .padding()
            .navigationTitle("Sticker Maker")
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch model.phase {
        case .idle:
            Text("Pick a photo of an object on a plain surface")
                .foregroundStyle(.secondary)
        case .processing:
            ProgressView("Cutting it out")
        case .ready:
            if let preview = model.preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        if isErasing && !isMoving {
                            EraseOverlay(
                                canvasSize: preview.size,
                                brushRadius: model.brushRadius,
                                suppress: pinch != 1 || twist != .zero
                            ) { points, size in
                                Task { await model.addStroke(viewPoints: points, viewSize: size) }
                            }
                        }
                    }
                    .scaleEffect(zoom * pinch)
                    .rotationEffect(rotation + twist)
                    .offset(x: pan.width + panDrag.width, y: pan.height + panDrag.height)
                    .gesture(viewGesture, including: isErasing ? .all : .none)
                    .gesture(panGesture, including: isErasing && isMoving ? .all : .none)
                    .padding()
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .padding()
        }
    }

    private var viewGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                zoom = min(max(zoom * value.magnification, 1), 6)
                if zoom == 1 {
                    pan = .zero
                }
            }
            .simultaneously(with: RotateGesture()
                .updating($twist) { value, state, _ in state = value.rotation }
                .onEnded { value in
                    rotation += value.rotation
                })
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($panDrag) { value, state, _ in state = value.translation }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
            }
    }

    private func resetView() {
        zoom = 1
        pan = .zero
        rotation = .zero
        isMoving = false
    }

    private var eraserTools: some View {
        HStack {
            if isErasing {
                Slider(value: $model.brushRadius, in: 6...60)
                    .frame(maxWidth: 80)
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    Task { await model.undoStroke() }
                }
                .disabled(model.strokes.isEmpty)
                Button("Clear", systemImage: "trash") {
                    Task { await model.resetStrokes() }
                }
                .disabled(model.strokes.isEmpty)
                Button("Move", systemImage: "hand.draw") {
                    isMoving.toggle()
                }
                .tint(isMoving ? .green : .accentColor)
                Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
                    resetView()
                }
                .disabled(zoom == 1 && pan == .zero && rotation == .zero)
            }
            Button(isErasing ? "Done" : "Erase", systemImage: "eraser") {
                isErasing.toggle()
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .tint(isErasing ? .green : .accentColor)
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .lineLimit(1)
    }

    private func ensureOpenPage() {
        if let current = mat.pageID, library.journals.contains(where: { $0.pageIDs.contains(current) }) {
            return
        }
        let journalID = library.activeJournal?.id ?? library.journals[0].id
        let pageID = library.lastPage(of: journalID) ?? library.addPage(to: journalID)
        mat.openPage(pageID)
        journalFocusID = journalID
        journalZoomed = true
    }

    private func openLatestPage(_ journalID: UUID) {
        library.setActive(journalID)
        let pageID = library.lastPage(of: journalID) ?? library.addPage(to: journalID)
        openPage(pageID, in: journalID)
    }

    private func openPage(_ pageID: UUID, in journalID: UUID) {
        library.setActive(journalID)
        journalFocusID = journalID
        journalZoomed = true
        if mat.pageID != pageID {
            mat.openPage(pageID)
        }
        route = .board
    }

    private func openNewPage(in journalID: UUID) {
        let pageID = library.addPage(to: journalID)
        openPage(pageID, in: journalID)
    }

    private func seedBoard() {
        ensureOpenPage()
        if let image = UIImage(named: "testObject") {
            mat.addSticker(image)
        }
        mat.place(.emoji("⭐️"))
        mat.place(.symbol("heart.fill", .pink))
        mat.place(.text("hello"))
        let spots: [CGSize] = [
            CGSize(width: 0, height: -110),
            CGSize(width: -100, height: 110),
            CGSize(width: 100, height: 110),
            CGSize(width: 0, height: 210)
        ]
        for index in mat.items.indices where index < spots.count {
            mat.items[index].offset = spots[index]
        }
        if CommandLine.arguments.contains("-overlap"), let first = mat.items.first {
            mat.place(.text("TOP"))
            if let last = mat.items.indices.last {
                mat.items[last].offset = first.offset
            }
        }
        mat.selection = nil
        route = .board
    }

    private func tabBar(selected: HomeTab) -> some View {
        HomeTabBar(selected: selected) { tab in
            switch tab {
            case .home: route = .home
            case .journal: route = .journals
            case .profile: route = .profile
            }
        }
        .padding(.bottom, 20)
    }

    private func write() {
        pickedFeeling = nil
        route = .feelings
    }

    private func startGuides(_ feeling: Feeling, _ need: Need) {
        route = .guiding
        guidingTask?.cancel()
        guidingTask = Task {
            let result = await GuideGenerator().guides(for: feeling, need: need)
            guard !Task.isCancelled else { return }
            finishGuides(result.questions, feeling: feeling, need: need, usedModel: result.usedModel)
        }
    }

    private func skipGuides() {
        guidingTask?.cancel()
        finishGuides([], feeling: nil, need: nil, usedModel: false)
    }

    private func finishGuides(_ questions: [String], feeling: Feeling?, need: Need?, usedModel: Bool) {
        let journalID = library.activeJournal?.id ?? library.journals[0].id
        let pageID = library.addPage(to: journalID)
        mat.openPage(pageID)
        journalFocusID = journalID
        journalZoomed = true
        mat.recordGuides(questions, feeling: feeling, need: need, usedModel: usedModel)
        mat.addText()
        if let id = mat.selection {
            mat.beginEditing(id)
        }
        route = .board
    }

    private func openCamera(returningTo destination: Route) {
        cameraReturn = destination
        route = .camera
    }

    private func capture(_ data: Data) {
        Task { await model.load(data) }
    }

    private func addToMat() {
        Task { await finishSticker() }
    }

    private func finishSticker() async {
        guard model.foundSubject, let image = await model.trimmedSticker() else { return }
        ensureOpenPage()
        mat.addSticker(image)
        retake()
        route = .board
    }

    private func retake() {
        pickerItem = nil
        isErasing = false
        model.reset()
    }

    private func useSample() {
        guard let data = UIImage(named: "testObject")?.pngData() else { return }
        Task { await model.load(data) }
    }
}

struct EraseOverlay: View {
    let canvasSize: CGSize
    let brushRadius: CGFloat
    let suppress: Bool
    let onStroke: ([CGPoint], CGSize) -> Void

    @State private var current: [CGPoint] = []
    @State private var cancelled = false

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / max(canvasSize.width, 1)
            ZStack {
                Color.clear.contentShape(Rectangle())
                Path { path in
                    guard let first = current.first else { return }
                    path.move(to: first)
                    for point in current.dropFirst() {
                        path.addLine(to: point)
                    }
                    if current.count == 1 {
                        path.addLine(to: first)
                    }
                }
                .stroke(
                    Color.red.opacity(0.45),
                    style: StrokeStyle(lineWidth: brushRadius * 2 * scale, lineCap: .round, lineJoin: .round)
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if cancelled { return }
                        if suppress {
                            current = []
                            cancelled = true
                            return
                        }
                        current.append(value.location)
                    }
                    .onEnded { _ in
                        if !cancelled && !current.isEmpty {
                            onStroke(current, geometry.size)
                        }
                        current = []
                        cancelled = false
                    }
            )
            .onChange(of: suppress) {
                if suppress {
                    current = []
                    cancelled = true
                }
            }
        }
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 16
            for row in 0..<Int(size.height / tile) + 1 {
                for column in 0..<Int(size.width / tile) + 1 {
                    let isDark = (row + column).isMultiple(of: 2)
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(isDark ? Color(white: 0.82) : Color(white: 0.94)))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
