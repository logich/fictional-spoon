import Foundation

/// Bundled dressage tests that ship with the app.
enum SampleTests {

    /// USEF/USDF Training Level Test 1 (2023), effective 12/1/2022 through 11/30/2026.
    /// Standard 20x60m arena.
    static let trainingLevel1 = DressageTest(
        name: "Training Level Test 1",
        organization: .usef,
        level: "Training",
        arenaSize: .standard,
        year: 2023,
        movements: [
            Movement(
                sequence: 1,
                location: .letter(.A),
                spokenText: "A, Enter working trot rising",
                directiveText: "Enter working trot rising",
                expectedGait: .trot
            ),
            Movement(
                sequence: 2,
                location: .letter(.X),
                spokenText: "X, Halt, salute. Proceed working trot rising",
                directiveText: "Halt, salute. Proceed working trot rising",
                expectedGait: .trot
            ),
            Movement(
                sequence: 3,
                location: .letter(.C),
                spokenText: "C, Track left",
                directiveText: "Track left",
                expectedGait: .trot
            ),
            Movement(
                sequence: 4,
                location: .letter(.E),
                spokenText: "E, Circle left 20 meters",
                directiveText: "Circle left 20m",
                expectedGait: .trot
            ),
            Movement(
                sequence: 5,
                location: .letter(.A),
                spokenText: "A, Circle left 20 meters, developing left lead canter in first quarter of circle",
                directiveText: "Circle left 20m developing left lead canter in first quarter of circle",
                expectedGait: .canter
            ),
            Movement(
                sequence: 6,
                location: .letter(.A),
                spokenText: "A, Working canter",
                directiveText: "A-F-B Working canter",
                expectedGait: .canter
            ),
            Movement(
                sequence: 7,
                location: .between(.B, .M),
                spokenText: "Between B and M, Working trot rising",
                directiveText: "Between B & M Working trot",
                expectedGait: .trot
            ),
            Movement(
                sequence: 8,
                location: .between(.C, .H),
                spokenText: "Between C and H, Medium walk",
                directiveText: "Between C & H Medium walk",
                expectedGait: .walk
            ),
            Movement(
                sequence: 9,
                location: .letter(.E),
                spokenText: "E, Change rein, free walk",
                directiveText: "E-F Change rein, free walk",
                expectedGait: .walk
            ),
            Movement(
                sequence: 10,
                location: .letter(.F),
                spokenText: "F, Medium walk",
                directiveText: "Medium walk",
                expectedGait: .walk
            ),
            Movement(
                sequence: 11,
                location: .letter(.A),
                spokenText: "A, Working trot rising",
                directiveText: "Working trot rising",
                expectedGait: .trot
            ),
            Movement(
                sequence: 12,
                location: .letter(.E),
                spokenText: "E, Circle right 20 meters",
                directiveText: "Circle right 20m",
                expectedGait: .trot
            ),
            Movement(
                sequence: 13,
                location: .letter(.C),
                spokenText: "C, Circle right 20 meters, developing right lead canter in first quarter of circle",
                directiveText: "Circle right 20m developing right lead canter in first quarter of circle",
                expectedGait: .canter
            ),
            Movement(
                sequence: 14,
                location: .letter(.C),
                spokenText: "C, Working canter",
                directiveText: "C-M-B Working canter",
                expectedGait: .canter
            ),
            Movement(
                sequence: 15,
                location: .between(.B, .F),
                spokenText: "Between B and F, Working trot rising",
                directiveText: "Between B & F Working trot",
                expectedGait: .trot
            ),
            Movement(
                sequence: 16,
                location: .letter(.A),
                spokenText: "A, Down centerline",
                directiveText: "Down centerline",
                expectedGait: .trot
            ),
            Movement(
                sequence: 17,
                location: .letter(.X),
                spokenText: "X, Halt, salute",
                directiveText: "Halt, salute",
                expectedGait: .halt
            ),
        ]
    )
}
