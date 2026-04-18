import SwiftUI

struct WaterProgressCard: View {
    let total: Int
    let goal: Int
    let reminderInterval: Int
    let onQuickAdd: (Int) -> Void
    let onCustomAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Water Intake")
                        .font(.title3.bold())
                    Text("Goal \(goal) ml • Every \(reminderInterval)h")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("💧")
                    .font(.system(size: 34))
            }

            ProgressView(value: progress)
                .tint(Theme.sage)

            Text("\(total) / \(goal) ml")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(AppConstants.quickWaterAmounts, id: \.self) { amount in
                    Button("+\(amount)ml") {
                        onQuickAdd(amount)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.rose)
                }

                Button("+Custom") {
                    onCustomAdd()
                }
                .buttonStyle(.bordered)
                .tint(Theme.sage)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.cream, Theme.blush.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: Theme.shadow, radius: 8, y: 4)
    }

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(total) / Double(goal), 1)
    }
}
