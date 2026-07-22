//
//  ScoreView.swift
//  Ontology
//
//  A tight, composable UI for displaying and editing `[Score]` (a `ScoreCard`).
//
//  Read-only: each score renders as a progress ring with a "value/goal" label.
//  Editable: tapping a ring expands inline +/- controls that update the value.
//

#if canImport(SwiftUI)
import SwiftUI
import Ontology
import Units

// MARK: - Card

/// Displays and edits a `Binding<[Score]>`.
///
/// In read-only mode each score is a compact progress ring showing `value/goal`.
/// When `editable`, tapping a ring expands stepper controls for the current value.
public struct ScoreCardView: View {
    @Binding var scores: [Score]
    var editable: Bool
    var axis: Axis

    public init(
        scores: Binding<[Score]>,
        editable: Bool = false,
        axis: Axis = .vertical
    ) {
        self._scores = scores
        self.editable = editable
        self.axis = axis
    }

    public var body: some View {
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        layout {
            ForEach($scores) { $score in
                ScoreView(score: $score, editable: editable)
            }
        }
    }
}

// MARK: - Single score

/// A single `Score` as a progress ring, optionally editable.
public struct ScoreView: View {
    @Binding var score: Score
    var editable: Bool
    var step: Double
    @State private var expanded = false

    public init(score: Binding<Score>, editable: Bool = false, step: Double = 1) {
        self._score = score
        self.editable = editable
        self.step = step
    }

    private var fraction: Double {
        let g = score.goal.value
        guard g != 0 else { return score.value.value > 0 ? 1 : 0 }
        return min(1, max(0, score.value.value / g))
    }

    private var tint: Color {
        switch score.state {
        case .final:  return .green
        case .ignore: return .secondary
        default:      return .accentColor
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: toggleExpanded) {
                HStack(spacing: 6) {
                    ring
                    if !score.summary.isEmpty {
                        Text(score.summary)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    Spacer()
                    if editable {
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!editable)

            if editable && expanded {
                editor
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(fmt(score.value.value))/\(fmt(score.goal.value))")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(2)
        }
        .frame(width: 38, height: 38)
        .animation(.snappy, value: fraction)
    }

    private var editor: some View {
        HStack(spacing: 8) {
            Button { adjust(-step) } label: {
                Image(systemName: "minus.circle.fill")
            }
            .disabled(score.value.value <= 0)

            Text(fmt(score.value.value))
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .frame(minWidth: 28)

            Button { adjust(step) } label: {
                Image(systemName: "plus.circle.fill")
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.snappy) {
                    score.state = score.isFinal ? .in_progress : .final
                }
            } label: {
                Image(systemName: score.isFinal ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .foregroundStyle(score.isFinal ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .font(.title3)
        .padding(.leading, 2)
    }

    private func adjust(_ delta: Double) {
        let boundedDelta = max(-score.value.value, delta)
        _ = withAnimation(.snappy) {
            score.record(boundedDelta)
        }
    }

    private func toggleExpanded() {
        guard editable else { return }
        withAnimation(.snappy(duration: 0.2)) {
            expanded.toggle()
        }
    }
}

// MARK: - Formatting

/// Formats a score magnitude as an integer when whole, otherwise one decimal.
private func fmt(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}

// MARK: - Preview

#Preview("Score Card") {
    @Previewable @State var scores: [Score] = [
        Score(summary: "Chapters read", value: 1, goal: 5, state: .in_progress),
        Score(summary: "Miles run", value: 8, goal: 10, state: .in_progress),
        Score(summary: "Setup complete", value: 1, goal: 1, state: .final),
    ]
    VStack(alignment: .leading, spacing: 24) {
        ScoreCardView(scores: $scores, editable: true)
        Divider()
        ScoreCardView(scores: $scores, axis: .horizontal)
    }
    .padding()
    .frame(width: 260)
}
#endif
