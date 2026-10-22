import SwiftUI

enum JournalCover: String, CaseIterable, Codable, Identifiable {
    case stone
    case sage
    case blush
    case sky
    case butter
    case lilac
    case ink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .stone: Color(white: 0.85)
        case .sage: Color(red: 0.78, green: 0.88, blue: 0.80)
        case .blush: Color(red: 0.97, green: 0.80, blue: 0.82)
        case .sky: Color(red: 0.76, green: 0.86, blue: 0.96)
        case .butter: Color(red: 0.98, green: 0.92, blue: 0.68)
        case .lilac: Color(red: 0.86, green: 0.80, blue: 0.95)
        case .ink: Color(red: 0.24, green: 0.25, blue: 0.29)
        }
    }
}

struct Journal: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var cover = JournalCover.stone
    var icon = "📖"
    var pageIDs: [UUID] = []
    var createdAt = Date()
    var updatedAt = Date()

    var updatedText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: updatedAt)
    }
}

@Observable
@MainActor
final class JournalLibrary {
    var journals: [Journal] = []
    var activeJournalID: UUID?
    var onPagesRemoved: (([UUID]) -> Void)?

    private let store: MatStore?

    init(persistent: Bool) {
        store = persistent ? MatStore.shared : nil
        if let store, let saved = store.loadLibrary(), !saved.journals.isEmpty {
            journals = saved.journals
            activeJournalID = saved.activeJournalID ?? saved.journals.first?.id
        } else {
            var first = Journal(title: "My Personal Journal")
            if let migrated = store?.migratedPageID {
                first.pageIDs = [migrated]
            }
            journals = [first]
            activeJournalID = first.id
            save()
        }
    }

    func save() {
        store?.saveLibrary(StoredLibrary(journals: journals, activeJournalID: activeJournalID))
    }

    func journal(_ id: UUID?) -> Journal? {
        guard let id else { return nil }
        return journals.first { $0.id == id }
    }

    var activeJournal: Journal? {
        journal(activeJournalID) ?? journals.first
    }

    func setActive(_ id: UUID) {
        guard activeJournalID != id else { return }
        activeJournalID = id
        save()
    }

    func addJournal() -> UUID {
        let covers = JournalCover.allCases
        let journal = Journal(title: "New Journal", cover: covers[journals.count % covers.count])
        journals.append(journal)
        activeJournalID = journal.id
        save()
        return journal.id
    }

    func update(_ journal: Journal) {
        guard let index = journals.firstIndex(where: { $0.id == journal.id }) else { return }
        journals[index] = journal
        save()
    }

    func deleteJournal(_ id: UUID) {
        guard journals.count > 1, let journal = journal(id) else { return }
        onPagesRemoved?(journal.pageIDs)
        for page in journal.pageIDs {
            store?.deletePage(page)
        }
        journals.removeAll { $0.id == id }
        if activeJournalID == id {
            activeJournalID = journals.first?.id
        }
        save()
    }

    func addPage(to journalID: UUID) -> UUID {
        let page = UUID()
        if let index = journals.firstIndex(where: { $0.id == journalID }) {
            journals[index].pageIDs.append(page)
            journals[index].updatedAt = Date()
        }
        activeJournalID = journalID
        save()
        return page
    }

    func deletePage(_ pageID: UUID, from journalID: UUID) {
        onPagesRemoved?([pageID])
        store?.deletePage(pageID)
        if let index = journals.firstIndex(where: { $0.id == journalID }) {
            journals[index].pageIDs.removeAll { $0 == pageID }
        }
        save()
    }

    func lastPage(of journalID: UUID) -> UUID? {
        journal(journalID)?.pageIDs.last
    }

    func touch(pageID: UUID) {
        guard let index = journals.firstIndex(where: { $0.pageIDs.contains(pageID) }) else { return }
        journals[index].updatedAt = Date()
        save()
    }

    func thumbnail(for pageID: UUID) -> UIImage? {
        store?.thumbnail(for: pageID)
    }

    func saveThumbnail(_ png: Data, for pageID: UUID) {
        store?.saveThumbnail(png, for: pageID)
    }
}

