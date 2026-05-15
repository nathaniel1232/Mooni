//
//  MooniSleepWidgetBundle.swift
//  MooniSleepWidget
//

import WidgetKit
import SwiftUI

@main
struct MooniSleepWidgetBundle: WidgetBundle {
    var body: some Widget {
        MooniSleepWidget()
        // MooniFriendsSleepWidget — hidden until backend friend-sync is built.
        // Re-add once FriendsWidgetStore is actually being written to from a
        // real friends backend (see FriendsSleepData.swift wire-up plan).
    }
}
