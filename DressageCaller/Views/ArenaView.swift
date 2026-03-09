import SwiftUI

/// Draws the arena rectangle with letter positions, rider dot, and current movement path.
struct ArenaView: View {
    let configuration: ArenaConfiguration
    let riderState: RiderState
    let detectedBeacons: [DetectedBeacon]
    var currentMovement: Movement? = nil

    private let padding: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let arenaWidth = configuration.arenaSize.width
            let arenaLength = configuration.arenaSize.length
            let drawArea = CGSize(
                width: geo.size.width - padding * 2,
                height: geo.size.height - padding * 2
            )
            let scaleX = drawArea.width / arenaWidth
            let scaleY = drawArea.height / arenaLength
            let scale = min(scaleX, scaleY)
            let offsetX = padding + (drawArea.width - arenaWidth * scale) / 2
            let offsetY = padding + (drawArea.height - arenaLength * scale) / 2

            // Converts arena meters (Y-up) to screen points (Y-down)
            let toScreen: (CGPoint) -> CGPoint = { pt in
                CGPoint(
                    x: offsetX + pt.x * scale,
                    y: offsetY + (arenaLength - pt.y) * scale
                )
            }

            Canvas { context, _ in
                // Arena rectangle
                let rect = CGRect(
                    x: offsetX, y: offsetY,
                    width: arenaWidth * scale, height: arenaLength * scale
                )
                context.stroke(Path(rect), with: .color(.secondary), lineWidth: 2)

                // Centerline (dashed)
                let centerX = offsetX + 10 * scale
                var centerline = Path()
                centerline.move(to: CGPoint(x: centerX, y: offsetY))
                centerline.addLine(to: CGPoint(x: centerX, y: offsetY + arenaLength * scale))
                context.stroke(centerline, with: .color(.secondary.opacity(0.3)),
                               style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                // Movement path
                if let movement = currentMovement, let shape = movement.path {
                    let gaitColor = color(for: movement.expectedGait)
                    let pathStyle = StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5])
                    let origin = movement.location.position(for: configuration.arenaSize)
                    let originScreen = toScreen(origin)

                    switch shape {
                    case .line(let dest):
                        let destScreen = toScreen(dest.position(for: configuration.arenaSize))
                        var p = Path()
                        p.move(to: originScreen)
                        p.addLine(to: destScreen)
                        context.stroke(p, with: .color(gaitColor.opacity(0.8)), style: pathStyle)
                        drawArrowhead(context: &context, at: destScreen, from: originScreen, color: gaitColor)

                    case .circle(let diameter):
                        // The named letter is the tangent point on the track.
                        // Offset the circle center inward (toward arena center) by the radius
                        // so the circle is tangential to the letter position.
                        let radiusMeters = diameter / 2
                        let arenaCenter = CGPoint(
                            x: configuration.arenaSize.width / 2,
                            y: configuration.arenaSize.length / 2
                        )
                        let dx = arenaCenter.x - origin.x
                        let dy = arenaCenter.y - origin.y
                        let dist = max((dx * dx + dy * dy).squareRoot(), 0.001)
                        let centerArena = CGPoint(
                            x: origin.x + (dx / dist) * radiusMeters,
                            y: origin.y + (dy / dist) * radiusMeters
                        )
                        let centerScreen = toScreen(centerArena)
                        let screenRadius = radiusMeters * scale
                        let circleRect = CGRect(
                            x: centerScreen.x - screenRadius,
                            y: centerScreen.y - screenRadius,
                            width: screenRadius * 2,
                            height: screenRadius * 2
                        )
                        context.stroke(Path(ellipseIn: circleRect),
                                       with: .color(gaitColor.opacity(0.8)), style: pathStyle)

                    case .track(let waypoints):
                        var p = Path()
                        p.move(to: originScreen)
                        for letter in waypoints {
                            let pos = letter.position(for: configuration.arenaSize)
                            p.addLine(to: toScreen(pos))
                        }
                        context.stroke(p, with: .color(gaitColor.opacity(0.8)), style: pathStyle)
                        if let last = waypoints.last {
                            let lastScreen = toScreen(last.position(for: configuration.arenaSize))
                            let prev = waypoints.count > 1
                                ? toScreen(waypoints[waypoints.count - 2].position(for: configuration.arenaSize))
                                : originScreen
                            drawArrowhead(context: &context, at: lastScreen, from: prev, color: gaitColor)
                        }
                    }
                }

                // Letter markers
                let beaconLetters = configuration.beaconLetters
                for letter in ArenaLetter.allCases {
                    let pos = letter.position(for: configuration.arenaSize)
                    let screenPos = toScreen(pos)

                    let isBeacon = beaconLetters.contains(letter)
                    let isTrigger = currentMovement.map { movementTriggers($0, letter: letter) } ?? false
                    let radius: CGFloat = isBeacon ? 12 : 8

                    let circle = Path(ellipseIn: CGRect(
                        x: screenPos.x - radius, y: screenPos.y - radius,
                        width: radius * 2, height: radius * 2
                    ))

                    if isTrigger {
                        let gaitColor = color(for: currentMovement?.expectedGait)
                        context.fill(circle, with: .color(gaitColor.opacity(0.25)))
                        context.stroke(circle, with: .color(gaitColor), lineWidth: 2.5)
                    } else if isBeacon {
                        context.fill(circle, with: .color(.blue.opacity(0.3)))
                        context.stroke(circle, with: .color(.blue), lineWidth: 2)
                    } else {
                        context.stroke(circle, with: .color(.secondary), lineWidth: 1)
                    }

                    let text = Text(letter.rawValue)
                        .font(.caption2.bold())
                        .foregroundColor(isTrigger ? color(for: currentMovement?.expectedGait) : isBeacon ? .blue : .secondary)
                    context.draw(context.resolve(text),
                                 at: CGPoint(x: screenPos.x, y: screenPos.y - radius - 8))
                }

                // Rider dot
                if riderState.confidence != .none {
                    let riderScreen = toScreen(riderState.position)
                    let dotRadius: CGFloat = 10
                    let dot = Path(ellipseIn: CGRect(
                        x: riderScreen.x - dotRadius, y: riderScreen.y - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    ))
                    let dotColor: Color = switch riderState.confidence {
                    case .strong: .green
                    case .weak:   .yellow
                    case .none:   .red
                    }
                    context.fill(dot, with: .color(dotColor))
                    context.stroke(dot, with: .color(dotColor.opacity(0.8)), lineWidth: 2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func movementTriggers(_ movement: Movement, letter: ArenaLetter) -> Bool {
        switch movement.location {
        case .letter(let l): return l == letter
        case .between(let a, let b): return a == letter || b == letter
        }
    }

    private func color(for gait: Gait?) -> Color {
        switch gait {
        case .halt:   return .primary
        case .walk:   return .blue
        case .trot:   return .orange
        case .canter: return .red
        case nil:     return .accentColor
        }
    }

    private func drawArrowhead(context: inout GraphicsContext, at tip: CGPoint, from prev: CGPoint, color: Color) {
        let dx = tip.x - prev.x
        let dy = tip.y - prev.y
        let len = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let ux = dx / len
        let uy = dy / len
        let size: CGFloat = 10

        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - size * ux + size * 0.5 * uy,
                                   y: tip.y - size * uy - size * 0.5 * ux))
        arrow.addLine(to: CGPoint(x: tip.x - size * ux - size * 0.5 * uy,
                                   y: tip.y - size * uy + size * 0.5 * ux))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color.opacity(0.8)))
    }
}
