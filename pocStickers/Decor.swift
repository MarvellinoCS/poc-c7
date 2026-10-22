import SwiftUI

enum TapeStyle: String, CaseIterable, Codable, Identifiable {
    case blush
    case butter
    case mint
    case sky
    case lilac
    case stripe
    case dots
    case check

    var id: String { rawValue }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        switch self {
        case .blush: context.fill(Path(full), with: .color(Color(red: 0.99, green: 0.78, blue: 0.82)))
        case .butter: context.fill(Path(full), with: .color(Color(red: 0.99, green: 0.93, blue: 0.64)))
        case .mint: context.fill(Path(full), with: .color(Color(red: 0.76, green: 0.92, blue: 0.83)))
        case .sky: context.fill(Path(full), with: .color(Color(red: 0.75, green: 0.87, blue: 0.98)))
        case .lilac: context.fill(Path(full), with: .color(Color(red: 0.85, green: 0.79, blue: 0.96)))
        case .stripe:
            context.fill(Path(full), with: .color(Color(red: 1.0, green: 0.97, blue: 0.93)))
            var stripes = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                stripes.move(to: CGPoint(x: x, y: size.height))
                stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 11
            }
            context.stroke(stripes, with: .color(Color(red: 0.96, green: 0.62, blue: 0.68)), lineWidth: 4)
        case .dots:
            context.fill(Path(full), with: .color(Color(red: 0.62, green: 0.80, blue: 0.95)))
            var dots = Path()
            var row = 0
            var y: CGFloat = 5
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? 6 : 12
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                    x += 12
                }
                y += 8
                row += 1
            }
            context.fill(dots, with: .color(.white.opacity(0.9)))
        case .check:
            context.fill(Path(full), with: .color(.white))
            let cell: CGFloat = 6
            var tint = Path()
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var column = 0
                var x: CGFloat = 0
                while x < size.width {
                    if (row + column).isMultiple(of: 2) {
                        tint.addRect(CGRect(x: x, y: y, width: cell, height: cell))
                    }
                    x += cell
                    column += 1
                }
                y += cell
                row += 1
            }
            context.fill(tint, with: .color(Color(red: 0.97, green: 0.62, blue: 0.70).opacity(0.75)))
        }
    }
}

struct TapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tooth: CGFloat = 4
        let step: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tooth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tooth, y: rect.minY))
        var y = rect.minY
        var out = true
        while y < rect.maxY {
            y = min(y + step, rect.maxY)
            path.addLine(to: CGPoint(x: out ? rect.maxX : rect.maxX - tooth, y: y))
            out.toggle()
        }
        path.addLine(to: CGPoint(x: rect.minX + tooth, y: rect.maxY))
        var back = rect.maxY
        out = true
        while back > rect.minY {
            back = max(back - step, rect.minY)
            path.addLine(to: CGPoint(x: out ? rect.minX : rect.minX + tooth, y: back))
            out.toggle()
        }
        path.closeSubpath()
        return path
    }
}

struct TapeView: View {
    let style: TapeStyle
    var width: CGFloat = 150

    var body: some View {
        Canvas { context, size in
            var context = context
            style.draw(in: &context, size: size)
        }
        .frame(width: width, height: width * 0.24)
        .clipShape(TapeShape())
        .opacity(0.92)
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
    }
}

enum PenColor: String, CaseIterable, Codable, Identifiable {
    case black
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .black: Color(white: 0.1)
        case .red: Color(red: 0.92, green: 0.2, blue: 0.2)
        case .orange: Color(red: 0.98, green: 0.55, blue: 0.1)
        case .yellow: Color(red: 0.98, green: 0.82, blue: 0.1)
        case .green: Color(red: 0.2, green: 0.7, blue: 0.35)
        case .blue: Color(red: 0.2, green: 0.45, blue: 0.95)
        case .purple: Color(red: 0.6, green: 0.35, blue: 0.9)
        case .pink: Color(red: 0.98, green: 0.45, blue: 0.7)
        }
    }
}

