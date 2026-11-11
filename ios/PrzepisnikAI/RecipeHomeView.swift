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

struct ShareImportView: View {
    let items: [String]
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Otrzymany materiał") {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in Text(item).textSelection(.enabled) }
                }
                Section("Dalszy krok") {
                    Text("Udostępniony materiał został odebrany. Następny etap połączy go z analizą AI i utworzy kartę przepisu.")
                    TextField("Dodatkowa notatka (opcjonalnie)", text: $note, axis: .vertical)
                }
            }.navigationTitle("Import przepisu")
        }
    }
}
