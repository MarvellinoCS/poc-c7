import FoundationModels
import SwiftUI

enum Feeling: String, CaseIterable, Identifiable {
    case happy
    case confused
    case sad
    case frustrated
    case anxious
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .happy: "Happy and grateful"
        case .confused: "Confused and unsure"
        case .sad: "Sad and disappointed"
        case .frustrated: "Frustrated and upset"
        case .anxious: "Anxious and overthinking"
        case .unsure: "I'm not sure yet ..."
        }
    }

    var emoji: String {
        switch self {
        case .happy: "😊"
        case .confused: "😕"
        case .sad: "😔"
        case .frustrated: "😤"
        case .anxious: "😰"
        case .unsure: "🤔"
        }
    }

    var fallback: [String] {
        switch self {
        case .happy:
            [
                "What is one small thing from today that you want to remember?",
                "Who or what are you most grateful for right now, and why?",
                "How could you carry this feeling into tomorrow?"
            ]
        case .confused:
            [
                "What is the one thing you feel least sure about right now?",
                "What do you already know, even if it is only a little?",
                "What would help you feel a bit clearer today?"
            ]
        case .sad:
            [
                "What happened that made today feel heavy?",
                "What did you hope would be different?",
                "What is one kind thing you could do for yourself right now?"
            ]
        case .frustrated:
            [
                "What exactly is bothering you the most?",
                "What part of this is in your control, and what is not?",
                "What would you say to a friend who felt this way?"
            ]
        case .anxious:
            [
                "What thought keeps coming back to you?",
                "What is the worst that could happen, and how likely is it really?",
                "What is one small step that would make tonight feel lighter?"
            ]
        case .unsure:
            [
                "If you had to describe today in three words, what would they be?",
                "What has been on your mind that you have not said out loud?",
                "What do you need most right now?"
            ]
        }
    }
}

enum Need: String, CaseIterable, Identifiable {
    case untangle
    case makeSense
    case understand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .untangle: "Untangle my thoughts & feelings"
        case .makeSense: "Make sense of what happened"
        case .understand: "Understand what I need to feel better"
        }
    }

    var detail: String {
        switch self {
        case .untangle: "Everything feels tangled and I want to make sense of it, one step at a time"
        case .makeSense: "Something keeps coming back to mind, and I want to understand why"
        case .understand: "I want to understand what I'm hoping for or what I can do next"
        }
    }

    var symbol: String {
        switch self {
        case .untangle: "scribble.variable"
        case .makeSense: "arrow.triangle.2.circlepath"
        case .understand: "heart.text.square"
        }
    }

    var guidance: String {
        switch self {
        case .untangle:
            "Help them separate their thoughts from their feelings and name them one small step at a time."
        case .makeSense:
            "Help them describe what happened and understand why it keeps coming back to their mind."
        case .understand:
            "Help them notice what they are hoping for and what small next step could help them feel better."
        }
    }

    var fallback: [String] {
        switch self {
        case .untangle:
            [
                "What is the first thought that comes to mind, without editing it?",
                "Which of these feelings is the loudest right now?",
                "If you could untangle just one thing today, what would it be?"
            ]
        case .makeSense:
            [
                "What happened, told as simply as you can?",
                "Why do you think this keeps coming back to you?",
                "What part of it do you still not understand?"
            ]
        case .understand:
            [
                "What are you hoping for right now?",
                "What do you need more of, or less of, in your day?",
                "What is one small thing you could do next?"
            ]
        }
    }
}

@Generable
struct JournalGuides {
    @Guide(description: "Open-ended reflective journaling questions, each under 20 words", .count(3))
    var questions: [String]
}

struct GuideSet: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var feeling: String
    var need: String
    var questions: [String]
    var usedModel: Bool

    var feelingTitle: String { Feeling(rawValue: feeling)?.title ?? feeling }

    var needTitle: String { Need(rawValue: need)?.title ?? need }
}

struct GuideResult {
    let questions: [String]
    let usedModel: Bool
}

struct GuideGenerator {
    static var isModelAvailable: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale()
    }

    private func fallback(for feeling: Feeling, need: Need) -> [String] {
        [feeling.fallback[0], need.fallback[1], need.fallback[2]]
    }

    func guides(for feeling: Feeling, need: Need) async -> GuideResult {
        guard Self.isModelAvailable else {
            return GuideResult(questions: fallback(for: feeling, need: need), usedModel: false)
        }
        do {
            let session = LanguageModelSession(
                instructions: """
                You are a warm, gentle journaling companion. You write short, open-ended questions \
                that help someone start writing about how they feel. You never give advice, \
                diagnoses or medical guidance. Every question is specific, kind and under 20 words.
                """
            )
            let prompt = """
            The person says they are feeling: \(feeling.title).
            What they want from this journaling session: \(need.title). \(need.guidance)
            Write three questions to help them begin writing.
            """
            let response = try await session.respond(to: prompt, generating: JournalGuides.self)
            let questions = response.content.questions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard questions.count >= 2 else {
                return GuideResult(questions: fallback(for: feeling, need: need), usedModel: false)
            }
            return GuideResult(questions: Array(questions.prefix(3)), usedModel: true)
        } catch {
            return GuideResult(questions: fallback(for: feeling, need: need), usedModel: false)
        }
    }
}

