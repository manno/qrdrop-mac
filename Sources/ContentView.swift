import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var inputText = "https://github.com"
    @State private var isDropTargeted = false
    @State private var detailLevel = QRCodeDetailLevel.balanced
    @State private var exportMessage = "Copy the QR image or save it as a PNG."

    private let dropTypes = [
        UTType.url.identifier,
        UTType.plainText.identifier,
        UTType.utf8PlainText.identifier
    ]

    private var qrImage: NSImage? {
        QRCodeRenderer.image(for: inputText, detailLevel: detailLevel)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            editorPane
            previewPane
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 520)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste or drop text")
                .font(.title2.weight(.semibold))

            Text("URLs work great, but any text can be turned into a QR code.")
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isDropTargeted ? 2 : 1)

                TextEditor(text: $inputText)
                    .font(.system(.body, design: .default))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.clear)

                if inputText.isEmpty {
                    Text("Drop a link here or press Command-V")
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                        .padding(.leading, 18)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 260)
            .onDrop(of: dropTypes, isTargeted: $isDropTargeted, perform: handleDrop)

            HStack(spacing: 12) {
                Button("Paste from Clipboard", action: pasteFromClipboard)
                    .keyboardShortcut("v", modifiers: [.command])

                Button("Clear") {
                    inputText = ""
                }
                .disabled(inputText.isEmpty)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("QR detail")
                        .font(.headline)

                    Spacer()

                    Text(detailLevel.title)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(detailLevel.rawValue) },
                        set: { newValue in
                            detailLevel = QRCodeDetailLevel(rawValue: Int(newValue.rounded())) ?? .balanced
                        }
                    ),
                    in: 0...Double(QRCodeDetailLevel.allCases.count - 1),
                    step: 1
                )

                HStack {
                    Text("Simpler")
                    Spacer()
                    Text("More detailed")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(detailLevel.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QR preview")
                .font(.title2.weight(.semibold))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    Group {
                        if let qrImage {
                            Image(nsImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(28)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.secondary)

                                Text("Enter some text to generate a QR code.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(width: 320, height: 320)

            Text("The QR code updates live as the text changes.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Copy QR Image", action: copyQRCode)
                    .disabled(qrImage == nil)

                Button("Save PNG", action: saveQRCode)
                    .disabled(qrImage == nil)
            }

            Text(exportMessage)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(width: 320, alignment: .topLeading)
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general

        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
            inputText = url.absoluteString
            return
        }

        if let text = pasteboard.string(forType: .string) {
            inputText = text
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: NSURL.self) }) {
            _ = provider.loadObject(ofClass: NSURL.self) { item, error in
                guard error == nil, let url = item as? URL else {
                    return
                }

                DispatchQueue.main.async {
                    inputText = url.absoluteString
                }
            }

            return true
        }

        if let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) {
            _ = provider.loadObject(ofClass: NSString.self) { item, error in
                guard error == nil, let text = item as? String else {
                    return
                }

                DispatchQueue.main.async {
                    inputText = text
                }
            }

            return true
        }

        return false
    }

    private func copyQRCode() {
        guard let qrImage else {
            exportMessage = "Enter some text before copying the QR code."
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if pasteboard.writeObjects([qrImage]) {
            exportMessage = "Copied the QR image to the clipboard."
        } else {
            exportMessage = "Could not copy the QR image."
        }
    }

    private func saveQRCode() {
        guard let pngData = QRCodeRenderer.pngData(for: inputText, detailLevel: detailLevel) else {
            exportMessage = "Enter some text before saving the QR code."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "qrcode.png"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            exportMessage = "Save canceled."
            return
        }

        do {
            try pngData.write(to: destinationURL, options: .atomic)
            exportMessage = "Saved PNG to \(destinationURL.lastPathComponent)."
        } catch {
            exportMessage = "Could not save PNG: \(error.localizedDescription)"
        }
    }
}
