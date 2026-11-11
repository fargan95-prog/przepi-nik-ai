import SwiftUI
import AVFoundation
import UIKit

struct RecipeHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sharedItems: [String] = []
    @State private var savedRecipes: [RecipeImportResponse] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Wszystkie"
    @State private var showImport = false
    private let green = Color(red: 0.19, green: 0.29, blue: 0.23)
    private let groupID = "group.com.fargan95.przepisnikai"

    private var categories: [String] {
        ["Wszystkie"] + Array(Set(savedRecipes.map { $0.category }.filter { !$0.isEmpty })).sorted()
    }

    private var filteredRecipes: [RecipeImportResponse] {
        savedRecipes.filter { recipe in
            let matchesCategory = selectedCategory == "Wszystkie" || recipe.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || recipe.name.localizedCaseInsensitiveContains(query) ||
                recipe.ingredients.contains { $0.name.localizedCaseInsensitiveContains(query) } ||
                recipe.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRYWATNA KSIĄŻKA KUCHARSKA")
                            .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                        Text("Przepiśnik")
                            .font(.system(size: 36, weight: .bold, design: .serif)).foregroundStyle(green)
                        Text("Twoje przepisy, zebrane w jednym miejscu.")
                            .foregroundStyle(.secondary)
                        Button { loadShare(); showImport = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.down").font(.title2)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Importuj z Instagrama").font(.headline)
                                    Text("Udostępnij rolkę, post lub zdjęcie").font(.caption)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundStyle(.white).padding(16)
                            .background(green, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color(red: 0.97, green: 0.96, blue: 0.93))
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                Button { selectedCategory = category } label: {
                                    Text(category)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 13).padding(.vertical, 8)
                                        .background(selectedCategory == category ? green : Color(.secondarySystemBackground),
                                                    in: Capsule())
                                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 4)
                    }
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: searchText.isEmpty ? "book.closed" : "magnifyingglass")
                                .font(.system(size: 34)).foregroundStyle(green.opacity(0.65))
                            Text(searchText.isEmpty ? "Biblioteka jest pusta" : "Brak wyników")
                                .font(.headline)
                            Text(searchText.isEmpty
                                ? "Dodaj przepis ręcznie lub zaimportuj go z Instagrama."
                                : "Zmień wyszukiwaną frazę lub kategorię.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, onSave: updateRecipe)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recipe.name).font(.headline).foregroundStyle(.primary)
                                    Text([recipe.category, recipe.servings.map { "\($0) por." }, recipe.prepMinutes.map { "\($0) min" }]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if recipe.needsReview {
                                        Label("Do sprawdzenia", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption2).foregroundStyle(.orange)
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteRecipes)
                    }
                } header: {
                    HStack {
                        Text("Moja biblioteka")
                        Spacer()
                        Text("\(filteredRecipes.count) przepisów").textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .searchable(text: $searchText, prompt: "Szukaj przepisu lub składnika")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { loadShare(); showImport = true } label: {
                            Label("Importuj z udostępnienia", systemImage: "square.and.arrow.down")
                        }
                        Button(action: addBlankRecipe) {
                            Label("Dodaj ręcznie", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(green)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton().disabled(savedRecipes.isEmpty)
                }
            }
            .sheet(isPresented: $showImport, onDismiss: { loadSaved(); loadShare() }) {
                ShareImportView(items: sharedItems)
            }
            .onAppear {
                loadShare()
                loadSaved()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    loadShare()
                    loadSaved()
                }
            }
        }
    }

    private func loadShare() {
        let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("ShareInbox/latest-share.json")
        guard let inbox, let data = try? Data(contentsOf: inbox),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [String] else {
            sharedItems = []
            return
        }
        sharedItems = items
    }

    private func clearShareInbox() {
        guard let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("ShareInbox", isDirectory: true) else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent == "latest-share.json" || file.lastPathComponent.hasPrefix("shared-") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func loadSaved() {
        let defaults = UserDefaults(suiteName: groupID)
        let stored = defaults?.array(forKey: "savedRecipes") as? [Data] ?? []
        savedRecipes = stored.compactMap { try? JSONDecoder().decode(RecipeImportResponse.self, from: $0) }
    }

    private func addBlankRecipe() {
        let recipe = RecipeImportResponse(name: "Nowy przepis")
        savedRecipes.insert(recipe, at: 0)
        persistRecipes()
    }

    private func deleteRecipes(at offsets: IndexSet) {
        let ids = offsets.map { filteredRecipes[$0].id }
        savedRecipes.removeAll { ids.contains($0.id) }
        persistRecipes()
    }

    private func updateRecipe(_ updated: RecipeImportResponse, originalID: String) {
        if let index = savedRecipes.firstIndex(where: { $0.id == originalID }) {
            savedRecipes[index] = updated
            persistRecipes()
        }
    }

    private func persistRecipes() {
        let stored = savedRecipes.compactMap { try? JSONEncoder().encode($0) }
        UserDefaults(suiteName: groupID)?.set(stored, forKey: "savedRecipes")
    }
}

