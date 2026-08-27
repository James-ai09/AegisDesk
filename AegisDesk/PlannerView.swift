import SwiftUI
import EventKit
import Combine

@MainActor
final class PlannerStore: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var eventsConnected = false
    @Published var remindersConnected = false
    @Published var errorMessage = ""

    func prepare() async {
        eventsConnected = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        remindersConnected = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        if eventsConnected || remindersConnected { await refresh() }
    }

    func connectEvents() async {
        do {
            eventsConnected = try await eventStore.requestFullAccessToEvents()
            errorMessage = eventsConnected ? "" : "Calendar access was not granted. You can enable it in System Settings."
            if eventsConnected { await refresh() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectReminders() async {
        do {
            remindersConnected = try await eventStore.requestFullAccessToReminders()
            errorMessage = remindersConnected ? "" : "Reminders access was not granted. You can enable it in System Settings."
            if remindersConnected { await refresh() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        eventsConnected = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        remindersConnected = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        if eventsConnected {
            let start = Calendar.current.startOfDay(for: Date())
            let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        }
        if remindersConnected {
            let reminderPredicate = eventStore.predicateForReminders(in: nil)
            reminders = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: reminderPredicate) { items in
                    continuation.resume(returning: (items ?? []).filter { !$0.isCompleted }.sorted {
                        ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture)
                    })
                }
            }
        }
        if !eventsConnected { events = [] }
        if !remindersConnected { reminders = [] }
    }

    func addEvent(title: String, start: Date, duration: TimeInterval) throws {
        guard let calendar = eventStore.defaultCalendarForNewEvents else { throw PlannerError.noCalendar }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(duration)
        event.calendar = calendar
        try eventStore.save(event, span: .thisEvent)
    }

    func addReminder(title: String, dueDate: Date) throws {
        guard let calendar = eventStore.defaultCalendarForNewReminders() else { throw PlannerError.noReminderList }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        try eventStore.save(reminder, commit: true)
    }

    enum PlannerError: LocalizedError {
        case noCalendar, noReminderList
        var errorDescription: String? {
            switch self {
            case .noCalendar: "No writable Apple calendar is available."
            case .noReminderList: "No writable Apple reminder list is available."
            }
        }
    }
}

struct PlannerView: View {
    let planWithAI: (String) -> Void
    @StateObject private var store = PlannerStore()
    @State private var showingNewEvent = false
    @State private var showingNewReminder = false
    @AppStorage("plannerPriorityOne") private var priorityOne = ""
    @AppStorage("plannerPriorityTwo") private var priorityTwo = ""
    @AppStorage("plannerPriorityThree") private var priorityThree = ""

    var body: some View {
        plannerContent
        .navigationTitle("Planner")
        .toolbar {
            if store.eventsConnected || store.remindersConnected {
                ToolbarItemGroup(placement: .primaryAction) {
                    if store.eventsConnected {
                        Button("New event", systemImage: "calendar.badge.plus") { showingNewEvent = true }
                    }
                    if store.remindersConnected {
                        Button("New reminder", systemImage: "checklist") { showingNewReminder = true }
                    }
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                }
            }
        }
        .task { await store.prepare() }
        .sheet(isPresented: $showingNewEvent) { NewPlannerItemView(kind: .event) { title, date in
            try store.addEvent(title: title, start: date, duration: 3600)
            Task { await store.refresh() }
        } }
        .sheet(isPresented: $showingNewReminder) { NewPlannerItemView(kind: .reminder) { title, date in
            try store.addReminder(title: title, dueDate: date)
            Task { await store.refresh() }
        } }
    }

    private var plannerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 9 : 14) {
                weekOverview
                prioritiesCard
                FocusSessionCard(planWithAI: planWithAI)
                TeamTimeZonesCard()
                if store.eventsConnected || store.remindersConnected {
                    dailyBriefing
                }
                if store.eventsConnected {
                    plannerSection("Upcoming events", symbol: "calendar") {
                        ForEach(store.events, id: \.eventIdentifier) { event in
                            PlannerRow(
                                title: event.title ?? "Untitled event",
                                date: event.startDate,
                                symbol: "calendar",
                                detail: eventDetail(event)
                            )
                        }
                        if store.events.isEmpty { Text("No events in the next seven days.").foregroundStyle(.secondary) }
                    }
                }
                if store.remindersConnected {
                    plannerSection("Open reminders", symbol: "checklist") {
                        ForEach(store.reminders, id: \.calendarItemIdentifier) { reminder in
                            PlannerRow(title: reminder.title, date: reminder.dueDateComponents?.date, symbol: "circle")
                        }
                        if store.reminders.isEmpty { Text("No open reminders.").foregroundStyle(.secondary) }
                    }
                }
                if !store.eventsConnected || !store.remindersConnected {
                    connectionCard
                }
            }
            .frame(maxWidth: AegisLayout.contentMaxWidth(900), alignment: .leading)
        }
        .contentMargins(AegisLayout.pagePadding, for: .scrollContent)
    }

    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Seven-day overview", systemImage: "chart.bar.fill").font(.headline)
                Spacer()
                Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: AegisDeviceClass.current == .phone ? 92 : 130), spacing: 8)], spacing: 8) {
                PlannerMetric(value: "\(store.events.count)", title: "Events", symbol: "calendar")
                PlannerMetric(value: scheduledDuration, title: "Scheduled", symbol: "clock")
                PlannerMetric(value: "\(store.reminders.count)", title: "Reminders", symbol: "checklist")
                PlannerMetric(value: "\(overdueReminderCount)", title: "Overdue", symbol: "exclamationmark.circle")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AegisDeviceClass.current == .phone ? 10 : 14)
        .glassEffect(.regular.tint(.accentColor.opacity(0.08)), in: RoundedRectangle(cornerRadius: 18))
    }

    private var prioritiesCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Top priorities", systemImage: "flag.fill").font(.headline)
            priorityField(number: 1, text: $priorityOne)
            priorityField(number: 2, text: $priorityTwo)
            priorityField(number: 3, text: $priorityThree)
            Text("Priorities are stored locally on this device.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AegisDeviceClass.current == .phone ? 10 : 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    private func priorityField(number: Int, text: Binding<String>) -> some View {
        HStack(spacing: 9) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 25, height: 25)
                .background(Color.accentColor.opacity(0.13), in: Circle())
            TextField("Priority \(number)", text: text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
    }

    private var scheduledDuration: String {
        let seconds = store.events.reduce(0.0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
        let hours = seconds / 3600
        return hours < 10 ? hours.formatted(.number.precision(.fractionLength(1))) + "h" : Int(hours).formatted() + "h"
    }

    private var overdueReminderCount: Int {
        store.reminders.filter { reminder in
            guard let due = reminder.dueDateComponents?.date else { return false }
            return due < Date()
        }.count
    }

    private func eventDetail(_ event: EKEvent) -> String {
        let minutes = max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        let duration = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        return "\(duration) · \(event.calendar.title)"
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Apple Calendar & Reminders", systemImage: "calendar.badge.clock").font(.headline)
            Text("Connect to see your schedule and create items in the device’s configured accounts.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                if !store.eventsConnected {
                    Button("Connect Calendar", systemImage: "calendar") { Task { await store.connectEvents() } }
                        .buttonStyle(AegisPrimaryButtonStyle())
                }
                if !store.remindersConnected {
                    Button("Connect Reminders", systemImage: "checklist") { Task { await store.connectReminders() } }
                        .buttonStyle(AegisPrimaryButtonStyle())
                }
            }
            if !store.errorMessage.isEmpty { Text(store.errorMessage).font(.caption).foregroundStyle(.red) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private var dailyBriefing: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Daily Briefing", systemImage: "sun.max.fill").font(.headline)
            Text("\(store.events.filter { Calendar.current.isDateInToday($0.startDate) }.count) events today · \(store.reminders.count) open reminders")
                .foregroundStyle(.secondary)
            Button("Plan my day with AI", systemImage: "sparkles") { planWithAI(briefingPrompt) }
                .buttonStyle(AegisPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: RoundedRectangle(cornerRadius: 18))
    }

    private var briefingPrompt: String {
        let eventLines = store.events.prefix(8).map { "- \($0.title ?? "Event") at \($0.startDate.formatted(date: .abbreviated, time: .shortened))" }
        let reminderLines = store.reminders.prefix(8).map { "- \($0.title ?? "Reminder")" }
        return "Help me plan my day. Upcoming events:\n\(eventLines.joined(separator: "\n"))\nOpen reminders:\n\(reminderLines.joined(separator: "\n"))"
    }

    private func plannerSection<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TeamTimeZonesCard: View {
    private let zones = [
        ("London", "Europe/London"),
        ("New York", "America/New_York"),
        ("Tokyo", "Asia/Tokyo")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Team time zones", systemImage: "globe.europe.africa.fill").font(.headline)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 10) {
                    ForEach(zones, id: \.1) { zone in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.0).font(.caption).foregroundStyle(.secondary)
                            Text(time(context.date, zone: zone.1)).font(.headline.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func time(_ date: Date, zone: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct FocusSessionCard: View {
    let planWithAI: (String) -> Void
    @State private var goal = ""
    @State private var duration = 25
    @State private var endDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Focus Session", systemImage: "timer").font(.headline)
                Spacer()
                if let endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(remaining(until: endDate, at: context.date))
                            .font(.title3.monospacedDigit().bold())
                    }
                }
            }

            TextField("What do you want to focus on?", text: $goal)
                .textFieldStyle(.roundedBorder)

            if endDate == nil {
                Picker("Length", selection: $duration) {
                    Text("15 min").tag(15)
                    Text("25 min").tag(25)
                    Text("50 min").tag(50)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                if endDate == nil {
                    Button("Start focus", systemImage: "play.fill") {
                        endDate = Date().addingTimeInterval(TimeInterval(duration * 60))
                    }
                    .buttonStyle(AegisPrimaryButtonStyle())
                    .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("End session", systemImage: "stop.fill") { endDate = nil }
                        .buttonStyle(AegisSecondaryButtonStyle())
                }
                Button("Make an AI action plan", systemImage: "sparkles") {
                    planWithAI("Create a concise action plan for a \(duration)-minute focus session on: \(goal)")
                }
                .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular.tint(.accentColor.opacity(0.10)), in: RoundedRectangle(cornerRadius: 18))
    }

    private func remaining(until endDate: Date, at now: Date) -> String {
        let seconds = max(0, Int(endDate.timeIntervalSince(now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PlannerRow: View {
    let title: String
    let date: Date?
    let symbol: String
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(1)
                if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            if let date { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 3)
    }
}

private struct PlannerMetric: View {
    let value: String
    let title: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol).foregroundStyle(.tint)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct NewPlannerItemView: View {
    enum Kind { case event, reminder }
    let kind: Kind
    let save: (String, Date) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(kind == .event ? "Event title" : "Reminder title", text: $title)
                DatePicker("Date and time", selection: $date)
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle(kind == .event ? "New Event" : "New Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try save(title, date); dismiss() } catch { errorMessage = error.localizedDescription }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(idealWidth: 460, idealHeight: 300)
    }
}
