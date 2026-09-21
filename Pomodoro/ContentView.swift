// Pomodoro/ContentView.swift
import SwiftUI

/// Adaptive root: a plain tab bar on iPhone (and iPad in narrow Slide
/// Over/Split View), a sidebar on iPad's wider layouts. horizontalSizeClass
/// is the standard SwiftUI signal for this — it already accounts for
/// Split View/Stage Manager width, not just device idiom.
struct ContentView: View {
    @ObservedObject var viewModel: TimerViewModel
    let historyStore: HistoryStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: SidebarSection? = .timer

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(SidebarSection.allCases, selection: $selection) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
                .navigationTitle("Simple: StandBy Timer")
            } detail: {
                detail(for: selection ?? .timer)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .preferredColorScheme(.dark)
        } else {
            TabView {
                TimerView(viewModel: viewModel)
                    .tabItem { Label("Timer", systemImage: "timer") }
                StatsView(viewModel: viewModel, historyStore: historyStore)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
                SettingsView(viewModel: viewModel)
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func detail(for section: SidebarSection) -> some View {
        switch section {
        case .timer:
            TimerView(viewModel: viewModel)
        case .stats:
            StatsView(viewModel: viewModel, historyStore: historyStore)
        case .settings:
            SettingsView(viewModel: viewModel)
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case timer, stats, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: "timer"
        case .stats: "chart.bar"
        case .settings: "gear"
        }
    }
}
