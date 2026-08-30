import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var tasks: [TaskRow] = []
    @Published var habits: [HabitRow] = []
    @Published var habitDoneToday: Set<String> = []
    @Published var checkinCounts: [Int: Int] = [:]  // stamp → count; stays empty while upstream read is broken
    @Published var lastSync: Date?
    @Published var error: String?
    @Published var openCount: Int = 0

    private var pollTask: Task<Void, Never>?

    init() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                await self?.refresh()
            }
        }
    }

    deinit { pollTask?.cancel() }

    // MARK: Reads (CLI calls run off-main)

    private func call<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) { try work() }.value
    }

    func refresh() async {
        await refreshTasks()
        await refreshHabits()
        lastSync = Date()
    }

    func refreshTasks() async {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: Date())) ?? Date()
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        do {
            tasks = try await call { try TickTickCLI.tasksInRange(start, end) }
            self.error = nil
        } catch {
            tasks = []
            self.error = Self.friendly(error)
        }
        recomputeOpenCount()
    }

    func refreshHabits() async {
        do {
            habits = try await call { try TickTickCLI.habits() }
        } catch {
            habits = []
        }
        recomputeOpenCount()
    }

    private func recomputeOpenCount() {
        let cal = Calendar.current
        let endOfToday = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        openCount = tasks.filter { $0.isOpen && $0.dueDate != nil && $0.dueDate! < endOfToday }.count
    }

    static func friendly(_ error: Error) -> String {
        switch error as? CLIRunnerError {
        case .notFound: return "TickTick CLI not found"
        case .authOrApi(let msg): return msg
        case .decode(let msg): return "Decode error: \(msg)"
        default: return String(describing: error)
        }
    }

    // MARK: Task writes (optimistic, revert on failure)

    func toggleComplete(_ task: TaskRow) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let wasOpen = tasks[idx].isOpen
        tasks[idx].status = wasOpen ? 2 : 0
        recomputeOpenCount()
        guard wasOpen else {
            error = "Uncomplete not supported by CLI yet"
            return
        }
        do {
            try await call { try TickTickCLI.completeTask(task) }
            error = nil
        } catch {
            tasks[idx].status = 0
            recomputeOpenCount()
            self.error = Self.friendly(error)
        }
    }

    func delete(_ task: TaskRow) async {
        let idx = tasks.firstIndex(where: { $0.id == task.id }) ?? 0
        tasks.removeAll { $0.id == task.id }
        recomputeOpenCount()
        do {
            try await call { try TickTickCLI.deleteTask(task) }
            error = nil
        } catch {
            tasks.insert(task, at: min(idx, tasks.count))
            recomputeOpenCount()
            self.error = Self.friendly(error)
        }
    }

    func addTask(_ title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let created = try await call { try TickTickCLI.createTask(title: trimmed, due: nil) }
            tasks.append(created)
            recomputeOpenCount()
            error = nil
        } catch {
            self.error = Self.friendly(error)
        }
    }

    // MARK: Habit writes

    func toggleCheckin(_ habit: HabitRow) async {
        let nowChecked = !habitDoneToday.contains(habit.id)
        if nowChecked { habitDoneToday.insert(habit.id) } else { habitDoneToday.remove(habit.id) }
        if let idx = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[idx].totalCheckIns += nowChecked ? 1 : -1
        }
        let stamp = Self.todayStamp()
        checkinCounts[stamp] = habitDoneToday.count
        do {
            try await call { try TickTickCLI.checkin(habitID: habit.id, stamp: stamp, value: nowChecked ? 1 : 0) }
            error = nil
        } catch {
            if nowChecked { habitDoneToday.remove(habit.id) } else { habitDoneToday.insert(habit.id) }
            if let idx = habits.firstIndex(where: { $0.id == habit.id }) {
                habits[idx].totalCheckIns += nowChecked ? -1 : 1
            }
            checkinCounts[stamp] = habitDoneToday.count
            self.error = Self.friendly(error)
        }
    }

    static func todayStamp() -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
