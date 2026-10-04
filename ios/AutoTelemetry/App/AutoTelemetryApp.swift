import SwiftData
import SwiftUI

@main
struct AutoTelemetryApp: App {
    private let model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .tint(Tok.accent)
                #if DEBUG
                .task { await runLaunchScanIfRequested() }
                #endif
        }
    }
}

#if DEBUG
/// `-scan-car` launch argument: run the car scan through the first garage car that has an adapter, then print the log.
/// Lets the scan run from the Mac with the console attached, without tapping through the app.
@MainActor
private func runLaunchScanIfRequested() async {
    let args = ProcessInfo.processInfo.arguments
    if args.contains("-drive-car") { await runLaunchDrive(); return }
    guard args.contains("-scan-car") else { return }
    let model = AppModel.shared
    for _ in 0..<40 where model.auth.ownerId == nil { try? await Task.sleep(for: .milliseconds(500)) }
    guard let car = model.ownedVehicles().first(where: { AdapterPrefs.get($0.id) != nil }) else {
        print("[SCAN] no garage car has an adapter set up")
        return
    }
    for _ in 0..<40 where model.ble.state != .poweredOn { try? await Task.sleep(for: .milliseconds(500)) }
    print("[SCAN] scanning \(car.displayName)")
    await model.scanCar(car)
    print("[SCAN] finished")
}

/// `-drive-car` launch argument: record a short real drive through the first garage car that has an adapter and print
/// what each second recorded, so the whole path (car, phone sensors, profile readings) can be checked from the Mac.
@MainActor
private func runLaunchDrive() async {
    let model = AppModel.shared
    for _ in 0..<40 where model.auth.ownerId == nil { try? await Task.sleep(for: .milliseconds(500)) }
    for _ in 0..<40 where model.ble.state != .poweredOn { try? await Task.sleep(for: .milliseconds(500)) }
    guard let car = model.ownedVehicles().first(where: { AdapterPrefs.get($0.id) != nil }) else {
        print("[DRIVE] no garage car has an adapter set up")
        return
    }
    print("[DRIVE] starting \(car.displayName)")
    guard model.startDrive(car: car) else { print("[DRIVE] could not start"); return }
    for second in 1...45 {
        try? await Task.sleep(for: .seconds(1))
        if second % 5 == 0 {
            var d = FetchDescriptor<Sample>(sortBy: [SortDescriptor(\.at, order: .reverse)])
            d.fetchLimit = 1
            let last = (try? model.container.mainContext.fetch(d))?.first
            let readings = (last?.readings ?? [:]).sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.value.map { String(format: "%.2f", $0) } ?? "-")" }.joined(separator: " ")
            print("[DRIVE] t=\(second)s state=\(model.drive.state) acc=\(last?.accuracyM.map { String(format: "%.0f", $0) } ?? "-") lat=\(last?.lat != nil) | \(readings)")
        }
    }
    // What the Live tab would list right now.
    for g in LiveGroups.make(model.drive.live) { print("[LIVE] \(g.title): \(g.rows.count) rows, e.g. " + g.rows.prefix(3).map { "\($0.label)=\($0.value) \($0.unit)" }.joined(separator: "; ")) }
    model.drive.stop()
    print("[DRIVE] stopped; waiting to upload: \(model.sync.pending)")
}
#endif
