import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var routineViewModel: RoutineViewModel
    @EnvironmentObject private var waterViewModel: WaterViewModel

    @State private var isPresentingAddRoutine = false
    @State private var isPresentingCustomWaterSheet = false
    @State private var customAmount = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        todayRoutineSection
                        waterCardSection
                    }
                    .padding()
                }
                .background(Theme.cream.opacity(0.35))

                Button {
                    isPresentingAddRoutine = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Theme.rose)
                        .clipShape(Circle())
                        .shadow(color: Theme.shadow, radius: 8, y: 4)
                }
                .padding()
            }
            .navigationTitle("Home")
            .sheet(isPresented: $isPresentingAddRoutine) {
                AddEditRoutineView()
            }
            .sheet(isPresented: $isPresentingCustomWaterSheet) {
                NavigationStack {
                    Form {
                        TextField("Amount in ml", text: $customAmount)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                    }
                    .navigationTitle("Custom Water")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isPresentingCustomWaterSheet = false
                                customAmount = ""
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                if let amount = Int(customAmount), amount > 0 {
                                    waterViewModel.addWater(amount: amount)
                                }
                                isPresentingCustomWaterSheet = false
                                customAmount = ""
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hello, beauty!")
                .font(.largeTitle.bold())
                .environment(\.layoutDirection, .rightToLeft)

            Text(greeting)
                .font(.title3.weight(.semibold))

            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.blush, Theme.cream],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: Theme.shadow, radius: 8, y: 4)
    }

    private var todayRoutineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Routine")
                .font(.title3.bold())

            if routineViewModel.todayRoutineItems().isEmpty {
                emptyState(
                    symbol: "sparkles",
                    title: "No routines for today",
                    message: "Add a routine to build your beauty flow."
                )
            } else {
                ForEach(routineViewModel.todayRoutineItems()) { item in
                    RoutineItemRow(item: item)
                }
            }
        }
    }

    private var waterCardSection: some View {
        WaterProgressCard(
            total: waterViewModel.totalToday,
            goal: waterViewModel.dailyGoal,
            reminderInterval: waterViewModel.reminderIntervalHours,
            onQuickAdd: { amount in
                waterViewModel.addWater(amount: amount)
            },
            onCustomAdd: {
                isPresentingCustomWaterSheet = true
            }
        )
    }

    private func emptyState(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(Theme.sage)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: Theme.shadow, radius: 8, y: 4)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
}
