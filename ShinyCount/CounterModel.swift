import SwiftUI
import Foundation
import AppKit

// MARK: - Macro (global, shared)

struct Macro: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var value: Int
    var keyLabel: String
}

// MARK: - Captured Pokemon

struct CapturedPokemon: Identifiable, Codable {
    var id: UUID = UUID()
    var pokemonName: String
    var pokemonID: Int
    var encounters: Int
    var capturedAt: Date = Date()
}

// MARK: - Hunt (individual counter)

struct Hunt: Identifiable, Codable {
    var id: UUID = UUID()
    var pokemonName: String = ""
    var pokemonID: Int = 0
    var count: Int = 0
    var saveFilePath: String = ""
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var hunts: [Hunt] = []
    @Published var selectedHuntID: UUID? = nil
    @Published var macros: [Macro] = []

    @Published var showMacros: Bool = false
    @Published var colorScheme: ColorScheme? = nil
    @Published var collection: [CapturedPokemon] = []
    private let huntsKey      = "savedHunts"
    private let macrosKey     = "savedMacros"
    private let collectionKey = "savedCollection"

    init() {
        loadHunts()
        loadMacros()
        loadCollection()
        if hunts.isEmpty { addHunt() }
        if selectedHuntID == nil { selectedHuntID = hunts.first?.id }
    }

    var selectedHunt: Hunt? {
        get { hunts.first { $0.id == selectedHuntID } }
        set {
            guard let h = newValue, let idx = hunts.firstIndex(where: { $0.id == h.id }) else { return }
            hunts[idx] = h
        }
    }

    // MARK: Hunt CRUD

    func addHunt() {
        let h = Hunt()
        hunts.append(h)
        selectedHuntID = h.id
        saveHunts()
    }

    func deleteHunt(id: UUID) {
        hunts.removeAll { $0.id == id }
        if selectedHuntID == id { selectedHuntID = hunts.first?.id }
        saveHunts()
    }

    func captureHunt(id: UUID) {
        guard let hunt = hunts.first(where: { $0.id == id }) else { return }
        let captured = CapturedPokemon(
            pokemonName: hunt.pokemonName,
            pokemonID: hunt.pokemonID,
            encounters: hunt.count
        )
        collection.insert(captured, at: 0)
        saveCollection()
        deleteHunt(id: id)
    }

    func deleteCaptured(id: UUID) {
        collection.removeAll { $0.id == id }
        saveCollection()
    }

    func editCaptured(id: UUID, encounters: Int) {
        guard let idx = collection.firstIndex(where: { $0.id == id }) else { return }
        collection[idx].encounters = encounters
        saveCollection()
    }

    func updateHunt(_ hunt: Hunt) {
        guard let idx = hunts.firstIndex(where: { $0.id == hunt.id }) else { return }
        hunts[idx] = hunt
        saveHunts()
        saveHuntToFile(hunt)
    }

    // MARK: Counter operations

    func increment(id: UUID) { applyDelta(1, to: id) }
    func decrement(id: UUID) { applyDelta(-1, to: id) }
    func reset(id: UUID) {
        guard let idx = hunts.firstIndex(where: { $0.id == id }) else { return }
        hunts[idx].count = 0
        saveHunts()
        saveHuntToFile(hunts[idx])
    }
    func executeMacro(_ macro: Macro, on id: UUID) {
        applyDelta(macro.value, to: id)
    }

    private func applyDelta(_ delta: Int, to id: UUID) {
        guard let idx = hunts.firstIndex(where: { $0.id == id }) else { return }
        hunts[idx].count += delta
        saveHunts()
        saveHuntToFile(hunts[idx])
    }

    // MARK: Macro CRUD

    func addMacro(name: String, value: Int, keyLabel: String) {
        macros.append(Macro(name: name, value: value, keyLabel: keyLabel))
        saveMacros()
    }
    func updateMacro(id: UUID, name: String, value: Int, keyLabel: String) {
        guard let idx = macros.firstIndex(where: { $0.id == id }) else { return }
        macros[idx] = Macro(id: id, name: name, value: value, keyLabel: keyLabel)
        saveMacros()
    }
    func deleteMacro(id: UUID) {
        macros.removeAll { $0.id == id }
        saveMacros()
    }
    func deleteAllMacros() {
        macros.removeAll()
        saveMacros()
    }

    // MARK: File I/O per hunt

    func chooseSaveFile(for id: UUID) {
        guard let idx = hunts.firstIndex(where: { $0.id == id }) else { return }
        let panel = NSSavePanel()
        panel.title = "Guardar contador"
        panel.nameFieldStringValue = "\(hunts[idx].pokemonName.isEmpty ? "counter" : hunts[idx].pokemonName).txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        hunts[idx].saveFilePath = url.path
        saveHunts()
        saveHuntToFile(hunts[idx])
    }

    func importFile(for id: UUID) {
        guard let idx = hunts.firstIndex(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.title = "Importar contador"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let v = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        hunts[idx].count = v
        hunts[idx].saveFilePath = url.path
        saveHunts()
    }

    private func saveHuntToFile(_ hunt: Hunt) {
        guard !hunt.saveFilePath.isEmpty else { return }
        let url = URL(fileURLWithPath: hunt.saveFilePath)
        try? "\(hunt.count)".write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Persistence

    private func saveHunts() {
        if let data = try? JSONEncoder().encode(hunts) {
            UserDefaults.standard.set(data, forKey: huntsKey)
        }
    }

    private func loadHunts() {
        if let data = UserDefaults.standard.data(forKey: huntsKey),
           let saved = try? JSONDecoder().decode([Hunt].self, from: data) {
            hunts = saved
        }
    }

    private func saveMacros() {
        if let data = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(data, forKey: macrosKey)
        }
    }

    private func loadMacros() {
        if let data = UserDefaults.standard.data(forKey: macrosKey),
           let saved = try? JSONDecoder().decode([Macro].self, from: data) {
            macros = saved
        }
    }

    private func saveCollection() {
        if let data = try? JSONEncoder().encode(collection) {
            UserDefaults.standard.set(data, forKey: collectionKey)
        }
    }

    private func loadCollection() {
        if let data = UserDefaults.standard.data(forKey: collectionKey),
           let saved = try? JSONDecoder().decode([CapturedPokemon].self, from: data) {
            collection = saved
        }
    }
}
