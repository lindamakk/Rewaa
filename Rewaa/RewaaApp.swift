//
//  RewaaApp.swift
//  Rewaa
//
//  Created by Linda on 17/04/2026.
//

import SwiftData
import SwiftUI

@main
struct RewaaApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var routineViewModel: RoutineViewModel
    @StateObject private var waterViewModel: WaterViewModel

    init() {
        let schema = Schema([
            RoutineItem.self,
            WaterLog.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }

        sharedModelContainer = container
        _routineViewModel = StateObject(
            wrappedValue: RoutineViewModel(modelContext: container.mainContext)
        )
        _waterViewModel = StateObject(
            wrappedValue: WaterViewModel(modelContext: container.mainContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(routineViewModel)
                .environmentObject(waterViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
