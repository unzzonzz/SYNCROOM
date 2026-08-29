//  SettingsStore.swift
//  User preferences that outlive a single screen.
//
//  Held in memory only — persistence is out of scope while there is no backend,
//  and inventing a store now would be guessing at the eventual shape.

import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {

    // Notifications
    var liveStartAlerts = true
    var followAlerts = true
    var donationAlerts = true
    var marketingAlerts = false

    // Audio and playback
    var preferredInputDevice: AudioDevice = Fixtures.audioDevices[0]
    var dataSaver = false
    var autoplay = true
}