struct DrawStroke: Codable, Equatable {
    var points: [CGPoint]
    var width: CGFloat
    var color: PenColor
    var size: CGSize

    static func make(from canvasPoints: [CGPoint], width: CGFloat, color: PenColor) -> (stroke: DrawStroke, center: CGPoint)? {
        guard let first = canvasPoints.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in canvasPoints {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let relative = canvasPoints.map { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
        let size = CGSize(width: maxX - minX + width, height: maxY - minY + width)
        return (DrawStroke(points: relative, width: width, color: color, size: size), center)
    }

    func path(offsetBy extra: CGFloat = 0) -> Path {
        let shift = CGPoint(x: size.width / 2 + extra, y: size.height / 2 + extra)
        let mapped = points.map { CGPoint(x: $0.x + shift.x, y: $0.y + shift.y) }
        var path = Path()
        guard let first = mapped.first else { return path }
        if mapped.count == 1 {
            path.addEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
            return path
        }
        path.move(to: first)
        if mapped.count == 2 {
            path.addLine(to: mapped[1])
            return path
        }
        for index in 1..<(mapped.count - 1) {
            let mid = CGPoint(x: (mapped[index].x + mapped[index + 1].x) / 2, y: (mapped[index].y + mapped[index + 1].y) / 2)
            path.addQuadCurve(to: mid, control: mapped[index])
        }
        path.addLine(to: mapped[mapped.count - 1])
        return path
    }

    func distance(to point: CGPoint) -> CGFloat {
        guard let first = points.first else { return .infinity }
        if points.count == 1 {
            return hypot(point.x - first.x, point.y - first.y)
        }
        var best = CGFloat.infinity
        for index in 0..<(points.count - 1) {
            let a = points[index]
            let b = points[index + 1]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            var t: CGFloat = 0
            if lengthSquared > 0 {
                t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
            }
            best = min(best, hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy)))
        }
        return best
    }
}

struct StrokeView: View {
    let stroke: DrawStroke

    var body: some View {
        ZStack {
            if stroke.points.count == 1 {
                stroke.path().fill(stroke.color.color)
            } else {
                stroke.path().stroke(
                    stroke.color.color,
                    style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: stroke.size.width, height: stroke.size.height)
    }
}

struct DrawLayer: View {
    let color: PenColor
    let width: CGFloat
    let onFinish: ([CGPoint]) -> Void

    @State private var current: [CGPoint] = []

    var body: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            Path { path in
                guard let first = current.first else { return }
                path.move(to: first)
                for point in current.dropFirst() {
                    path.addLine(to: point)
                }
                if current.count == 1 {
                    path.addEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
                }
            }
            .stroke(color.color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if let last = current.last, hypot(value.location.x - last.x, value.location.y - last.y) < 1.5 {
                        return
                    }
                    current.append(value.location)
                }
                .onEnded { _ in
                    onFinish(current)
                    current = []
                }
        )
        .accessibilityIdentifier("draw-layer")
    }
}

struct HatchIcon: View {
    var body: some View {
        Canvas { context, size in
            var lines = Path()
            for offset in [-8.0, 0.0, 8.0] {
                lines.move(to: CGPoint(x: 2 + offset, y: size.height - 2))
                lines.addLine(to: CGPoint(x: size.width - 2 + offset, y: 2))
            }
            context.clip(to: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4))
            context.stroke(lines, with: .foreground, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        .frame(width: 26, height: 26)
    }
}

struct TextBoxIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(lineWidth: 2.4)
            .frame(width: 26, height: 26)
            .overlay {
                Text("T").font(.system(size: 15, weight: .bold))
            }
    }
}

struct WashiIcon: View {
    var body: some View {
        ZStack {
            TapeShape()
                .frame(width: 30, height: 13)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.white.opacity(0.85)).frame(width: 2.6, height: 2.6)
                }
            }
        }
        .rotationEffect(.degrees(-38))
        .frame(width: 26, height: 26)
    }
}
