import SwiftUI

struct PopoverRoot: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab: Tab = .tasks

    enum Tab: Hashable { case tasks, habits }

    var body: some View {
        VStack(spacing: 0) {
            header

            segControl
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            // Hidden shortcuts: ⌘R refresh, ⌘1/⌘2 tabs
            Group {
                Button("") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                Button("") { selectedTab = .tasks }.keyboardShortcut("1", modifiers: .command)
                Button("") { selectedTab = .habits }.keyboardShortcut("2", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0.001)
            .accessibilityHidden(true)

            if let err = store.error, store.showErrorBanner {
                errorBanner(err, authRelated: store.isAuthError)
            }

            Group {
                switch selectedTab {
                case .tasks: TasksView()
                case .habits: HabitsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .frame(width: 356, height: selectedTab == .tasks ? 452 : 696)
        .background(Theme.base)
        .onAppear { Task { await store.refresh() } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedTab == .tasks ? TasksView.headline : "Habits")
                .font(.system(size: 14.5, weight: .bold))
                .foregroundColor(Theme.text)
            Spacer()
            Text(selectedTab == .tasks ? "\(store.openCount) open" : "\(store.habitDoneToday.count) / \(store.habits.count) today")
                .font(.system(size: 11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(Theme.subtext0)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.surface0, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 10)
    }

    private var segControl: some View {
        HStack(spacing: 2) {
            segButton("Tasks", tab: .tasks)
            segButton("Habits", tab: .habits)
        }
        .padding(2)
        .background(Theme.crust, in: RoundedRectangle(cornerRadius: 8))
    }

    private func segButton(_ label: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selectedTab == tab ? Theme.text : Theme.subtext0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.surface1)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private func errorBanner(_ message: String, authRelated: Bool) -> some View {
        Button {
            if authRelated {
                Task.detached(priority: .userInitiated) {
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ticktick")
                    p.arguments = ["auth", "login"]
                    try? p.run()
                }
            } else {
                Task { await store.refresh() }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text(message)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(authRelated ? "open ticktick auth" : "retry")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Theme.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.red.opacity(0.12))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(store.error == nil ? Theme.green : Theme.red)
                    .frame(width: 6, height: 6)
                if let sync = store.lastSync, store.error == nil {
                    Text("synced via ticktick cli · \(Self.timeFormatter.string(from: sync))")
                } else if store.error != nil {
                    Text("sync failed")
                } else {
                    Text("syncing…")
                }
            }
            .font(.system(size: 10.5))
            .foregroundColor(Theme.overlay0)

            Spacer()

            Menu {
                Button {
                    try? LoginItem.toggle()
                } label: {
                    if LoginItem.isEnabled { Text("✓ Launch at Login") } else { Text("Launch at Login") }
                }
                .disabled(!Bundle.main.bundlePath.hasSuffix(".app"))
                Button("Open ticktick auth") {
                    Task.detached(priority: .userInitiated) {
                        let p = Process()
                        p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ticktick")
                        p.arguments = ["auth", "login"]
                        try? p.run()
                    }
                }
                Divider()
                Button("Quit TickTickBar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.overlay0)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22, height: 18)

            Text("⌘R refresh")
                .font(.system(size: 10.5))
                .foregroundColor(Theme.overlay0)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Theme.mantle)
        .overlay(Rectangle().fill(Theme.overlay0.opacity(0.2)).frame(height: 1), alignment: .top)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension AppStore {
    fileprivate var showErrorBanner: Bool { true }

    // Auth failures surface as 401-ish messages from the CLI.
    fileprivate var isAuthError: Bool {
        guard let e = error else { return false }
        return e.lowercased().contains("401")
            || e.lowercased().contains("unauthorized")
            || e.lowercased().contains("token")
            || e.lowercased().contains("auth")
    }
}
