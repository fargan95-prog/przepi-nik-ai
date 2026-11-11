import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let groupID = "group.com.fargan95.przepisnikai"
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusLabel.text = "Przekazuję materiał do Przepiśnika AI…"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        receiveSharedItems()
    }

    private func receiveSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish(error: "Nie otrzymano materiału."); return
        }
        let providers = extensionItems.flatMap { $0.attachments ?? [] }
        let text = extensionItems.compactMap { $0.attributedContentText?.string }.joined(separator: "\n")
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        guard let container else { finish(error: "Brak dostępu do współdzielonego folderu."); return }
        let inbox = container.appendingPathComponent("ShareInbox", isDirectory: true)
        do { try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true) }
        catch { finish(error: "Nie można zapisać udostępnionego materiału."); return }

        let taskGroup = DispatchGroup()
        let lock = NSLock()
        var urls: [String] = []
        var errors: [String] = []
        if !text.isEmpty { urls.append(text) }

        for (index, provider) in providers.enumerated() {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                taskGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    defer { taskGroup.leave() }
                    let sharedURL = (item as? URL) ?? (item as? NSURL).map { $0 as URL } ?? (item as? String).flatMap(URL.init(string:))
                    if let sharedURL {
                        lock.lock(); urls.append(sharedURL.absoluteString); lock.unlock()
                    } else if let error {
                        lock.lock(); errors.append(error.localizedDescription); lock.unlock()
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
                        provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let type = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ? UTType.movie : UTType.image
                taskGroup.enter()
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { sourceURL, error in
                    defer { taskGroup.leave() }
                    guard let sourceURL else {
                        if let error { lock.lock(); errors.append(error.localizedDescription); lock.unlock() }
                        return
                    }
                    let ext = sourceURL.pathExtension.isEmpty ? (type == .movie ? "mov" : "img") : sourceURL.pathExtension
                    let destination = inbox.appendingPathComponent("shared-\(index)-\(UUID().uuidString).\(ext)")
                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: destination)
                        lock.lock(); urls.append(destination.lastPathComponent); lock.unlock()
                    } catch {
                        lock.lock(); errors.append(error.localizedDescription); lock.unlock()
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                taskGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    defer { taskGroup.leave() }
                    if let value = item as? String {
                        lock.lock(); urls.append(value); lock.unlock()
                    }
                }
            }
        }

        taskGroup.notify(queue: .main) {
            let payload: [String: Any] = [
                "items": urls,
                "errors": errors,
                "receivedAt": ISO8601DateFormatter().string(from: Date())
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
                try data.write(to: inbox.appendingPathComponent("latest-share.json"), options: .atomic)
                self.statusLabel.text = errors.isEmpty ? "Materiał przekazany. Otwórz Przepiśnik AI, aby utworzyć przepis." : "Część materiału przekazano. Niektórych załączników nie udało się odczytać."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.extensionContext?.completeRequest(returningItems: nil) }
            } catch { self.finish(error: "Nie udało się zapisać materiału.") }
        }
    }

    private func finish(error: String) {
        statusLabel.text = error
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.extensionContext?.cancelRequest(withError: NSError(domain: "PrzepisnikShare", code: 1, userInfo: [NSLocalizedDescriptionKey: error])) }
    }
}
