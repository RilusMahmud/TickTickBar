import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: AppStore
    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                let buckets = Self.bucket(store.tasks)

                LazyVStack(spacing: 0) {
                    if buckets.overdue.isEmpty && buckets.today.isEmpty {
                        emptyState
                    } else {
                        if !buckets.overdue.isEmpty {
                            groupLabel("Overdue")
                            ForEach(buckets.overdue) { TaskListRow(task: $0) }
                        }
                        if !buckets.today.isEmpty {
                            groupLabel("Today")
                            ForEach(buckets.today) { TaskListRow(task: $0) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            addField
        }
        .padding(.bottom, 8)
    }

    // MARK: Sections

    private func groupLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(1)
            .foregroundColor(Theme.overlay0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 2) {
            Text("All clear")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(Theme.subtext0)
            Text("Nothing due today")
                .font(.system(size: 12.5))
                .foregroundColor(Theme.overlay0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.blue)
            TextField("Add a task for today…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.text)
                .onSubmit { submit() }
                .focused($fieldFocused)
            Text("⏎")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundColor(Theme.overlay0)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Theme.mantle, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.overlay0.opacity(0.3)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.crust, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.overlay0.opacity(0.25)))
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }

    private func submit() {
        let title = newTitle
        newTitle = ""
        Task { await store.addTask(title) }
        fieldFocused = true
    }

    // MARK: Grouping

    struct Buckets { var overdue: [TaskRow]; var today: [TaskRow] }

    static func bucket(_ tasks: [TaskRow]) -> Buckets {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let endToday = cal.date(byAdding: .day, value: 1, to: startToday) ?? startToday

        var overdue: [TaskRow] = []
        var today: [TaskRow] = []
        for t in tasks where t.dueDate != nil {
            if t.isOpen && t.dueDate! < startToday {
                overdue.append(t)
            } else if t.dueDate! < endToday {
                today.append(t)
            }
        }
        let byDateThenOrder: (TaskRow, TaskRow) -> Bool = { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?): return x != y ? x < y : (a.sortOrder ?? 0) < (b.sortOrder ?? 0)
            default: return (a.sortOrder ?? 0) < (b.sortOrder ?? 0)
            }
        }
        return Buckets(overdue: overdue.sorted(by: byDateThenOrder), today: today.sorted(by: byDateThenOrder))
    }

    static var headline: String {
        let f = DateFormatter()
        f.dateFormat = "Today · EEE, MMM d"
        return f.string(from: Date())
    }
}

// MARK: - Row

private struct TaskListRow: View {
    @EnvironmentObject var store: AppStore
    let task: TaskRow
    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            checkbox
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.isOpen ? Theme.text : Theme.overlay0)
                    .strikethrough(!task.isOpen, color: Theme.overlay0)
                    .lineLimit(1)
                    .truncationMode(.tail)
                metaLine
            }
            Spacer(minLength: 4)
            priorityDot
            if hovering || confirmingDelete { deleteControl }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hovering ? AnyShapeStyle(Theme.surface0) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.isOpen ? "open" : "completed")")
    }

    private var checkbox: some View {
        Button {
            Task { await store.toggleComplete(task) }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(task.isOpen ? Theme.overlay0 : Theme.green, lineWidth: 1.5)
                    .background(Circle().fill(task.isOpen ? Color.clear : Theme.green))
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.crust)
                    .opacity(task.isOpen ? 0 : 1)
            }
            .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isOpen ? "Complete \(task.title)" : "Uncomplete \(task.title)")
    }

    @ViewBuilder private var metaLine: some View {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let isOverdue = task.isOpen && task.dueDate.map { $0 < startToday } == true

        HStack(spacing: 8) {
            Text(Self.metaText(task, isOverdue: isOverdue))
                .foregroundColor(isOverdue ? Theme.red : Theme.subtext0)
                .fontWeight(isOverdue ? .semibold : .regular)
            if let proj = Self.projectName(task.projectId) {
                Text("#\(proj)")
                    .foregroundColor(Theme.overlay0)
            }
        }
        .font(.system(size: 11))
        .monospacedDigit()
    }

    private var priorityDot: some View {
        Circle()
            .fill(Self.priorityColor(task.priority))
            .frame(width: 7, height: 7)
    }

    @ViewBuilder private var deleteControl: some View {
        if confirmingDelete {
            HStack(spacing: 4) {
                Button {
                    Task { await store.delete(task) }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.crust)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.red)
                Button {
                    confirmingDelete = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.subtext0)
                }
                .buttonStyle(.plain)
            }
            .accessibilityLabel("Confirm delete \(task.title)")
        } else {
            Button {
                confirmingDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.overlay0)
            }
            .buttonStyle(.plain)
            .onHover { if $0 {} }
            .accessibilityLabel("Delete \(task.title)")
        }
    }

    static func priorityColor(_ p: Int) -> Color {
        switch p {
        case 5: return Theme.red
        case 3: return Theme.yellow
        case 1: return Theme.blue
        default: return Theme.surface2
        }
    }

    static func metaText(_ task: TaskRow, isOverdue: Bool) -> String {
        guard let due = task.dueDate else { return "" }
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        if isOverdue {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: due), to: startToday).day ?? 0
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "\(days) day\(days == 1 ? "" : "s") ago · \(f.string(from: due))"
        }
        if task.isAllDay { return "All day" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: due)
    }

    static func projectName(_ id: String) -> String? {
        id == TickTickCLI.todoProjectID ? "todos" : nil
    }
}
