import SwiftUI
import AppKit

// MARK: - NSEvent key recorder

class KeyRecorder: ObservableObject {
    @Published var capturedKey: String = ""
    @Published var isRecording: Bool = false
    private var monitor: Any?

    func startRecording() {
        isRecording = true
        capturedKey = ""
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            let modifierOnly: [UInt16] = [54,55,56,57,58,59,60,61,62,63]
            guard !modifierOnly.contains(event.keyCode) else { return event }
            let chars = event.charactersIgnoringModifiers ?? ""
            if !chars.isEmpty {
                DispatchQueue.main.async {
                    self.capturedKey = chars.uppercased()
                    self.isRecording = false
                    self.stopMonitor()
                }
            }
            return nil
        }
    }

    func stopRecording() { isRecording = false; stopMonitor() }

    private func stopMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Global key handler

class GlobalKeyHandler {
    private var monitor: Any?

    func start(appState: AppState) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let r = NSApp.keyWindow?.firstResponder, r is NSTextView { return event }
            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return event }
            let chars = (event.charactersIgnoringModifiers ?? "").uppercased()
            guard !chars.isEmpty, let id = appState.selectedHuntID else { return event }
            if let macro = appState.macros.first(where: { $0.keyLabel.uppercased() == chars }) {
                DispatchQueue.main.async { appState.executeMacro(macro, on: id) }
                return nil
            }
            return event
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Sprite view

struct SpriteView: View {
    let spriteURL: String
    @State private var image: NSImage? = nil
    @State private var lastURL: String = ""

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else if !spriteURL.isEmpty {
                ProgressView()
            }
        }
        .onAppear { loadImage() }
        .onChange(of: spriteURL) { loadImage() }
    }

    func loadImage() {
        guard !spriteURL.isEmpty, spriteURL != lastURL else { return }
        lastURL = spriteURL
        image = nil
        guard let url = URL(string: spriteURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let img = NSImage(data: data) {
                DispatchQueue.main.async { self.image = img }
            }
        }.resume()
    }
}

// MARK: - Root view