struct BookView: View {
    let journal: Journal
    var showsEdit = false
    var onEdit: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 6,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: width * 0.1,
                    topTrailingRadius: width * 0.1
                )
                .fill(journal.cover.color)
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [.black.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: width * 0.08)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 6,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: width * 0.1,
                        topTrailingRadius: width * 0.1
                    )
                )
                .shadow(color: .black.opacity(0.14), radius: 12, y: 6)

                VStack(spacing: 0) {
                    label(width: width)
                        .padding(.top, height * 0.2)
                    Spacer(minLength: 0)
                }

                if showsEdit {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: onEdit) {
                                Text("Edit")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(Color(white: 0.4)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("journal-edit")
                        }
                    }
                    .padding(18)
                }
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
    }

    private func label(width: CGFloat) -> some View {
        let circle = width * 0.115
        return ZStack(alignment: .top) {
            VStack(spacing: width * 0.03) {
                Text(journal.title)
                    .font(.system(size: width * 0.072, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.black)
                Capsule()
                    .fill(Color(white: 0.8))
                    .frame(height: 3)
            }
            .padding(.horizontal, width * 0.06)
            .padding(.top, circle * 0.75)
            .padding(.bottom, width * 0.05)
            .frame(width: width * 0.56)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
            .padding(.top, circle / 2)

            Text(journal.icon)
                .font(.system(size: circle * 0.62))
                .frame(width: circle, height: circle)
                .background(Circle().fill(Color(white: 0.95)))
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
        }
    }
}

struct JournalsScreen: View {
    @Bindable var library: JournalLibrary
    @Binding var focusedID: UUID?
    @Binding var zoomed: Bool
    let onOpenPage: (UUID) -> Void
    let onShowPages: (UUID) -> Void

    @State private var editing = false

    private var focusedJournal: Journal? {
        library.journal(focusedID) ?? library.journals.first
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let bookWidth = zoomed ? width * 0.88 : width * 0.68
            let gap = zoomed ? width * 0.06 : width * 0.10
            let margin = (width - bookWidth) / 2

            VStack(spacing: 0) {
                header
                    .frame(height: 96)
                Spacer(minLength: 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: gap) {
                        ForEach(Array(library.journals.enumerated()), id: \.element.id) { index, journal in
                            BookView(
                                journal: journal,
                                showsEdit: zoomed && journal.id == focusedJournal?.id,
                                onEdit: { editing = true }
                            )
                            .frame(width: bookWidth)
                            .opacity(zoomed && journal.id != focusedJournal?.id ? 0 : 1)
                            .contentShape(Rectangle())
                            .onTapGesture { tap(journal) }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("journal-book-\(index)")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
                .scrollPosition(id: $focusedID)
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .frame(height: bookWidth * 1.5 + 24)
                Spacer(minLength: 0)
                footer
                    .frame(height: zoomed ? 90 : 130)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: zoomed)
        }
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            if focusedID == nil {
                focusedID = library.activeJournalID ?? library.journals.first?.id
            }
        }
        .onChange(of: focusedID) {
            if zoomed, let id = focusedID {
                library.setActive(id)
            }
        }
        .sheet(isPresented: $editing) {
            if let journal = focusedJournal {
                CoverEditor(library: library, journalID: journal.id) {
                    editing = false
                    withAnimation { zoomed = false }
                    focusedID = library.journals.first?.id
                }
            }
        }
    }

