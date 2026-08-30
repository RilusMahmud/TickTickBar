import Foundation

// MARK: - Models

struct TaskRow: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var projectId: String
    var title: String
    var priority: Int          // 0=None, 1=Low, 3=Medium, 5=High
    var status: Int            // 0=Open, 2=Completed
    var isAllDay: Bool
    var dueDate: Date?
    var sortOrder: Double?

    var isOpen: Bool { status == 0 }
}

struct HabitRow: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var goal: Double
    var step: Int
    var unit: String
    var totalCheckIns: Int
}

struct HabitCheckin: Codable, Equatable {
    var habitId: String
    var stamp: Int             // YYYYMMDD
    var value: Double          // 1 = checked, 0 = unchecked
}

enum CLIRunnerError: Error, Equatable {
    case notFound
    case authOrApi(String)
    case decode(String)
}

// MARK: - CLI wrapper
// Runs the local ticktick CLI as a child process; JSON in/out.

enum TickTickCLI {
    static let todoProjectID = "681b30c08f08d916d69230ad"

    private static let binary: String = {
        let preferred = "/opt/homebrew/bin/ticktick"
        return FileManager.default.isExecutableFile(atPath: preferred) ? preferred : "ticktick" // bare name resolves via PATH
    }()

    /// Dates from the API: "2026-08-26T18:00:00.000+0000"
    private static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return f
    }()

    private static let isoFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = apiDateFormatter.date(from: s) { return date }
            if let date = isoFallback.date(from: s) { return date }
            // Offset without millis: strip and retry once.
            if let date = isoFallback.date(from: s.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unparseable date \(s)")
        }
        return d
    }

    /// Spawn the CLI, wait (bounded), return stdout data.
    @discardableResult
    private static func run(_ args: [String]) throws -> Data {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        if binary.hasPrefix("/") { p.executableURL = URL(fileURLWithPath: binary) }
        p.arguments = args

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        // Drain pipes concurrently so large responses can't fill the 64KB
        // buffer and deadlock the child before we reach readDataToEndOfFile.
        var outData = Data(); var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ticktickbar.cli-pipes", attributes: .concurrent)
        group.enter(); queue.async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); queue.async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }

        do {
            try p.run()
        } catch {
            out.fileHandleForReading.closeFile(); err.fileHandleForReading.closeFile()
            throw CLIRunnerError.notFound
        }

        // 15s cap so a hung CLI can't wedge the app.
        let deadline = Date().addingTimeInterval(15)
        while p.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if p.isRunning {
            p.terminate()
            group.wait()
            throw CLIRunnerError.authOrApi("CLI timed out")
        }
        group.wait()

        guard p.terminationStatus == 0 else {
            let msg = String(data: errData, encoding: .utf8) ?? "unknown error"
            let firstLine = msg.split(separator: "\n").first.map(String.init) ?? msg
            let trimmed = String(firstLine.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw CLIRunnerError.authOrApi("CLI exited \(p.terminationStatus)") }
            throw CLIRunnerError.authOrApi(trimmed)
        }
        return outData
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try makeDecoder().decode(type, from: data) }
        catch { throw CLIRunnerError.decode(String(describing: error)) }
    }

    // MARK: Date helpers (local timezone for CLI args)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func utcInstant(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f.string(from: date)
    }

    // MARK: Task commands

    /// Open + completed tasks whose due date falls in [start, end].
    static func tasksInRange(_ start: Date, _ end: Date) throws -> [TaskRow] {
        let data = try run(["task", "filter",
                            "--start-date", dayFormatter.string(from: start),
                            "--end-date", dayFormatter.string(from: end),
                            "--status", "0,2",
                            "--json"])
        return try decode([TaskRow].self, data)
    }

    /// Create an all-day task in the todos project. `due` nil → today.
    static func createTask(title: String, due: Date?) throws -> TaskRow {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: due ?? Date())
        comps.hour = 23; comps.minute = 59
        let dueDate = cal.date(from: comps) ?? Date()
        let data = try run(["task", "create",
                            "--title", title,
                            "--project", todoProjectID,
                            "--due-date", utcInstant(dueDate),
                            "--all-day",
                            "--json"])
        return try decode(TaskRow.self, data)
    }

    static func completeTask(_ task: TaskRow) throws {
        try run(["task", "complete", task.projectId, task.id])
    }

    static func deleteTask(_ task: TaskRow) throws {
        try run(["task", "delete", task.projectId, task.id])
    }

    // MARK: Habit commands

    static func habits() throws -> [HabitRow] {
        try decode([HabitRow].self, try run(["habit", "list", "--json"]))
    }

    /// value 1 = check in, 0 = uncheck.
    static func checkin(habitID: String, stamp: Int, value: Double) throws {
        try run(["habit", "checkin", habitID,
                 "--stamp", String(stamp),
                 "--value", String(format: "%g", value)])
    }

    /// NOTE: upstream checkins read currently returns [] even after writes; kept wired for when it's fixed.
    static func checkins(habitIDs: [String], from: Int, to: Int) throws -> [HabitCheckin] {
        guard !habitIDs.isEmpty else { return [] }
        let data = try run(["habit", "checkins",
                            "--habits", habitIDs.joined(separator: ","),
                            "--from", String(from),
                            "--to", String(to),
                            "--json"])
        return try decode([HabitCheckin].self, data)
    }
}
