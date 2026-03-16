import PDFKit
import SwiftUI

/// Downloads a USDF PDF from a URL, parses movements from the text, and saves to TestLibrary.
///
/// PDF parsing is best-effort: it works on text-layer PDFs using USDF formatting conventions.
/// Multi-column or scanned PDFs will need manual correction after import.
@MainActor
struct TestImportView: View {
    @Environment(\.dismiss) private var dismiss

    var library: TestLibrary
    var fileURL: URL? = nil

    @State private var urlText: String = ""
    @State private var testName: String = ""
    @State private var phase: Phase = .entry
    @State private var parsedMovements: [Movement] = []
    @State private var errorMessage: String?

    enum Phase {
        case entry
        case downloading
        case review
        case saving
    }

    var body: some View {
        NavigationStack {
            Form {
                switch phase {
                case .entry:
                    entrySection
                case .downloading:
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Downloading PDF…")
                                .foregroundStyle(.secondary)
                        }
                    }
                case .review:
                    reviewSection
                case .saving:
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Saving…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Import Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let url = fileURL {
                    parseLocal(url: url)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if phase == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveTest() }
                            .disabled(testName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var entrySection: some View {
        Group {
            Section("PDF URL") {
                TextField("https://…", text: $urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Download") { downloadAndParse() }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section {
                EmptyView()
            } footer: {
                Text("Enter the URL of a USDF dressage test PDF. The text layer will be extracted and movements parsed. Review the result before saving.")
            }
        }
    }

    private var reviewSection: some View {
        Group {
            Section("Test Name") {
                TextField("e.g. Training Level Test 1", text: $testName)
            }
            Section("Movements (\(parsedMovements.count))") {
                ForEach(parsedMovements) { movement in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(movement.sequence)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 20, alignment: .trailing)
                            Text(movement.location.label)
                                .font(.caption.bold())
                            if let gait = movement.expectedGait {
                                Text(gait.rawValue.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(movement.directiveText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Download + parse

    private func downloadAndParse() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Invalid URL."
            return
        }
        errorMessage = nil
        phase = .downloading

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".pdf")
                try data.write(to: tempURL)
                parsePDF(at: tempURL, cleanup: true)
            } catch {
                errorMessage = "Download failed: \(error.localizedDescription)"
                phase = .entry
            }
        }
    }

    private func parseLocal(url: URL) {
        phase = .downloading
        let accessing = url.startAccessingSecurityScopedResource()
        parsePDF(at: url, cleanup: false)
        if accessing { url.stopAccessingSecurityScopedResource() }
    }

    private func parsePDF(at url: URL, cleanup: Bool) {
        guard let pdf = PDFDocument(url: url) else {
            errorMessage = "Could not open PDF. Ensure the file is a valid PDF with a text layer."
            phase = .entry
            return
        }

        let text = extractText(from: pdf)
        if cleanup { try? FileManager.default.removeItem(at: url) }

        let movements = parseMovements(from: text)
        if movements.isEmpty {
            errorMessage = "No movements found. The PDF may be scanned or use an unexpected format."
            phase = .entry
            return
        }

        parsedMovements = movements
        phase = .review
    }

    private let parser = PDFTestParser()

    private func extractText(from pdf: PDFDocument) -> String {
        parser.extractText(from: pdf)
    }

    private func parseMovements(from text: String) -> [Movement] {
        parser.parseMovements(from: text)
    }

    // MARK: - Save

    private func saveTest() {
        phase = .saving
        errorMessage = nil
        let test = DressageTest(
            name: testName.trimmingCharacters(in: .whitespaces),
            organization: .usdf,
            level: testName,
            arenaSize: .standard,
            year: Calendar.current.component(.year, from: Date()),
            movements: parsedMovements
        )
        Task {
            do {
                try library.save(test)
                dismiss()
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
                phase = .review
            }
        }
    }
}
