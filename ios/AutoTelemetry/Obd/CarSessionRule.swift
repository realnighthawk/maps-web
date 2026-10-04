import Foundation

/// When the car disconnects, should the drive end? Only if it was started during that car session (by the car's
/// connection, or by hand while connected). A drive you began earlier, away from the car, is yours to end.
enum CarSessionRule {
    static let graceSeconds: TimeInterval = 60

    static func shouldStop(driveBusy: Bool, driveRequestedAt: Date?, carConnectedAt: Date) -> Bool {
        guard driveBusy, let requested = driveRequestedAt else { return false }
        return requested >= carConnectedAt
    }
}
