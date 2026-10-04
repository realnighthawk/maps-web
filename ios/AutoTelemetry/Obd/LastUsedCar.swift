import Foundation

/// Which car to connect to when nobody has picked one: the car you drove most recently, among those with an adapter
/// set up (a car with no adapter can't be connected, however recently it was added).
enum LastUsedCar {
    /// [carsWithAdapter] are the candidates in the order to fall back to; [recentTripCars] are the vehicle ids of past
    /// drives, newest first (a drive with no car is skipped).
    static func pick(carsWithAdapter: [String], recentTripCars: [String?]) -> String? {
        let candidates = Set(carsWithAdapter)
        return recentTripCars.compactMap { $0 }.first(where: candidates.contains) ?? carsWithAdapter.first
    }
}