enum SidebarSelection: Hashable {
    case hunt(UUID)
    case collection
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var sidebarSelection: SidebarSelection? = nil
    private let keyHandler = GlobalKeyHandler()

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState, selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            switch sidebarSelection {
            case .hunt(let id):
                if let hunt = appState.hunts.first(where: { $0.id == id }) {
                    HuntDetailView(appState: appState, hunt: hunt)
                } else {
                    placeholderView
                }
            case .collection:
                CollectionView(appState: appState)
            case nil:
                placeholderView
            }
        }
        .preferredColorScheme(appState.colorScheme)
        .onAppear {
            keyHandler.start(appState: appState)
            if let first = appState.hunts.first {
                sidebarSelection = .hunt(first.id)
                appState.selectedHuntID = first.id
            }
        }
        .onDisappear { keyHandler.stop() }
        .onChange(of: sidebarSelection) {
            if case .hunt(let id) = sidebarSelection {
                appState.selectedHuntID = id
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { appState.addHunt() } label: {
                    Image(systemName: "plus")
                }
                .help("Nuevo contador")

                Button { appState.showMacros = true } label: {
                    Image(systemName: "gearshape")
                }
                .help("Macros globales")
                .sheet(isPresented: $appState.showMacros) {
                    MacrosSheet(appState: appState)
                }

            }
        }
    }

    var placeholderView: some View {
        Text("Selecciona o crea un contador")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var appState: AppState
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Section("HUNTS ACTIVOS") {
                ForEach(appState.hunts) { hunt in
                    HuntRow(hunt: hunt)
                        .tag(SidebarSelection.hunt(hunt.id))
                        .contextMenu {
                            Button(role: .destructive) {
                                appState.deleteHunt(id: hunt.id)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
            }

            Section("BIBLIOTECA") {
                Label("Colección", systemImage: "star.fill")
                    .tag(SidebarSelection.collection)
                    .foregroundStyle(.yellow)
            }
        }
        .listStyle(.sidebar)
    }
}

struct HuntRow: View {
    let hunt: Hunt

    var body: some View {
        HStack(spacing: 10) {
            if !hunt.pokemonID.description.isEmpty && hunt.pokemonID > 0 {
                SpriteView(spriteURL: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/\(hunt.pokemonID).png")
                    .frame(width: 40, height: 40)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(hunt.pokemonName.isEmpty ? "Sin nombre" : hunt.pokemonName.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("\(hunt.count) encuentros")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hunt Detail

struct HuntDetailView: View {
    @ObservedObject var appState: AppState
    let hunt: Hunt

    @State private var selectedTab = 0
    @State private var showPicker = false
    @State private var showEditCount = false
    @State private var toastMessage: String? = nil

    var currentHunt: Hunt {
        appState.hunts.first { $0.id == hunt.id } ?? hunt
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sprite
            if currentHunt.pokemonID > 0 {
                SpriteView(spriteURL: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/\(currentHunt.pokemonID).png")
                    .frame(height: 286)
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
            }

            // Counter
            VStack(spacing: 12) {
                Text("\(currentHunt.count)")
                    .font(.system(size: 104, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2), value: currentHunt.count)

                HStack(spacing: 13) {
                    Button { appState.decrement(id: hunt.id) } label: {
                        Label("Restar", systemImage: "minus").frame(minWidth: 117)
                    }
                    .controlSize(.large)

                    Button { appState.increment(id: hunt.id) } label: {
                        Label("Sumar", systemImage: "plus").frame(minWidth: 117)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }

                Button { showEditCount = true } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .sheet(isPresented: $showEditCount) {
                    EditCountSheet(
                        currentCount: currentHunt.count,
                        onSave: { val in
                            var updated = currentHunt
                            updated.count = val
                            appState.updateHunt(updated)
                            showEditCount = false
                        },
                        onReset: {
                            appState.reset(id: hunt.id)
                            showEditCount = false
                        },
                        onCaptured: {
                            appState.captureHunt(id: hunt.id)
                            showEditCount = false
                        },
                        onCancel: { showEditCount = false }
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))


        }
        .overlay(toastOverlay)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
Button { showPicker = true } label: {
                    Label(currentHunt.pokemonName.isEmpty ? "Pokémon" : currentHunt.pokemonName.capitalized,
                          systemImage: "sparkles")
                }
                .help("Seleccionar Pokémon")
                .popover(isPresented: $showPicker) {
                    PokemonPicker { name, id in
                        var updated = currentHunt
                        updated.pokemonName = name
                        updated.pokemonID   = id
                        appState.updateHunt(updated)
                        showPicker = false
                    }
                }

                if currentHunt.pokemonID > 0 {
                    Button {
                        var updated = currentHunt
                        updated.pokemonName = ""
                        updated.pokemonID   = 0
                        appState.updateHunt(updated)
                    } label: { Image(systemName: "xmark.circle") }
                    .help("Quitar Pokémon")
                }

                Divider()

                Button { appState.importFile(for: hunt.id) } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Importar .txt")

                Button { appState.chooseSaveFile(for: hunt.id) } label: {
                    Image(systemName: "doc.text")
                }
                .help("Guardar en…")

            }
        }
    }

    func showToast(_ msg: String?) {
        guard let msg = msg else { return }
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toastMessage = nil }
    }

    var toastOverlay: some View {
        VStack {
            Spacer()
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: toastMessage)
    }
}

// MARK: - Macros Tab

struct MacrosTab: View {
    @ObservedObject var appState: AppState
    let huntID: UUID
    var toast: (String?) -> Void
    @State private var showAddForm = false
    @State private var editingMacro: Macro? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("MACROS GLOBALES — clic o pulsa la tecla asignada")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                if appState.macros.isEmpty {
                    Text("Sin macros. Crea una abajo.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(appState.macros) { macro in
                        MacroCard(macro: macro) {
                            appState.executeMacro(macro, on: huntID)
                            toast("\(macro.name) ejecutada")
                        } onEdit: {
                            editingMacro = macro
                        } onDelete: {
                            appState.deleteMacro(id: macro.id)
                            toast("Macro eliminada")
                        }
                    }
                }
                .padding(.horizontal, 16)

                if showAddForm {
                    MacroForm(title: "Nueva macro") { name, value, key in
                        appState.addMacro(name: name, value: value, keyLabel: key)
                        showAddForm = false
                        toast("Macro guardada")
                    } onCancel: { showAddForm = false }
                    .padding(.horizontal, 16)
                } else {
                    Button { showAddForm = true } label: {
                        Label("Nueva macro", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
            }
            .padding(.top, 12)
        }
        .sheet(item: $editingMacro) { macro in
            MacroEditSheet(macro: macro) { name, value, key in
                appState.updateMacro(id: macro.id, name: name, value: value, keyLabel: key)
                toast("Macro actualizada")
            }
        }
    }
}

// MARK: - Hunt Config Tab

struct HuntConfigTab: View {
    @ObservedObject var appState: AppState
    let hunt: Hunt
    @Binding var showPicker: Bool
    var toast: (String?) -> Void
    @State private var editName = ""
    @State private var editCount = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("NOMBRE DEL HUNT").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                HStack {
                    TextField("Nombre", text: $editName).textFieldStyle(.roundedBorder)
                        .onAppear { editName = hunt.pokemonName }
                    Button("Aplicar") {
                        var updated = hunt
                        updated.pokemonName = editName
                        appState.updateHunt(updated)
                        toast("Nombre actualizado")
                    }
                }

                Divider()

                Text("FIJAR CONTADOR").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                HStack {
                    TextField("Valor", text: $editCount).textFieldStyle(.roundedBorder)
                    Button("Aplicar") {
                        guard let v = Int(editCount) else { return }
                        var updated = hunt
                        updated.count = v
                        appState.updateHunt(updated)
                        toast("Contador fijado a \(v)")
                    }
                }

                Divider()

                Text("POKÉMON").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Button { showPicker = true } label: {
                    Label("Cambiar Pokémon", systemImage: "sparkles").frame(maxWidth: .infinity)
                }

                Divider()

                Text("ARCHIVO .TXT").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Button { appState.chooseSaveFile(for: hunt.id) } label: {
                    Label("Elegir archivo", systemImage: "folder").frame(maxWidth: .infinity)
                }
                Button { appState.importFile(for: hunt.id) } label: {
                    Label("Importar .txt", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }
                Text(hunt.saveFilePath.isEmpty ? "Sin archivo asignado" : hunt.saveFilePath)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(2)

                Divider()

                Text("ZONA DE PELIGRO").font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
                Button(role: .destructive) {
                    appState.deleteAllMacros(); toast("Todas las macros eliminadas")
                } label: {
                    Label("Eliminar todas las macros", systemImage: "trash").frame(maxWidth: .infinity)
                }
                Button(role: .destructive) {
                    appState.deleteHunt(id: hunt.id)
                } label: {
                    Label("Eliminar este hunt", systemImage: "xmark.circle").frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Macro Card

struct MacroCard: View {
    let macro: Macro
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(macro.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(macro.value >= 0 ? "+\(macro.value)" : "\(macro.value)")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(macro.keyLabel.isEmpty ? "—" : macro.keyLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                    HStack(spacing: 4) {
                        Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 10)) }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                        Button(action: onDelete) { Image(systemName: "xmark").font(.system(size: 10)) }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Key Capture Button

struct KeyCaptureButton: View {
    @Binding var keyLabel: String
    @StateObject private var recorder = KeyRecorder()

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if recorder.isRecording { recorder.stopRecording() }
                else { recorder.startRecording() }
            } label: {
                if recorder.isRecording {
                    Label("Pulsa cualquier tecla…", systemImage: "record.circle").foregroundStyle(.red)
                } else {
                    Text(keyLabel.isEmpty ? "Grabar tecla" : "Tecla: \(keyLabel)")
                }
            }
            .buttonStyle(.bordered)
            .onChange(of: recorder.capturedKey) {
                if !recorder.capturedKey.isEmpty { keyLabel = recorder.capturedKey }
            }
            if !keyLabel.isEmpty {
                Button("Quitar") { keyLabel = "" }.buttonStyle(.borderless).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Macro Form

struct MacroForm: View {
    let title: String
    var initialName: String = ""
    var initialValue: String = ""
    var initialKey: String = ""
    let onSave: (String, Int, String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var valueStr: String = ""
    @State private var keyLabel: String = ""

    var body: some View {
        GroupBox(label: Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)) {
            VStack(alignment: .leading, spacing: 8) {
                row("Nombre") { TextField("ej. +1", text: $name).textFieldStyle(.roundedBorder) }
                row("Valor")  { TextField("ej. 1", text: $valueStr).textFieldStyle(.roundedBorder) }
                row("Atajo")  { KeyCaptureButton(keyLabel: $keyLabel) }
                HStack {
                    Spacer()
                    Button("Cancelar", action: onCancel)
                    Button("Guardar") {
                        guard !name.isEmpty, let v = Int(valueStr) else { return }
                        onSave(name, v, keyLabel)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || Int(valueStr) == nil)
                }
            }
            .padding(4)
        }
        .onAppear { name = initialName; valueStr = initialValue; keyLabel = initialKey }
        .padding(.bottom, 12)
    }

    func row<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text("\(label):").frame(width: 60, alignment: .trailing)
                .font(.system(size: 13)).foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Macro Edit Sheet

struct MacroEditSheet: View {
    let macro: Macro
    let onSave: (String, Int, String) -> Void
    @State private var name: String = ""
    @State private var valueStr: String = ""
    @State private var keyLabel: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Editar macro").font(.system(size: 16, weight: .medium))
            HStack {
                Text("Nombre:").frame(width: 60, alignment: .trailing)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                TextField("Nombre", text: $name).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Valor:").frame(width: 60, alignment: .trailing)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                TextField("Valor", text: $valueStr).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Atajo:").frame(width: 60, alignment: .trailing)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                KeyCaptureButton(keyLabel: $keyLabel)
            }
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    guard !name.isEmpty, let v = Int(valueStr) else { return }
                    onSave(name, v, keyLabel)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || Int(valueStr) == nil)
            }
        }
        .padding(24).frame(width: 340)
        .onAppear { name = macro.name; valueStr = "\(macro.value)"; keyLabel = macro.keyLabel }
    }
}

// MARK: - Pokemon Picker

struct PokemonEntry: Identifiable {
    let id: Int
    let name: String
    var spriteURL: String {
        "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/\(id).png"
    }
}

struct PokemonPicker: View {
    let onSelect: (String, Int) -> Void
    @State private var query: String = ""
    @State private var allPokemon: [PokemonEntry] = []
    @State private var results: [PokemonEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            Text("Seleccionar Pokémon")
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 16)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar…", text: $query)
                    .textFieldStyle(.plain)
                    .onChange(of: query) { filterResults() }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if isLoading {
                ProgressView("Cargando…").padding(40)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(results.prefix(80)) { entry in
                            Button {
                                onSelect(entry.name, entry.id)
                            } label: {
                                VStack(spacing: 4) {
                                    SpriteView(spriteURL: entry.spriteURL).frame(width: 72, height: 72)
                                    Text(entry.name.capitalized)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary).lineLimit(1)
                                }
                                .padding(6)
                            }
                            .buttonStyle(.plain)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 360, height: 440)
        .onAppear { loadPokemonList() }
    }

    func loadPokemonList() {
        let url = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=1025")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["results"] as? [[String: Any]] else { isLoading = false; return }
                allPokemon = items.compactMap { item in
                    guard let name = item["name"] as? String,
                          let urlStr = item["url"] as? String,
                          let id = Int(urlStr.split(separator: "/").last ?? "") else { return nil }
                    return PokemonEntry(id: id, name: name)
                }
                isLoading = false
                filterResults()
            }
        }.resume()
    }

    func filterResults() {
        results = query.isEmpty ? allPokemon : allPokemon.filter { $0.name.contains(query.lowercased()) }
    }
}

// MARK: - Settings Sheet (ajustes generales)

struct MacrosSheet: View {
    @ObservedObject var appState: AppState
    @State private var showAddForm = false
    @State private var editingMacro: Macro? = nil
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ajustes")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Apariencia").tag(0)
                Text("Macros").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if selectedTab == 0 {
                // Appearance tab
                VStack(alignment: .leading, spacing: 20) {
                    Text("TEMA").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        // System
                        AppearanceOption(label: "Sistema", icon: "circle.lefthalf.filled",
                            selected: appState.colorScheme == nil) {
                            appState.colorScheme = nil
                        }
                        // Light
                        AppearanceOption(label: "Claro", icon: "sun.max",
                            selected: appState.colorScheme == .light) {
                            appState.colorScheme = .light
                        }
                        // Dark
                        AppearanceOption(label: "Oscuro", icon: "moon",
                            selected: appState.colorScheme == .dark) {
                            appState.colorScheme = .dark
                        }
                    }

                    Divider()

                    Text("ACTUALIZACIONES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Versión actual: 0.8")
                                .font(.system(size: 13, weight: .medium))
                            Text("Se comprueba automáticamente al arrancar")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Buscar ahora") {
                            UpdateChecker.checkForUpdates(silent: false)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            } else {
                // Macros tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Las macros se aplican al contador activo al pulsar la tecla asignada.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 12)

                        if appState.macros.isEmpty {
                            Text("Sin macros. Crea una abajo.")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(appState.macros) { macro in
                                MacroCard(macro: macro) {
                                    if let id = appState.selectedHuntID {
                                        appState.executeMacro(macro, on: id)
                                    }
                                } onEdit: {
                                    editingMacro = macro
                                } onDelete: {
                                    appState.deleteMacro(id: macro.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        if showAddForm {
                            MacroForm(title: "Nueva macro") { name, value, key in
                                appState.addMacro(name: name, value: value, keyLabel: key)
                                showAddForm = false
                            } onCancel: { showAddForm = false }
                            .padding(.horizontal, 16)
                        } else {
                            Button { showAddForm = true } label: {
                                Label("Nueva macro", systemImage: "plus").frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                    .padding(.top, 4)
                }

                Divider()

                Button(role: .destructive) {
                    appState.deleteAllMacros()
                } label: {
                    Label("Eliminar todas las macros", systemImage: "trash")
                }
                .padding(16)
            }
        }
        .frame(width: 480, height: 520)
        .sheet(item: $editingMacro) { macro in
            MacroEditSheet(macro: macro) { name, value, key in
                appState.updateMacro(id: macro.id, name: name, value: value, keyLabel: key)
            }
        }
    }
}

struct AppearanceOption: View {
    let label: String
    let icon: String
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(selected ? .blue : .secondary)
                Text(label)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Count Sheet

struct EditCountSheet: View {
    let currentCount: Int
    let onSave: (Int) -> Void
    let onReset: () -> Void
    let onCaptured: () -> Void
    let onCancel: () -> Void

    @State private var valueStr: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Editar")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Valor actual: \(currentCount)")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                TextField("Nuevo valor", text: $valueStr)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
            }

            Divider()

            // Captura completada
            Button {
                onCaptured()
            } label: {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.yellow)
                    Text("¡Captura completada! 🎉")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(.yellow)

            Divider()

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onReset()
                } label: {
                    Label("Reiniciar a 0", systemImage: "arrow.counterclockwise")
                }

                Spacer()

                Button("Cancelar", action: onCancel)

                Button("Guardar") {
                    guard let v = Int(valueStr) else { return }
                    onSave(v)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Int(valueStr) == nil)
            }
        }
        .padding(24)
        .frame(width: 340)
        .onAppear { valueStr = "\(currentCount)" }
    }
}

// MARK: - Collection View

struct CollectionView: View {
    @ObservedObject var appState: AppState

    let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            if appState.collection.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow.opacity(0.4))
                    Text("Sin capturas todavía")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Cuando captures un shiny aparecerá aquí.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(appState.collection) { captured in
                            CapturedCard(captured: captured) {
                                appState.deleteCaptured(id: captured.id)
                            } onEdit: { encounters in
                                appState.editCaptured(id: captured.id, encounters: encounters)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Colección")
    }
}

// MARK: - Captured Card

struct CapturedCard: View {
    let captured: CapturedPokemon
    let onDelete: () -> Void
    let onEdit: (Int) -> Void

    @State private var showEditSheet = false
    @State private var editEncounters = ""

    var spriteURL: String {
        "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/\(captured.pokemonID).png"
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: captured.capturedAt)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    SpriteView(spriteURL: spriteURL)
                        .frame(width: 100, height: 100)

                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                        .padding(4)
                }

                Text(captured.pokemonName.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(captured.encounters) encuentros")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)

            // Three dots menu
            Menu {
                Button {
                    editEncounters = "\(captured.encounters)"
                    showEditSheet = true
                } label: {
                    Label("Editar encuentros", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        .sheet(isPresented: $showEditSheet) {
            CollectionEditSheet(
                currentCount: captured.encounters,
                onSave: { val in
                    onEdit(val)
                    showEditSheet = false
                },
                onReset: {
                    onEdit(0)
                    showEditSheet = false
                },
                onCancel: { showEditSheet = false }
            )
        }
    }
}

// MARK: - Collection Edit Sheet (sin botón de captura)

struct CollectionEditSheet: View {
    let currentCount: Int
    let onSave: (Int) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    @State private var valueStr: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Editar encuentros")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Valor actual: \(currentCount)")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                TextField("Nuevo valor", text: $valueStr)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
            }

            Divider()

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onReset()
                } label: {
                    Label("Reiniciar a 0", systemImage: "arrow.counterclockwise")
                }
                Spacer()
                Button("Cancelar", action: onCancel)
                Button("Guardar") {
                    guard let v = Int(valueStr) else { return }
                    onSave(v)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Int(valueStr) == nil)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { valueStr = "\(currentCount)" }
    }
}
