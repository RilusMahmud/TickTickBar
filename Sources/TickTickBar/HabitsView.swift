import SwiftUI

struct HabitsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HabitCalendarView(counts: store.checkinCounts, totalHabits: max(store.habits.count, 1))
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            Text("TODAY")
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1)
                .foregroundColor(Theme.overlay0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if store.habits.isEmpty {
                Text("No habits")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.overlay0)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ForEach(store.habits) { habit in
                    HabitRowView(habit: habit)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Calendar heatmap

struct HabitCalendarView: View {
    let counts: [Int: Int]   // stamp → checkins that day
    let totalHabits: Int
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Self.monthTitle(displayedMonth))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                HStack(spacing: 2) {
                    navButton("chevron.left") { displayedMonth = cal.addMonths(-1, to: displayedMonth) }
                    navButton("chevron.right") { displayedMonth = cal.addMonths(1, to: displayedMonth) }
                }
            }
            .padding(.bottom, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(Self.dowLabels, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Theme.overlay0)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Self.cells(for: displayedMonth), id: \.self) { cell in
                    cellView(cell)
                }
            }

            HStack(spacing: 5) {
                Text("less")
                ForEach(0...3, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Self.heatColor(level))
                        .frame(width: 9, height: 9)
                }
                Text("more")
            }
            .font(.system(size: 9.5))
            .foregroundColor(Theme.overlay0)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 8)
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.subtext0)
                .frame(width: 22, height: 22)
                .background(Theme.surface0, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.overlay0.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func cellView(_ cell: Cell) -> some View {
        if let day = cell.day {
            let isToday = cal.isDateInToday(day)
            let isFuture = day > Date()
            let level = heatLevel(for: day)

            Text(String(cal.component(.day, from: day)))
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundColor(level >= 3 ? Theme.crust : (isToday ? Theme.text : Theme.subtext0))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(RoundedRectangle(cornerRadius: 7).fill(isFuture ? Theme.surface0.opacity(0.5) : Self.heatColor(level)))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isToday ? Theme.blue : .clear, lineWidth: 1.5))
                .accessibilityLabel("\(cal.component(.day, from: day)), \(level == 0 ? "no check-ins" : "\(level) level check-ins")")
        } else {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
    }

    /// 0-3 by fraction of habits done that day. Upstream checkins read returns
    /// empty, so only today (via checkinCounts) ever lights up; wiring kept for the fix.
    func heatLevel(for day: Date) -> Int {
        let count = counts[Self.stamp(day)] ?? 0
        guard count > 0, totalHabits > 0 else { return 0 }
        let frac = Double(count) / Double(totalHabits)
        if frac >= 0.99 { return 3 }
        if frac >= 0.6 { return 2 }
        if frac >= 0.25 { return 1 }
        return 0
    }

    struct Cell: Hashable { var day: Date? }

    static func cells(for month: Date) -> [Cell] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstOfMonth = cal.startOfMonth(for: month)
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let blanks = [Cell](repeating: Cell(day: nil), count: firstWeekday - 1)
        let days = range.compactMap { offset -> Cell in
            var c = cal.dateComponents([.year, .month, .day], from: firstOfMonth)
            c.day = offset
            return Cell(day: cal.date(from: c))
        }
        return blanks + days
    }

    static func stamp(_ day: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    static func heatColor(_ level: Int) -> Color {
        switch level {
        case 1: return Theme.green.opacity(0.25)
        case 2: return Theme.green.opacity(0.5)
        case 3: return Theme.green.opacity(0.75)
        default: return Theme.surface0
        }
    }

    static let dowLabels = ["S", "M", "T", "W", "T", "F", "S"]

    static func monthTitle(_ month: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month)
    }
}

// MARK: - Habit row

struct HabitRowView: View {
    @EnvironmentObject var store: AppStore
    let habit: HabitRow
    @State private var hovering = false

    private var checked: Bool { store.habitDoneToday.contains(habit.id) }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Task { await store.toggleCheckin(habit) }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(checked ? Theme.green : Theme.overlay0, lineWidth: 2)
                        .background(Circle().fill(checked ? Theme.green : Color.clear))
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.crust)
                        .opacity(checked ? 1 : 0)
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checked ? "Uncheck \(habit.name)" : "Check in \(habit.name)")

            VStack(alignment: .leading, spacing: 1) {
                Text(habit.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(checked ? Theme.overlay0 : Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(checked ? "done" : "daily · goal \(Int(habit.goal)) \(habit.unit.lowercased())")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.subtext0)
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                Text("\(max(habit.totalCheckIns, 0))")
                    .monospacedDigit()
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(Theme.peach)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(hovering ? AnyShapeStyle(Theme.surface0) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 6)
        .onHover { hovering = $0 }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let c = dateComponents([.year, .month], from: date)
        return self.date(from: c) ?? date
    }

    func addMonths(_ n: Int, to date: Date) -> Date {
        self.date(byAdding: .month, value: n, to: date) ?? date
    }
}