struct FeelingsScreen: View {
    let onCancel: () -> Void
    let onContinue: (Feeling) -> Void

    @State private var selected: Feeling?

    init(initial: Feeling? = nil, onCancel: @escaping () -> Void, onContinue: @escaping (Feeling) -> Void) {
        self.onCancel = onCancel
        self.onContinue = onContinue
        _selected = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 17))
                    .accessibilityIdentifier("feelings-cancel")
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 52)

            Text("How are you feeling right now?")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 28)

            VStack(spacing: 14) {
                ForEach(Feeling.allCases) { feeling in
                    Button { selected = feeling } label: {
                        HStack(spacing: 14) {
                            Text(feeling.emoji).font(.system(size: 30))
                            Text(feeling.title).font(.system(size: 18))
                            Spacer(minLength: 0)
                            if selected == feeling {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 22))
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(white: selected == feeling ? 0.8 : 0.86))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(Color(white: 0.2), lineWidth: selected == feeling ? 2 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feeling-\(feeling.rawValue)")
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            Button {
                if let selected { onContinue(selected) }
            } label: {
                Text("Continue")
                    .font(.system(size: 19))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Capsule().fill(Color(white: selected == nil ? 0.62 : 0.3)))
            }
            .buttonStyle(.plain)
            .disabled(selected == nil)
            .accessibilityIdentifier("feelings-continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}

struct NeedsScreen: View {
    let onBack: () -> Void
    let onContinue: (Need) -> Void

    @State private var selected: Need?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back", action: onBack)
                    .font(.system(size: 17))
                    .accessibilityIdentifier("needs-back")
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 52)

            Text("How can I help you?")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 28)

            VStack(spacing: 16) {
                ForEach(Need.allCases) { need in
                    Button { selected = need } label: {
                        HStack(alignment: .center, spacing: 16) {
                            Image(systemName: need.symbol)
                                .font(.system(size: 30))
                                .frame(width: 56, height: 56)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(need.title)
                                    .font(.system(size: 19, weight: .semibold))
                                    .multilineTextAlignment(.leading)
                                Text(need.detail)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(white: 0.3))
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(white: selected == need ? 0.84 : 0.91))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(Color(white: 0.2), lineWidth: selected == need ? 2 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("need-\(need.rawValue)")
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            Button {
                if let selected { onContinue(selected) }
            } label: {
                Text("Continue")
                    .font(.system(size: 19))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Capsule().fill(Color(white: selected == nil ? 0.62 : 0.3)))
            }
            .buttonStyle(.plain)
            .disabled(selected == nil)
            .accessibilityIdentifier("needs-continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}

struct InspireSheet: View {
    let history: [GuideSet]
    let onPick: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Inspire Me", systemImage: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(white: 0.93)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inspire-close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if history.isEmpty {
                Text("No guides yet. Tap Write on Home and answer two quick questions to get some.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(white: 0.45))
                    .padding(20)
                    .accessibilityIdentifier("inspire-empty")
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(history.enumerated()), id: \.element.id) { section, set in
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(set.feelingTitle) · \(set.needTitle)")
                                        .font(.system(size: 14, weight: .semibold))
                                    HStack(spacing: 6) {
                                        Text(set.date, format: .dateTime.month().day().hour().minute())
                                        Text("·")
                                        Text(set.usedModel ? "Written on-device by AI" : "Suggested for you")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.5))
                                }
                                ForEach(Array(set.questions.enumerated()), id: \.offset) { index, question in
                                    Button { onPick(question) } label: {
                                        Text(question)
                                            .font(.system(size: 15))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(12)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.95)))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("inspire-\(section)-\(index)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

struct GuidingScreen: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Writing your guides...")
                .font(.system(size: 20))
            Text("A few questions to help you start writing.")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.5))
            Spacer()
            Button("Skip", action: onCancel)
                .font(.system(size: 17))
                .padding(.bottom, 40)
                .accessibilityIdentifier("guiding-skip")
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}

struct GuidesCard: View {
    let questions: [String]
    let onPick: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Inspiration guides", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(white: 0.92)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("guides-dismiss")
            }
            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                Button { onPick(question) } label: {
                    Text(question)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.95)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("guide-\(index)")
            }
        }
        .foregroundStyle(.black)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}
