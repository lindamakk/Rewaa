//
//  ContentView.swift
//  Rewaa
//
//  Created by Linda on 17/04/2026.
//

import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case home
        case routines
        case water
        case settings
    }

    @AppStorage("preferredAppearance") private var preferredAppearance = AppearanceOption.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var routineViewModel: RoutineViewModel
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(Tab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            RoutinesView()
                .tag(Tab.routines)
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.clipboard")
                }

            WaterView()
                .tag(Tab.water)
                .tabItem {
                    Label("Water", systemImage: "drop.fill")
                }

            SettingsView()
                .tag(Tab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Theme.rose)
        .preferredColorScheme(colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            routineViewModel.syncTimersWithCurrentTime()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRoutineGroup)) { notification in
            guard
                let groupIDString = notification.userInfo?["routineGroupID"] as? String,
                let groupID = UUID(uuidString: groupIDString)
            else {
                return
            }

            selectedTab = .routines
            routineViewModel.focusGroup(with: groupID)
        }
    }

    private var colorScheme: ColorScheme? {
        switch AppearanceOption(rawValue: preferredAppearance) ?? .system {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#Preview {
    ContentView()
}
