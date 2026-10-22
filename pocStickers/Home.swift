import SwiftUI

enum HomeTab: String {
    case home
    case journal
    case profile
}

struct HomeTabBar: View {
    let selected: HomeTab
    let onSelect: (HomeTab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            item(.home, "Home", "house.fill")
            item(.journal, "Journal", "book.closed.fill")
            item(.profile, "Profile", "person.fill")
        }
        .padding(6)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.08)))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private func item(_ tab: HomeTab, _ title: String, _ symbol: String) -> some View {
        Button { onSelect(tab) } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 22))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Color(white: 0.12))
            .frame(width: 92, height: 56)
            .background(Capsule().fill(selected == tab ? Color(white: 0.9) : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(tab.rawValue)")
    }
}

struct Polaroid: View {
    let image: UIImage?
    let width: CGFloat
    let angle: Double

    var body: some View {
        let inner = width - 28
        VStack(spacing: 0) {
            ZStack {
                Color(white: image == nil ? 0.85 : 0.95)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                }
            }
            .frame(width: inner, height: inner)
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
        .frame(width: width, height: width * 1.25)
        .background(Color.white)
        .shadow(color: .black.opacity(0.16), radius: 9, y: 3)
        .rotationEffect(.degrees(angle))
    }
}

struct HomeScreen: View {
    let stickers: [UIImage]
    let name: String
    let onWrite: () -> Void
    let onOpenJournal: () -> Void
    let onAddSticker: () -> Void

    private let slots: [(x: CGFloat, y: CGFloat, width: CGFloat, angle: Double)] = [
        (0.27, 0.27, 0.34, -6),
        (0.70, 0.23, 0.36, 4),
        (0.28, 0.76, 0.34, 3),
        (0.71, 0.73, 0.36, -4)
    ]

    private var greeting: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "What's on your mind?" : "What's on your mind \(trimmed)?"
    }

    var body: some View {
        GeometryReader { geometry in
            let recent = Array(stickers.suffix(4).reversed())
            ZStack {
                Color.white.ignoresSafeArea()

                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    let image = index < recent.count ? recent[index] : nil
                    Button {
                        if image == nil {
                            onAddSticker()
                        } else {
                            onOpenJournal()
                        }
                    } label: {
                        Polaroid(image: image, width: geometry.size.width * slot.width, angle: slot.angle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("polaroid-\(index)")
                    .position(x: geometry.size.width * slot.x, y: geometry.size.height * slot.y)
                }

                VStack(spacing: 18) {
                    Text(greeting)
                        .font(.system(size: 34))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                    Button(action: onWrite) {
                        Label("Write", systemImage: "plus")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color(white: 0.42)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("write")
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.5)
            }
        }
    }
}

struct ProfileScreen: View {
    @Binding var name: String
    let stickerCount: Int
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Profile")
                .font(.system(size: 34, weight: .bold))
            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
                TextField("Used in your greeting", text: $name)
                    .font(.system(size: 18))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.95)))
                    .accessibilityIdentifier("profile-name")
            }
            HStack(spacing: 12) {
                stat("\(stickerCount)", "Stickers")
                stat("\(itemCount)", "On your page")
            }
            Spacer()
            Text("Everything stays on this device.")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.5))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 100)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.ignoresSafeArea())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 28, weight: .semibold))
            Text(label).font(.system(size: 13)).foregroundStyle(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.95)))
    }
}