struct RecipeDetailView: View {
    @State private var recipe: RecipeImportResponse
    @State private var showEditor = false
    let onSave: (RecipeImportResponse, String) -> Void
    @State private var originalID: String
    private let green = Color(red: 0.19, green: 0.29, blue: 0.23)

    init(recipe: RecipeImportResponse, onSave: @escaping (RecipeImportResponse, String) -> Void) {
        _recipe = State(initialValue: recipe)
        _originalID = State(initialValue: recipe.id)
        self.onSave = onSave
    }

    private var shareText: String {
        var lines = [recipe.name, recipe.description, "Składniki:"]
        lines += recipe.ingredients.map { ingredient in
            "- \(ingredient.name): \([ingredient.amount, ingredient.unit].compactMap { $0 }.joined(separator: " "))"
        }
        lines.append("Przygotowanie:")
        lines += recipe.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        if let servings = recipe.servings { lines.append("Porcje: \(servings)") }
        if let prep = recipe.prepMinutes { lines.append("Przygotowanie: \(prep) min") }
        if let cook = recipe.cookMinutes { lines.append("Gotowanie: \(cook) min") }
        if let source = recipe.sourceURL { lines.append("Źródło: \(source)") }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                Text(recipe.description).foregroundStyle(.secondary)
                LabeledContent("Kategoria", value: recipe.category)
                if let servings = recipe.servings { LabeledContent("Porcje", value: String(servings)) }
                if let prep = recipe.prepMinutes { LabeledContent("Przygotowanie", value: "\(prep) min") }
                if let cook = recipe.cookMinutes { LabeledContent("Gotowanie", value: "\(cook) min") }
            }
            Section("Składniki") {
                ForEach(recipe.ingredients) { ingredient in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name).font(.body)
                        Text([ingredient.amount ?? "Ilość niepodana", ingredient.unit ?? "", ingredient.note]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 2)
                }
            }
            Section("Przygotowanie") {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)").font(.headline).foregroundStyle(green)
                            .frame(width: 25, height: 25).background(green.opacity(0.1), in: Circle())
                        Text(step)
                    }.padding(.vertical, 4)
                }
            }
            if !recipe.tags.isEmpty {
                Section("Tagi") { Text(recipe.tags.joined(separator: " · ")).foregroundStyle(.secondary) }
            }
            if recipe.needsReview || !recipe.uncertainties.isEmpty {
                Section("Do weryfikacji") {
                    Label("Ten przepis zawiera niepewne lub brakujące informacje.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    ForEach(recipe.uncertainties, id: \.self) { Text($0) }
                }
            }
            if let source = recipe.sourceURL, let url = URL(string: source) {
                Section("Źródło") { Link("Otwórz oryginalny post", destination: url) }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edytuj") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            RecipeEditorView(recipe: recipe) { updated in
                recipe = updated
                onSave(updated, originalID)
                originalID = updated.id
            }
        }
    }
}

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipe: RecipeImportResponse
    let onSave: (RecipeImportResponse) -> Void

    init(recipe: RecipeImportResponse, onSave: @escaping (RecipeImportResponse) -> Void) {
        _recipe = State(initialValue: recipe)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Podstawowe informacje") {
                    TextField("Nazwa przepisu", text: $recipe.name)
                    TextField("Opis", text: $recipe.description, axis: .vertical)
                    TextField("Kategoria", text: $recipe.category)
                    TextField("Podkategoria", text: $recipe.subcategory)
                    TextField("Tagi (oddziel przecinkami)", text: Binding(
                        get: { recipe.tags.joined(separator: ", ") },
                        set: { recipe.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                }
                Section("Składniki") {
                    ForEach($recipe.ingredients) { $ingredient in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Składnik", text: $ingredient.name)
                            HStack {
                                TextField("Ilość", text: Binding(
                                    get: { ingredient.amount ?? "" },
                                    set: { ingredient.amount = $0.isEmpty ? nil : $0 }
                                ))
                                TextField("Jednostka", text: Binding(
                                    get: { ingredient.unit ?? "" },
                                    set: { ingredient.unit = $0.isEmpty ? nil : $0 }
                                ))
                            }
                            TextField("Uwagi", text: $ingredient.note)
                        }
                    }
                    .onDelete { recipe.ingredients.remove(atOffsets: $0) }
                    Button {
                        recipe.ingredients.append(.init(name: "", amount: nil, unit: nil, note: ""))
                    } label: { Label("Dodaj składnik", systemImage: "plus") }
                }
                Section("Przygotowanie") {
                    ForEach(recipe.steps.indices, id: \.self) { index in
                        TextField("Krok \(index + 1)", text: $recipe.steps[index], axis: .vertical)
                    }
                    .onDelete { recipe.steps.remove(atOffsets: $0) }
                    Button { recipe.steps.append("") } label: { Label("Dodaj krok", systemImage: "plus") }
                }
                Section("Porcje i czas") {
                    TextField("Liczba porcji", text: Binding(
                        get: { recipe.servings.map(String.init) ?? "" },
                        set: { recipe.servings = Int($0) }
                    )).keyboardType(.numberPad)
                    TextField("Czas przygotowania (min)", text: Binding(
                        get: { recipe.prepMinutes.map(String.init) ?? "" },
                        set: { recipe.prepMinutes = Int($0) }
                    )).keyboardType(.numberPad)
                    TextField("Czas gotowania (min)", text: Binding(
                        get: { recipe.cookMinutes.map(String.init) ?? "" },
                        set: { recipe.cookMinutes = Int($0) }
                    )).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edytuj przepis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { onSave(recipe); dismiss() }
                }
            }
        }
    }
}

