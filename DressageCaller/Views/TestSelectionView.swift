import SwiftUI

/// Picker for selecting a dressage test.
struct TestSelectionView: View {
    @Binding var selectedTest: DressageTest?
    let arenaSize: ArenaSize
    @Environment(\.dismiss) private var dismiss

    /// All available tests, filtered to the current arena size.
    private var availableTests: [DressageTest] {
        Self.allTests.filter { $0.arenaSize == arenaSize }
    }

    /// All tests including those for a different arena size.
    private var otherTests: [DressageTest] {
        Self.allTests.filter { $0.arenaSize != arenaSize }
    }

    var body: some View {
        List {
            if availableTests.isEmpty {
                Section {
                    Text("No tests available for this arena size.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(arenaSize == .standard ? "Standard Arena (20\u{00D7}60m)" : "Small Arena (20\u{00D7}40m)") {
                    ForEach(availableTests) { test in
                        testRow(test)
                    }
                }
            }

            if !otherTests.isEmpty {
                Section {
                    ForEach(otherTests) { test in
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
    private static let allTests: [DressageTest] = [
        SampleTests.trainingLevel1,
    ]
}
