import SwiftUI

/// Draws the arena rectangle with letter positions and a rider dot.
struct ArenaView: View {
    let configuration: ArenaConfiguration
    let riderState: RiderState
    let detectedBeacons: [DetectedBeacon]

    private let padding: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let arenaWidth = configuration.arenaSize.width
            let arenaLength = configuration.arenaSize.length
            let drawArea = CGSize(
                width: geo.size.width - padding * 2,
                height: geo.size.height - padding * 2
            )
            // Scale to fit, preserving aspect ratio
            let scaleX = drawArea.width / arenaWidth
            let scaleY = drawArea.height / arenaLength
            let scale = min(scaleX, scaleY)
            let offsetX = padding + (drawArea.width - arenaWidth * scale) / 2
            let offsetY = padding + (drawArea.height - arenaLength * scale) / 2

            Canvas { context, _ in
                // Draw arena rectangle
                let rect = CGRect(
                    x: offsetX,
                    y: offsetY,
                    width: arenaWidth * scale,
                    height: arenaLength * scale
                )
                context.stroke(Path(rect), with: .color(.secondary), lineWidth: 2)

                // Draw centerline
                let centerX = offsetX + 10 * scale
                var centerline = Path()
                centerline.move(to: CGPoint(x: centerX, y: offsetY))
                centerline.addLine(to: CGPoint(x: centerX, y: offsetY + arenaLength * scale))
                context.stroke(centerline, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                // Draw letter markers
                let beaconLetters = configuration.beaconLetters
                for letter in ArenaLetter.allCases {
                    let pos = letter.position(for: configuration.arenaSize)
                    let screenPos = CGPoint(
                        x: offsetX + pos.x * scale,
                        y: offsetY + (arenaLength - pos.y) * scale // flip Y so A is at bottom
                    )

                    let isBeacon = beaconLetters.contains(letter)
                    let radius: CGFloat = isBeacon ? 12 : 8
                    let circle = Path(ellipseIn: CGRect(
                        x: screenPos.x - radius,
                        y: screenPos.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    if isBeacon {
                        context.fill(circle, with: .color(.blue.opacity(0.3)))
                        context.stroke(circle, with: .color(.blue), lineWidth: 2)
                    } else {
                        context.stroke(circle, with: .color(.secondary), lineWidth: 1)
                    }

                    // Label
                    let text = Text(letter.rawValue)
                        .font(.caption2.bold())
                        .foregroundColor(isBeacon ? .blue : .secondary)
                    context.draw(
                        context.resolve(text),
                        at: CGPoint(x: screenPos.x, y: screenPos.y - radius - 8)
                    )
                }

                // Draw rider dot
                if riderState.confidence != .none {
                    let riderScreen = CGPoint(
                        x: offsetX + riderState.position.x * scale,
                        y: offsetY + (arenaLength - riderState.position.y) * scale
                    )
                    let dotRadius: CGFloat = 10
                    let dot = Path(ellipseIn: CGRect(
                        x: riderScreen.x - dotRadius,
                        y: riderScreen.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))

                    let dotColor: Color = switch riderState.confidence {
                    case .strong: .green
                    case .weak: .yellow
                    case .none: .red
                    }
                    context.fill(dot, with: .color(dotColor))
                    context.stroke(dot, with: .color(dotColor.opacity(0.8)), lineWidth: 2)
                }
            }
        }
    }
}
