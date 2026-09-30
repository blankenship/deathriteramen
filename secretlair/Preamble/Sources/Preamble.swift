import SwiftUI

// MARK: - Model

struct CountdownEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var date: Date
}

@MainActor
final class EventStore: ObservableObject {
    static let maxEvents = 3
    private static let storageKey = "events"

    @Published var events: [CountdownEvent] = [] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([CountdownEvent].self, from: data) {
            events = decoded
        }
    }

    var isFull: Bool { events.count >= Self.maxEvents }

    func add(name: String, date: Date) {
        guard !isFull else { return }
        events.append(CountdownEvent(name: name, date: date))
        events.sort { $0.date < $1.date }
    }

    func remove(_ event: CountdownEvent) {
        events.removeAll { $0.id == event.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Countdown helpers

func daysUntil(_ date: Date, from now: Date) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: now)
    let end = cal.startOfDay(for: date)
    return cal.dateComponents([.day], from: start, to: end).day ?? 0
}

func countdownText(days: Int) -> String {
    switch days {
    case 0: return "Today"
    case 1: return "1 day"
    case let d where d > 1: return "\(d) days"
    case -1: return "1 day ago"
    default: return "\(-days) days ago"
    }
}

// MARK: - Views

struct EventRow: View {
    let event: CountdownEvent
    let now: Date
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        let days = daysUntil(event.date, from: now)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .lineLimit(1)
                Text(event.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete this event")
            }
            Text(countdownText(days: days))
                .font(.system(.title3, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(days < 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0))
        )
        .onHover { hovering = $0 }
    }
}

struct AddEventForm: View {
    let onAdd: (String, Date) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var date = Calendar.current.startOfDay(for: .now)
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Event name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(submit)
            DatePicker("Date", selection: $date, displayedComponents: .date)
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(10)
        .onAppear { nameFocused = true }
    }

    private func submit() {
        guard !trimmedName.isEmpty else { return }
        onAdd(trimmedName, date)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @State private var adding = false
    @State private var now = Date()

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if adding {
                AddEventForm(
                    onAdd: { name, date in
                        store.add(name: name, date: date)
                        adding = false
                    },
                    onCancel: { adding = false }
                )
                Divider()
            }
            if store.events.isEmpty && !adding {
                emptyState
            } else {
                VStack(spacing: 2) {
                    ForEach(store.events) { event in
                        EventRow(event: event, now: now) {
                            store.remove(event)
                        }
                    }
                }
                .padding(6)
            }
            Divider()
            footer
        }
        .frame(width: 300)
        .onAppear { now = Date() }
        .onReceive(clock) { now = $0 }
    }

    private var header: some View {
        HStack {
            Text("Preamble")
                .font(.headline)
            Spacer()
            Button {
                adding = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(adding || store.isFull)
            .help(store.isFull ? "You can have up to three events" : "Add an event")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "hourglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No events yet")
                .foregroundStyle(.secondary)
            Text("Click + to add one")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit Preamble") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
            Spacer()
        }
        .padding(.vertical, 7)
    }
}

// MARK: - App

@main
struct PreambleApp: App {
    @StateObject private var store = EventStore()

    var body: some Scene {
        MenuBarExtra("Preamble", systemImage: "hourglass") {
            ContentView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
