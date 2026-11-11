import SwiftUI

struct RecipeHomeView: View {
    @State private var sharedItems: [String] = []
    @State private var showImport = false
    private let green = Color(red: 0.19, green: 0.29, blue: 0.23)
    private let groupID = "group.com.fargan95.przepisnikai"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.93).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PRYWATNA KSIĄŻKA KUCHARSKA").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                        Text("Przepiśnik").font(.system(size: 36, weight: .bold, design: .serif)).foregroundStyle(green)
                        Text("Twoje przepisy, zebrane w jednym miejscu.").foregroundStyle(.secondary)
                    }
                    Button { loadShare(); showImport = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "square.and.arrow.down").font(.title2)
                            VStack(alignment: .leading) {
                                Text("Importuj z Instagrama").font(.headline)
                                Text("Udostępnij rolkę lub post do Przepiśnika").font(.caption)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }.foregroundStyle(.white).padding(18).background(green, in: RoundedRectangle(cornerRadius: 20))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ostatnio udostępnione").font(.title3.bold())
                        if sharedItems.isEmpty {
                            ContentUnavailableView("Brak materiałów", systemImage: "square.and.arrow.up", description: Text("W Instagramie wybierz Udostępnij, a następnie Przepiśnik AI."))
                        } else {
                            ForEach(Array(sharedItems.enumerated()), id: \.offset) { _, item in
                                Text(item).font(.subheadline).lineLimit(3).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    Spacer()
                }.padding(22)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { loadShare(); showImport = true } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(green) } } }
            .sheet(isPresented: $showImport) { ShareImportView(items: sharedItems) }
            .onAppear(perform: loadShare)
        }
    }

    private func loadShare() {
        let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("ShareInbox/latest-share.json")
        guard let inbox, let data = try? Data(contentsOf: inbox),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [String] else { return }
        sharedItems = items
    }
}

struct RecipeImportResponse: Decodable {
    struct Ingredient: Decodable, Identifiable {
        var name: String; var amount: String?; var unit: String?; var note: String
        var id: String { name + (amount ?? "") }
    }
    var isRecipe: Bool; var name: String; var description: String
    var category: String; var subcategory: String; var servings: Int?
    var prepMinutes: Int?; var cookMinutes: Int?
    var ingredients: [Ingredient]; var steps: [String]; var tags: [String]
    var needsReview: Bool; var uncertainties: [String]
}
struct ImportEnvelope: Decodable { let ok: Bool; let recipe: RecipeImportResponse?; let error: String? }

struct ShareImportView: View {
    let items: [String]
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var recipe: RecipeImportResponse?
    private let groupID = "group.com.fargan95.przepisnikai"
    private let endpoint = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Otrzymany materiał") {
                    ForEach(Array(items.enumerated()), id: \\.offset) { _, item in Text(item).textSelection(.enabled) }
                }
                Section("Analiza AI") {
                    TextField("Dodatkowa notatka (opcjonalnie)", text: $note, axis: .vertical)
                    Button {
                        Task { await importRecipe() }
                    } label: {
                        HStack { if isLoading { ProgressView() }; Text(isLoading ? "Analizuję…" : "Utwórz przepis z AI") }
                    }.disabled(isLoading || endpoint.isEmpty)
                    if endpoint.isEmpty { Text("Backend nie jest jeszcze podłączony.").foregroundStyle(.secondary) }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                if let recipe {
                    Section(recipe.name) {
                        Text(recipe.description)
                        LabeledContent("Kategoria", value: recipe.category)
                        if let servings = recipe.servings { LabeledContent("Porcje", value: String(servings)) }
                        ForEach(recipe.ingredients) { ingredient in
                            Text([ingredient.name, ingredient.amount ?? "nie podano", ingredient.unit ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        }
                        ForEach(Array(recipe.steps.enumerated()), id: \\.offset) { index, step in Text("\\(index + 1). \\(step)") }
                        if recipe.needsReview {
                            Label("Wymaga sprawdzenia", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            ForEach(recipe.uncertainties, id: \\.self) { Text($0) }
                        }
                    }
                }
            }.navigationTitle("Import przepisu")
        }
    }

    @MainActor private func importRecipe() async {
        guard let base = URL(string: endpoint), let url = URL(string: "/v1/recipes/import", relativeTo: base) else { errorMessage = "Nieprawidłowy adres backendu."; return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        let boundary = "Boundary-\\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\\(boundary)\\r\\nContent-Disposition: form-data; name=\\"\\(name)\\"\\r\\n\\r\\n\\(value)\\r\\n".utf8))
        }
        field("text", (items.joined(separator: "\\n") + "\\n" + note).trimmingCharacters(in: .whitespacesAndNewlines))
        if let inbox = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("ShareInbox") {
            let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("shared-") {
                guard let data = try? Data(contentsOf: file), data.count <= 24 * 1024 * 1024 else { continue }
                let mime = file.pathExtension.lowercased() == "jpg" || file.pathExtension.lowercased() == "jpeg" ? "image/jpeg" :
                    file.pathExtension.lowercased() == "png" ? "image/png" :
                    file.pathExtension.lowercased() == "mp4" ? "video/mp4" :
                    file.pathExtension.lowercased() == "mov" ? "video/quicktime" : "application/octet-stream"
                body.append(Data("--\\(boundary)\\r\\nContent-Disposition: form-data; name=\\"files\\"; filename=\\"\\(file.lastPathComponent)\\"\\r\\nContent-Type: \\(mime)\\r\\n\\r\\n".utf8))
                body.append(data); body.append(Data("\\r\\n".utf8))
            }
        }
        body.append(Data("--\\(boundary)--\\r\\n".utf8)); request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let server = try? JSONDecoder().decode(ImportEnvelope.self, from: data)
                throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: server?.error ?? "Serwer zwrócił błąd."])
            }
            let result = try JSONDecoder().decode(ImportEnvelope.self, from: data)
            guard result.ok, let parsed = result.recipe else { throw NSError(domain: "Import", code: 2, userInfo: [NSLocalizedDescriptionKey: "Materiał nie zawiera rozpoznawalnego przepisu."]) }
            recipe = parsed
        } catch { errorMessage = error.localizedDescription }
    }
}
