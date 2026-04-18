import SwiftData
import SwiftUI

struct RoutineItemRow: View {
    @Bindable var item: RoutineItem
    @EnvironmentObject private var routineViewModel: RoutineViewModel

    var body: some View {
        HStack(spacing: 14) {
            Text(item.category.icon)
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text(item.category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let duration = item.duration, duration > 0 {
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if routineViewModel.isTimerRunning(for: item) {
                        Text(routineViewModel.formattedRemaining(for: item))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.rose)
                    }

                    if item.isCompleted {
                        Text("Done")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.sage)
                    }
                }
            }

            Button(action: {
                routineViewModel.handlePrimaryAction(for: item)
            }) {
                Text(buttonTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(buttonForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(buttonBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(item.isCompleted)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: Theme.shadow, radius: 8, y: 4)
    }

    private var buttonTitle: String {
        if item.isCompleted {
            return "Done"
        }
        return routineViewModel.isTimerRunning(for: item) ? "Stop" : "Start"
    }

    private var buttonForeground: Color {
        item.isCompleted ? .secondary : .white
    }

    private var buttonBackground: Color {
        if item.isCompleted {
            return Theme.sand.opacity(0.6)
        }
        return routineViewModel.isTimerRunning(for: item) ? Theme.sand : Theme.rose
    }
}
