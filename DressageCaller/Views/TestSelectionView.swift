import SwiftUI

/// Picker for selecting a dressage test.
struct TestSelectionView: View {
    @Binding var selectedTest: DressageTest?
    let arenaSize: ArenaSize
    var library: TestLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var showImport = false

    /// Bundled tests matching the current arena size.
    private var availableTests: [DressageTest] {
        Self.bundledTests.filter { $0.arenaSize == arenaSize }
    }

    /// Bundled tests for a different arena size.
    private var otherTests: [DressageTest] {
        Self.bundledTests.filter { $0.arenaSize != arenaSize }
    }

    /// Imported tests matching the current arena size.
    private var importedTests: [DressageTest] {
        library.tests.filter { $0.arenaSize == arenaSize }
    }

    /// Imported tests for a different arena size.
    private var otherImportedTests: [DressageTest] {
        library.tests.filter { $0.arenaSize != arenaSize }
    }

    var body: some View {
        List {
            if availableTests.isEmpty && importedTests.isEmpty {
                Section {
                    Text("No tests available for this arena size.")
                        .foregroundStyle(.secondary)
                }
            }

            if !availableTests.isEmpty {
                Section(arenaSize == .standard ? "Standard Arena (20\u{00D7}60m)" : "Small Arena (20\u{00D7}40m)") {
                    ForEach(availableTests) { test in
                        testRow(test)
                    }
                }
            }

            if !importedTests.isEmpty {
                Section("Imported") {
                    ForEach(importedTests) { test in
                        testRow(test)
                    }
                }
            }

            if !otherTests.isEmpty || !otherImportedTests.isEmpty {
                Section {
                    ForEach(otherTests + otherImportedTests) { test in
                        testRow(test)
                            .disabled(true)
                    }
                } header: {
                    Text("Other Arena Size")
                } footer: {
                    Text("Change your arena size to use these tests.")
                }
            }
        }
        .navigationTitle("Select Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import…") { showImport = true }
            }
        }
        .sheet(isPresented: $showImport, onDismiss: { library.load() }) {
            TestImportView(library: library)
        }
    }

    private func testRow(_ test: DressageTest) -> some View {
        Button {
            selectedTest = test
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(test.name)
                        .foregroundStyle(.primary)
                    Text("\(test.organization.rawValue.uppercased()) \(test.year) \u{00B7} \(test.movements.count) movements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if test.id == selectedTest?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    /// Registry of all bundled tests.
    private static let bundledTests: [DressageTest] = [
        SampleTests.trainingLevel1,
    ]
}
