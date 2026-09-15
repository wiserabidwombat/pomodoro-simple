// PomodoroWidget/PomodoroIdleWidget.swift
import WidgetKit
import SwiftUI

struct PomodoroIdleEntry: TimelineEntry {
    let date: Date
    let accentColor: AccentColorOption
}

struct PomodoroIdleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroIdleEntry {
        PomodoroIdleEntry(date: Date(), accentColor: .white)
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroIdleEntry) -> Void) {
        completion(PomodoroIdleEntry(date: Date(), accentColor: PomodoroStateStore().loadAccentColor()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroIdleEntry>) -> Void) {
        let entry = PomodoroIdleEntry(date: Date(), accentColor: PomodoroStateStore().loadAccentColor())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct PomodoroIdleWidgetView: View {
    let entry: PomodoroIdleEntry

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.title2)
            Text("Pomodoro")
                .font(.caption)
        }
        .foregroundStyle(entry.accentColor.color)
        // iOS 17+ widgets must declare their background via containerBackground
        // rather than an opaque view in the body — the system manages
        // rendering (including StandBy's full-color mode) around it.
        .containerBackground(.black, for: .widget)
    }
}

struct PomodoroIdleWidget: Widget {
    let kind = "PomodoroIdleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroIdleProvider()) { entry in
            PomodoroIdleWidgetView(entry: entry)
                .widgetURL(URL(string: "pomodoro://open"))
        }
        .configurationDisplayName("Pomodoro")
        .description("Quick access to your Pomodoro timer.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}
