import Foundation
import PDFKit

/// Extracts and parses dressage movements from PDF text.
/// Supports USDF and WDAA test formatting conventions.
///
/// Extracted from TestImportView so it can be unit-tested independently.
struct PDFTestParser {

    // MARK: - Public API

    /// Extract raw text from all pages of a PDF document.
    func extractText(from pdf: PDFDocument) -> String {
        (0..<pdf.pageCount)
            .compactMap { pdf.page(at: $0)?.string }
            .joined(separator: "\n")
    }

    /// Parse movements from the raw text of a dressage test PDF.
    ///
    /// Returns an empty array if no movement blocks were found.
    func parseMovements(from text: String) -> [Movement] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Collapse continuation lines into movement blocks by detecting
        // lines that start with a sequence number (e.g. "1." or "1)").
        var blocks: [(sequence: Int, raw: String)] = []
        for line in lines {
            if let seq = leadingSequenceNumber(in: line) {
                blocks.append((seq, line))
            } else if !blocks.isEmpty {
                blocks[blocks.count - 1].raw += " " + line
            }
        }

        let letterValues = Set(ArenaLetter.allCases.map(\.rawValue))
        var movements: [Movement] = []

        for block in blocks {
            // Strip the sequence number prefix.
            let body = block.raw
                .replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            // Try to find an arena letter token at the start.
            let tokens = body.components(separatedBy: .whitespaces)
            let letterToken = tokens.first.flatMap { tok -> ArenaLetter? in
                let cleaned = tok.trimmingCharacters(in: .punctuationCharacters).uppercased()
                return letterValues.contains(cleaned) ? ArenaLetter(rawValue: cleaned) : nil
            }

            let location: MovementLocation = letterToken.map { .letter($0) } ?? .letter(.X)
            let gait = inferGait(from: body)

            movements.append(Movement(
                sequence: block.sequence,
                location: location,
                spokenText: body,
                directiveText: body,
                expectedGait: gait
            ))
        }

        return movements
    }

    // MARK: - Private helpers

    func leadingSequenceNumber(in line: String) -> Int? {
        let pattern = #"^(\d+)[\.\)]\s"#
        guard let range = line.range(of: pattern, options: .regularExpression),
              let numRange = line.range(of: #"^\d+"#, options: .regularExpression) else {
            return nil
        }
        _ = range
        return Int(line[numRange])
    }

    func inferGait(from text: String) -> Gait? {
        let lower = text.lowercased()
        if lower.contains("halt") { return .halt }
        if lower.contains("canter") { return .canter }
        if lower.contains("trot") { return .trot }
        if lower.contains("walk") { return .walk }
        return nil
    }
}