    private func tap(_ journal: Journal) {
        if zoomed {
            if journal.id == focusedJournal?.id {
                onOpenPage(journal.id)
            }
        } else {
            library.setActive(journal.id)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                focusedID = journal.id
                zoomed = true
            }
        }
    }

    private func circleButton(_ symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color(white: 0.4)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var header: some View {
        if zoomed {
            ZStack {
                VStack(spacing: 4) {
                    Text(focusedJournal?.title ?? "")
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                        .accessibilityIdentifier("journal-title")
                    Text("Last updated \(focusedJournal?.updatedText ?? "")")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.6))
                }
                .padding(.horizontal, 64)
                HStack {
                    circleButton("chevron.left", id: "journal-back") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { zoomed = false }
                    }
                    Spacer()
                    circleButton("square.grid.2x2", id: "journal-pages") {
                        if let id = focusedJournal?.id { onShowPages(id) }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        } else {
            HStack {
                Spacer()
                circleButton("plus", id: "journal-add") {
                    let id = library.addJournal()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        focusedID = id
                        zoomed = true
                    }
                    editing = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if zoomed {
            let index = library.journals.firstIndex { $0.id == focusedJournal?.id } ?? 0
            Text("\(index + 1) of \(library.journals.count)")
                .font(.system(size: 18))
                .foregroundStyle(Color(white: 0.55))
                .accessibilityIdentifier("journal-counter")
        } else {
            Color.clear
        }
    }
}

struct CoverEditor: View {
    @Bindable var library: JournalLibrary
    let journalID: UUID
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    private let icons = ["📖", "📔", "✨", "🌿", "🌙", "☀️", "💭", "🎞️", "🎨", "🧸", "🍓", "🪴"]

    private var title: Binding<String> {
        Binding(
            get: { library.journal(journalID)?.title ?? "" },
            set: { newValue in
                guard var journal = library.journal(journalID) else { return }
                journal.title = newValue
                library.update(journal)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Edit cover").font(.system(size: 22, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityIdentifier("cover-done")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Title").font(.system(size: 13)).foregroundStyle(Color(white: 0.5))
                TextField("Journal title", text: title)
                    .font(.system(size: 18))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.95)))
                    .accessibilityIdentifier("cover-title")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Color").font(.system(size: 13)).foregroundStyle(Color(white: 0.5))
                HStack(spacing: 12) {
                    ForEach(JournalCover.allCases) { cover in
                        Button {
                            guard var journal = library.journal(journalID) else { return }
                            journal.cover = cover
                            library.update(journal)
                        } label: {
                            Circle()
                                .fill(cover.color)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle().strokeBorder(
                                        Color.black.opacity(library.journal(journalID)?.cover == cover ? 0.85 : 0.12),
                                        lineWidth: library.journal(journalID)?.cover == cover ? 2.5 : 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cover-color-\(cover.rawValue)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Icon").font(.system(size: 13)).foregroundStyle(Color(white: 0.5))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            guard var journal = library.journal(journalID) else { return }
                            journal.icon = icon
                            library.update(journal)
                        } label: {
                            Text(icon)
                                .font(.system(size: 26))
                                .frame(width: 46, height: 46)
                                .background(
                                    Circle().fill(Color(white: library.journal(journalID)?.icon == icon ? 0.86 : 0.95))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cover-icon-\(icon)")
                    }
                }
            }

            Spacer(minLength: 0)

            if library.journals.count > 1 {
                Button("Delete journal", role: .destructive) { confirmingDelete = true }
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("cover-delete")
            }
        }
        .foregroundStyle(.black)
        .padding(24)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.large])
        .confirmationDialog("Delete this journal and all its pages?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete journal", role: .destructive) {
                library.deleteJournal(journalID)
                onDeleted()
            }
        }
    }
}

struct PagesScreen: View {
    @Bindable var library: JournalLibrary
    let journalID: UUID
    let onBack: () -> Void
    let onOpen: (UUID) -> Void
    let onNew: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    private var journal: Journal? { library.journal(journalID) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VStack(spacing: 4) {
                    Text(journal?.title ?? "")
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                    let count = journal?.pageIDs.count ?? 0
                    Text(count == 1 ? "1 reflection page" : "\(count) reflection pages")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.6))
                        .accessibilityIdentifier("pages-count")
                }
                .padding(.horizontal, 64)
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Color(white: 0.4)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pages-back")
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .frame(height: 96)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                    Button(action: onNew) {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.94))
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus").font(.system(size: 30, weight: .light))
                                        Text("New page").font(.system(size: 14))
                                    }
                                    .foregroundStyle(Color(white: 0.4))
                                }
                            Text(" ").font(.system(size: 13))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pages-new")

                    let ids = Array((journal?.pageIDs ?? []).reversed())
                    ForEach(Array(ids.enumerated()), id: \.element) { display, id in
                        let number = (journal?.pageIDs.firstIndex(of: id) ?? 0) + 1
                        Button { onOpen(id) } label: {
                            PageTile(image: library.thumbnail(for: id), number: number)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("page-\(display)")
                        .contextMenu {
                            Button("Delete page", systemImage: "trash", role: .destructive) {
                                library.deletePage(id, from: journalID)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
    }
}

struct PageTile: View {
    let image: UIImage?
    let number: Int

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Color(white: 0.97)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text("Blank").font(.system(size: 13)).foregroundStyle(Color(white: 0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.black.opacity(0.08)))
            Text("Page \(number)")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.45))
        }
    }
}
