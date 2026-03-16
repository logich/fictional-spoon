import SwiftUI

/// Scrollable list of all movements in a dressage test — for reviewing before a ride.
struct PreviewMovementsView: View {
    let test: DressageTest

    var body: some View {
        List(test.movements) { movement in
            HStack(alignment: .top, spacing: 12) {
                // Sequence number
                Text("\(movement.sequence)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)

                VStack(alignment: .leading, spacing: 3) {
                    // Location + spoken text
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(movement.location.label)
                            .font(.subheadline.bold())
                        Text(movement.spokenText)
                            .font(.subheadline)
                        Spacer(minLength: 0)
                        // Gait badge
                        if let gait = movement.expectedGait {
                            Text(gait.rawValue.capitalized)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(gaitColor(gait).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(gaitColor(gait))
                        }
                    }
                    // Directive text
                    Text(movement.directiveText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("Movements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func gaitColor(_ gait: Gait) -> Color {
        switch gait {
        case .halt:   return .primary
        case .walk:   return .green
        case .trot:   return .blue
        case .canter: return .orange
        }
    }
}
