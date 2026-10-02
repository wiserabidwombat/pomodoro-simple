// PomodoroWidget/PomodoroWidgetBundle.swift
import WidgetKit
import SwiftUI

@main
struct PomodoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        PomodoroIdleWidget()
        // On iOS 18+, the Live Activity also has a layout for the Apple
        // Watch Smart Stack; that needs an API iOS 17 doesn't have.
        if #available(iOS 18.0, *) {
            PomodoroLiveActivityWidgetWithWatch()
        } else {
            PomodoroLiveActivityWidget()
        }
    }
}
