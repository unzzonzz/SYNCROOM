//  SYNCROOMApp.swift
//  Composition root: the one place the app's shared state is created and the
//  one place a real `DataSource` would replace `MockDataSource`.

import SwiftUI

@main
struct SYNCROOMApp: App {
    @State private var session = SessionModel()
    @State private var router = AppRouter()
    @State private var playback = PlaybackController()
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(router)
                .environment(playback)
                .environment(settings)
                // Chrome is ink. The accent is reserved for what it means —
                // live, donation, warning, destructive — so it never becomes
                // decoration on navigation controls.
                .tint(Palette.ink)
        }
    }
}