struct RecipeImportResponse: Codable, Identifiable {
    struct Ingredient: Codable, Identifiable {
        var name: String; var amount: String?; var unit: String?; var note: String
        var id: String { name + (amount ?? "") }
    }
    var isRecipe: Bool; var name: String; var description: String
    var category: String; var subcategory: String; var servings: Int?
    var prepMinutes: Int?; var cookMinutes: Int?
    var ingredients: [Ingredient]; var steps: [String]; var tags: [String]
    var needsReview: Bool; var uncertainties: [String]
    var sourceURL: String? = nil
    var id: String { (sourceURL ?? "") + name }

    init(name: String = "Nowy przepis") {
        self.isRecipe = true
        self.name = name
        self.description = ""
        self.category = "Inne"
        self.subcategory = ""
        self.servings = nil
        self.prepMinutes = nil
        self.cookMinutes = nil
        self.ingredients = []
        self.steps = []
        self.tags = []
        self.needsReview = true
        self.uncertainties = ["Uzupełnij składniki i sposób przygotowania."]
        self.sourceURL = nil
    }
}
struct ImportEnvelope: Decodable { let ok: Bool; let recipe: RecipeImportResponse?; let error: String?; let sourceURL: String? }

struct ShareImportView: View {
    let items: [String]
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var recipe: RecipeImportResponse?
    @State private var savedMessage: String?
    private let groupID = "group.com.fargan95.przepisnikai"
    private let endpoint = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Otrzymany materiał") {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in Text(item).textSelection(.enabled) }
                }
                Section("Analiza AI") {
                    TextField("Dodatkowa notatka (opcjonalnie)", text: $note, axis: .vertical)
                    Text("Udostępnione zdjęcia, tekst i dźwięk zostaną wysłane do usługi AI w celu przygotowania przepisu. Zapisane przepisy pozostają w bibliotece na tym urządzeniu.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        Task { await importRecipe() }
                    } label: {
                        HStack { if isLoading { ProgressView() }; Text(isLoading ? "Analizuję…" : "Utwórz przepis z AI") }
                    }.disabled(isLoading || endpoint.isEmpty)
                    if endpoint.isEmpty { Text("Backend nie jest jeszcze podłączony.").foregroundStyle(.secondary) }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                if let savedMessage { Section { Label(savedMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green) } }
                if let recipe {
                    if !recipe.isRecipe {
                        Section("Potrzebujemy jeszcze materiału") {
                            Label("Otrzymaliśmy link, ale nie zawartość rolki.", systemImage: "link").foregroundStyle(.orange)
                            Text("Instagram nie przekazał filmu ani opisu przepisu. Nie będziemy zgadywać składników.")
                            if let source = recipe.sourceURL, let url = URL(string: source) {
                                Link("Otwórz oryginalny post na Instagramie", destination: url)
                            }
                            Text("Udostępnij ponownie zrzuty ekranu z listą składników i przygotowaniem albo wklej opis posta w polu notatki.")
                        }
                    } else {
                        Section(recipe.name) {
                            Text(recipe.description)
                            LabeledContent("Kategoria", value: recipe.category)
                            if let servings = recipe.servings { LabeledContent("Porcje", value: String(servings)) }
                            ForEach(recipe.ingredients) { ingredient in
                                Text([ingredient.name, ingredient.amount ?? "nie podano", ingredient.unit ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                            }
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in Text("\(index + 1). \(step)") }
                            if recipe.needsReview {
                                Label("Wymaga sprawdzenia", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                ForEach(recipe.uncertainties, id: \.self) { Text($0) }
                            }
                            if let source = recipe.sourceURL, let url = URL(string: source) {
                                Link("Oryginalne źródło", destination: url)
                            }
                        }
                    }
                }
            }.navigationTitle("Import przepisu")
        }
    }

    private func extractVideoFrames(from videoURL: URL) -> [Data] {
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        return [0.12, 0.35, 0.58, 0.82].compactMap { fraction in
            let time = CMTime(seconds: duration * fraction, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
            return UIImage(cgImage: image).jpegData(compressionQuality: 0.78)
        }
    }

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        guard !asset.tracks(withMediaType: .audio).isEmpty,
              let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "RecipeImport", code: 10, userInfo: [NSLocalizedDescriptionKey: "Wideo nie zawiera ścieżki audio."])
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        exporter.outputURL = output
        exporter.outputFileType = .m4a
        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously { continuation.resume() }
        }
        guard exporter.status == .completed else {
            try? FileManager.default.removeItem(at: output)
            throw exporter.error ?? NSError(domain: "RecipeImport", code: 11, userInfo: [NSLocalizedDescriptionKey: "Nie udało się wyodrębnić dźwięku z filmu."])
        }
        return output
    }

    @MainActor private func importRecipe() async {
        guard let base = URL(string: endpoint), let url = URL(string: "/v1/recipes/import", relativeTo: base) else { errorMessage = "Nieprawidłowy adres backendu."; return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        let sourceURL = items.first(where: { value in
            guard let url = URL(string: value), let host = url.host?.lowercased() else { return false }
            return host == "instagram.com" || host.hasSuffix(".instagram.com")
        })
        let nonURLText = items.filter { $0 != sourceURL && !$0.hasPrefix("shared-") }
        field("text", (nonURLText.joined(separator: "\n") + "\n" + note).trimmingCharacters(in: .whitespacesAndNewlines))
        if let sourceURL { field("sourceURL", sourceURL) }
        if let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("ShareInbox") {
            let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("shared-") {
                guard let data = try? Data(contentsOf: file), data.count <= 24 * 1024 * 1024 else { continue }
                var uploadData = data
                var uploadName = file.lastPathComponent
                var mime = file.pathExtension.lowercased() == "jpg" || file.pathExtension.lowercased() == "jpeg" ? "image/jpeg" :
                    file.pathExtension.lowercased() == "png" ? "image/png" :
                    ["heic", "heif"].contains(file.pathExtension.lowercased()) ? "image/heic" :
                    file.pathExtension.lowercased() == "webp" ? "image/webp" :
                    file.pathExtension.lowercased() == "mp4" ? "video/mp4" :
                    file.pathExtension.lowercased() == "mov" ? "video/quicktime" : "application/octet-stream"
                if mime == "image/heic", let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) {
                    uploadData = jpeg
                    uploadName = file.deletingPathExtension().lastPathComponent + ".jpg"
                    mime = "image/jpeg"
                }
                if mime.hasPrefix("video/"), let audioURL = try? await extractAudio(from: file),
                   let audioData = try? Data(contentsOf: audioURL) {
                    uploadData = audioData
                    uploadName = file.deletingPathExtension().lastPathComponent + ".m4a"
                    mime = "audio/mp4"
                    try? FileManager.default.removeItem(at: audioURL)
                }
                body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"files\"; filename=\"\(uploadName)\"\r\nContent-Type: \(mime)\r\n\r\n".utf8))
                body.append(uploadData); body.append(Data("\r\n".utf8))
                if file.pathExtension.lowercased() == "mp4" || file.pathExtension.lowercased() == "mov" {
                    let frames = extractVideoFrames(from: file)
                    for (frameIndex, frame) in frames.enumerated() {
                        let frameName = "reel-frame-\(frameIndex + 1).jpg"
                        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"files\"; filename=\"\(frameName)\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
                        body.append(frame)
                        body.append(Data("\r\n".utf8))
                    }
                }
            }
        }
        body.append(Data("--\(boundary)--\r\n".utf8)); request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let server = try? JSONDecoder().decode(ImportEnvelope.self, from: data)
                throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: server?.error ?? "Serwer zwrócił błąd."])
            }
            let result = try JSONDecoder().decode(ImportEnvelope.self, from: data)
            guard result.ok, var parsed = result.recipe else { throw NSError(domain: "Import", code: 2, userInfo: [NSLocalizedDescriptionKey: "Materiał nie zawiera rozpoznawalnego przepisu."]) }
            parsed.sourceURL = result.sourceURL ?? sourceURL
            recipe = parsed
            clearShareInbox()
            guard parsed.isRecipe else { return }
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(parsed) {
                let defaults = UserDefaults(suiteName: groupID)
                var saved = defaults?.array(forKey: "savedRecipes") as? [Data] ?? []
                if let source = parsed.sourceURL, !source.isEmpty {
                    saved.removeAll { storedData in
                        guard let existing = try? JSONDecoder().decode(RecipeImportResponse.self, from: storedData) else { return false }
                        return existing.sourceURL == source
                    }
                }
                saved.insert(data, at: 0)
                defaults?.set(Array(saved.prefix(500)), forKey: "savedRecipes")
                savedMessage = "Przepis zapisany w bibliotece na tym urządzeniu."
            }
        } catch { errorMessage = error.localizedDescription }
    }
}
