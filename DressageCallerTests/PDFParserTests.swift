import PDFKit
import Testing
@testable import DressageCaller

// MARK: - Text fixture tests (no network, fast)

@Suite("PDFTestParser — text fixtures")
struct PDFTestParserTextTests {

    let parser = PDFTestParser()

    // MARK: Sequence number detection

    @Test func detectsDotFormat() {
        #expect(parser.leadingSequenceNumber(in: "1. A Working trot") == 1)
    }

    @Test func detectsParenFormat() {
        #expect(parser.leadingSequenceNumber(in: "12) C Halt") == 12)
    }

    @Test func rejectsNonSequenceLine() {
        #expect(parser.leadingSequenceNumber(in: "Working trot rising") == nil)
    }

    @Test func rejectsLineWithNoFollowingSpace() {
        // "1.A" with no space after the dot — not a valid block start
        #expect(parser.leadingSequenceNumber(in: "1.A Working trot") == nil)
    }

    // MARK: Gait inference

    @Test func infersTrot() {
        #expect(parser.inferGait(from: "Working trot rising") == .trot)
    }

    @Test func infersCanter() {
        #expect(parser.inferGait(from: "Canter 15m circle") == .canter)
    }

    @Test func infersHalt() {
        #expect(parser.inferGait(from: "Halt, salute") == .halt)
    }

    @Test func infersWalk() {
        #expect(parser.inferGait(from: "Free walk on a long rein") == .walk)
    }

    @Test func infersNilForUnknown() {
        #expect(parser.inferGait(from: "Turn down centerline") == nil)
    }

    // MARK: Full movement parsing — USDF-style text fixture

    @Test func parsesUsdfStyleBlock() throws {
        let text = """
        USDF Training Level Test 1 (2019)
        Arena: Standard

        1. A  Enter working trot rising. Halt, salute. Proceed working trot rising.
        2. C  Track right.
        3. E  Circle right 20 meters.
        4. A  Medium walk.
        5. F  Working trot rising.
        6. A  Down centerline.
        7. X  Halt, salute. Leave arena at free walk.
        """

        let movements = parser.parseMovements(from: text)
        #expect(movements.count == 7)
        #expect(movements[0].sequence == 1)
        #expect(movements[0].location == .letter(.A))
        #expect(movements[0].expectedGait == .halt)
        #expect(movements[1].location == .letter(.C))
        #expect(movements[3].expectedGait == .walk)
        #expect(movements[6].location == .letter(.X))
    }

    @Test func parsesWdaaStyleBlock() throws {
        let text = """
        WDAA Western Dressage Basic Test 1

        1) A  Enter working jog. Halt, salute. Proceed working jog.
        2) C  Track left.
        3) E  Circle left 20 meters, working jog.
        4) B  Turn left.
        5) A  Halt, salute. Leave at free walk.
        """

        let movements = parser.parseMovements(from: text)
        #expect(movements.count == 5)
        #expect(movements[0].sequence == 1)
        #expect(movements[0].location == .letter(.A))
        #expect(movements[4].expectedGait == .halt)
    }

    @Test func collatesContinuationLines() {
        // Multi-line directive — second line should be appended to block 1
        let text = """
        1. A  Enter working trot rising.
             Halt, salute at X.
        2. C  Track right.
        """

        let movements = parser.parseMovements(from: text)
        #expect(movements.count == 2)
        #expect(movements[0].directiveText.contains("Halt"))
        #expect(movements[1].sequence == 2)
    }

    @Test func fallsBackToXForUnknownLetter() {
        let text = "1. Enter working trot rising.\n2. C Track right."
        let movements = parser.parseMovements(from: text)
        #expect(movements[0].location == .letter(.X))
        #expect(movements[1].location == .letter(.C))
    }

    @Test func returnsEmptyForGibberish() {
        let text = "This document has no numbered movements at all."
        #expect(parser.parseMovements(from: text).isEmpty)
    }
}

// MARK: - PDF download integration tests
//
// These tests download real PDFs from governing body websites and validate that
// the parser produces a plausible result. They are skipped in CI (no network).
//
// To run locally:
//   Product → Test (⌘U) — or filter to "PDFParserIntegrationTests" in the Test navigator.
//
// ADD URLS HERE as you find working direct PDF links from:
//   USDF:  https://www.usdf.org/downloads/forms/index.asp?TypePass=Tests
//   WDAA:  https://www.westerndressageassociation.org/wdaa-tests
//   FEI:   https://inside.fei.org/fei/your-role/organisers/dressage/tests

struct PDFTestCase {
    let name: String
    let url: String
    let expectedMovementCount: Int   // exact count; set to 0 to skip count assertion
    let expectedOrg: String          // "USDF", "WDAA", "FEI" — informational only
}

@Suite("PDFTestParser — PDF download integration", .tags(.integration))
struct PDFParserIntegrationTests {

    let parser = PDFTestParser()

    /// Add direct PDF URLs here. The test will download, parse, and report results.
    /// Set expectedMovementCount to 0 if you don't yet know the count.
    static let testCases: [PDFTestCase] = [
        // ── USDF ──────────────────────────────────────────────────────────────
        // Paste direct .pdf links from usdf.org once obtained:
        // PDFTestCase(name: "USDF Training Level Test 1 2019",
        //             url: "https://...",
        //             expectedMovementCount: 17,
        //             expectedOrg: "USDF"),

        // ── WDAA ──────────────────────────────────────────────────────────────
        // PDFTestCase(name: "WDAA Basic Test 1",
        //             url: "https://...",
        //             expectedMovementCount: 0,
        //             expectedOrg: "WDAA"),
    ]

    @Test(arguments: testCases)
    func parsesRealPDF(_ testCase: PDFTestCase) async throws {
        guard let url = URL(string: testCase.url) else {
            Issue.record("Invalid URL for \(testCase.name)")
            return
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard httpStatus == 200 else {
            Issue.record("HTTP \(httpStatus) downloading \(testCase.name)")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try data.write(to: tempURL)

        guard let pdf = PDFDocument(url: tempURL) else {
            Issue.record("PDFDocument could not open \(testCase.name)")
            return
        }

        let text = parser.extractText(from: pdf)
        let movements = parser.parseMovements(from: text)

        // Always print a summary so you can inspect results in the test log
        print("""
        ── \(testCase.name) [\(testCase.expectedOrg)] ──
           Pages     : \(pdf.pageCount)
           Chars     : \(text.count)
           Movements : \(movements.count)
        \(movementSummary(movements))
        """)

        #expect(!movements.isEmpty, "No movements parsed from \(testCase.name)")

        if testCase.expectedMovementCount > 0 {
            #expect(
                movements.count == testCase.expectedMovementCount,
                "Expected \(testCase.expectedMovementCount) movements, got \(movements.count)"
            )
        }

        // Every movement should have non-empty directive text
        for m in movements {
            #expect(!m.directiveText.isEmpty, "Movement \(m.sequence) has empty directive text")
        }
    }

    private func movementSummary(_ movements: [Movement]) -> String {
        movements.prefix(5).map { m in
            "   \(String(format: "%2d", m.sequence)). [\(m.location.label)] \(m.directiveText.prefix(60))"
        }.joined(separator: "\n")
        + (movements.count > 5 ? "\n   … (\(movements.count - 5) more)" : "")
    }
}

extension Tag {
    @Tag static var integration: Self
}
