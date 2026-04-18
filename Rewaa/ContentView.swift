//
//  ContentView.swift
//  Rewaa
//
//  Created by Linda on 17/04/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("preferredAppearance") private var preferredAppearance = AppearanceOption.system.rawValue

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            RoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.clipboard")
                }

            WaterView()
                .tabItem {
                    Label("Water", systemImage: "drop.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Theme.rose)
        .preferredColorScheme(colorScheme)
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
