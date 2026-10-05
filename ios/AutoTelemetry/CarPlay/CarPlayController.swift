import CarPlay
import MapKit
import Observation
import SwiftData
import UIKit

/// Entry point iOS calls when the phone connects to a CarPlay head unit.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        MainActor.assumeIsolated { CarPlayController.shared.connect(interfaceController, scene: scene) }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        MainActor.assumeIsolated { CarPlayController.shared.disconnect() }
    }
}

/// The car's screens: Plan (the trip planned on the phone, with its stops), Drive (status and one button), Drives (recent).
/// Read-mostly by design: no typing, no planning, no adapter choice while moving. Those stay on the phone.
@MainActor
final class CarPlayController {
    static let shared = CarPlayController()

    private let model = AppModel.shared
    private var interface: CPInterfaceController?
    private let driveTemplate = CPInformationTemplate(title: "Garage", layout: .leading, items: [], actions: [])
    private let drivesTemplate = CPListTemplate(title: "Drives", sections: [])
    private let planTemplate = CPListTemplate(title: "Plan", sections: [])
    private weak var scene: CPTemplateApplicationScene?
    private var planKey = ""
    private var listKey = ""
    private var connectedAt = Date.distantPast
    private var pendingStop: Task<Void, Never>?

    /// Apple's CarPlay guidelines: don't refresh data items in the car's UI more than once every 10 seconds. A change of
    /// drive state (connecting, live, stopped, failed) still shows at once, because it changes what the button does.
    private let minRefreshInterval: TimeInterval = 10
    private var lastRefresh = Date.distantPast
    private var lastState: DriveState?
    private var pendingRefresh: Task<Void, Never>?

    private init() {
        driveTemplate.tabTitle = "Drive"
        driveTemplate.tabImage = UIImage(systemName: "speedometer")
        drivesTemplate.tabTitle = "Drives"
        drivesTemplate.tabImage = UIImage(systemName: "clock.arrow.circlepath")
        planTemplate.tabTitle = "Plan"
        planTemplate.tabImage = UIImage(systemName: "point.topleft.down.to.point.bottomright.curvepath")
    }

    func connect(_ controller: CPInterfaceController, scene: CPTemplateApplicationScene) {
        interface = controller
        self.scene = scene
        // Back within the grace period (a wireless glitch): the drive carries on.
        pendingStop?.cancel()
        connectedAt = .now
        listKey = ""
        planKey = ""
        controller.setRootTemplate(CPTabBarTemplate(templates: [planTemplate, driveTemplate, drivesTemplate]), animated: false, completion: nil)
        // Getting in the car is the cue to connect to its adapter.
        if model.prefs.autoStart { Task { _ = await model.autoStartDrive() } }
        observe()
    }

    func disconnect() {
        interface = nil
        pendingRefresh?.cancel()
        lastState = nil
        endDriveAfterGrace(carConnectedAt: connectedAt)
    }

    /// Leaving the car ends the drive that began with it, after a minute so a brief CarPlay dropout doesn't cut it short.
    private func endDriveAfterGrace(carConnectedAt: Date) {
        guard model.prefs.autoStart else { return }
        pendingStop?.cancel()
        pendingStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(CarSessionRule.graceSeconds))
            guard !Task.isCancelled, let self else { return }
            if CarSessionRule.shouldStop(driveBusy: self.model.drive.busy, driveRequestedAt: self.model.drive.requestedAt,
                                         carConnectedAt: carConnectedAt) {
                self.model.drive.stop()
            }
        }
    }

    /// Redraws when something the screens read changes, but live numbers (which change every second) no more often
    /// than [minRefreshInterval]: the changes in between wait, and the latest values are shown when it is up.
    private func observe() {
        guard interface != nil else { return }
        let stateChanged = model.drive.state != lastState
        let wait = minRefreshInterval - Date().timeIntervalSince(lastRefresh)
        if !stateChanged, wait > 0 {
            pendingRefresh?.cancel()
            pendingRefresh = Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                if !Task.isCancelled { self?.observe() }
            }
            return
        }
        lastRefresh = Date()
        lastState = model.drive.state
        withObservationTracking { refresh() } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func refresh() {
        let cars = model.ownedVehicles()
        let signedIn: Bool = { if case .signedIn = model.auth.state { true } else { false } }()
        let drive = CarPlayContent.drive(
            state: model.drive.state, car: model.drive.vehicle?.displayName ?? cars.first?.displayName,
            drivetrain: (model.drive.vehicle ?? cars.first)?.drivetrain ?? .gas,
            live: model.drive.live, speedKmh: model.drive.speedKmh, signedIn: signedIn,
            streaming: model.prefs.streaming, pending: model.sync.pending)

        driveTemplate.title = drive.title
        driveTemplate.items = drive.rows.map { CPInformationItem(title: $0.label, detail: $0.value) }
        driveTemplate.actions = drive.action.map { [button($0)] } ?? []

        guard model.auth.ownerId != nil else {
            driveTemplate.items = [CPInformationItem(title: "Sign in", detail: "Open AutoTelemetry on your iPhone")]
            driveTemplate.actions = []
            return
        }
        refreshLists(cars)
        refreshPlan()
    }

    // MARK: plan

    private func refreshPlan() {
        let screen = CarPlayContent.plan(model.plan.plan)
        // Rebuild only when the plan changes; the arrival time moves every minute and isn't worth a redraw.
        let summary = screen.summary.filter { $0.label != "Arrive" }.map(\.value).joined(separator: ",")
        let key = "\(screen.title)|\(screen.message ?? "")|\(summary)|\(screen.stops.map(\.name).joined(separator: ","))"
        guard key != planKey else { return }
        planKey = key
        planTemplate.updateSections(sections(for: screen))
    }

    private func sections(for screen: CarPlayPlanScreen) -> [CPListSection] {
        if let m = screen.message { return [CPListSection(items: [CPListItem(text: screen.title, detailText: m)])] }
        var out = [CPListSection(items: screen.summary.map { CPListItem(text: $0.value, detailText: $0.label) }, header: screen.title, sectionIndexTitle: nil)]
        if !screen.stops.isEmpty {
            let items = screen.stops.map { stop -> CPListItem in
                let item = CPListItem(text: stop.name, detailText: stop.detail,
                                      image: UIImage(systemName: stop.isCharge ? "bolt.fill" : "fuelpump.fill"))
                item.accessoryType = .disclosureIndicator
                item.handler = { [weak self] _, done in self?.offerDirections(to: stop); done() }
                return item
            }
            out.append(CPListSection(items: items, header: "Stops", sectionIndexTitle: nil))
        }
        return out
    }

    /// Hands a stop to Apple Maps for guidance (turn-by-turn isn't this app's job). Whether CarPlay allows it for this
    /// kind of app is confirmed once the entitlement is granted; if it refuses, say so rather than do nothing.
    private func offerDirections(to stop: CarPlayPlanScreen.Stop) {
        let go = CPAlertAction(title: "Directions in Apple Maps", style: .default) { [weak self] _ in
            self?.interface?.dismissTemplate(animated: true, completion: nil)
            guard let scene = self?.scene else { return }
            let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: stop.latitude, longitude: stop.longitude)))
            item.name = stop.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving], from: scene) { ok in
                if !ok { Task { @MainActor in self?.showMessage("Couldn't open Apple Maps from here.") } }
            }
        }
        let cancel = CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.interface?.dismissTemplate(animated: true, completion: nil) }
        interface?.presentTemplate(CPActionSheetTemplate(title: stop.name, message: stop.detail.isEmpty ? nil : stop.detail, actions: [go, cancel]),
                                   animated: true, completion: nil)
    }

    private func showMessage(_ text: String) {
        let ok = CPAlertAction(title: "OK", style: .default) { [weak self] _ in self?.interface?.dismissTemplate(animated: true, completion: nil) }
        interface?.presentTemplate(CPAlertTemplate(titleVariants: [text], actions: [ok]), animated: true, completion: nil)
    }

    private func button(_ action: CarPlayDrive.Action) -> CPTextButton {
        switch action {
        case .start, .retry:
            CPTextButton(title: action == .start ? "Start drive" : "Try again", textStyle: .confirm) { [weak self] _ in self?.start() }
        case .stop:
            CPTextButton(title: "Stop drive", textStyle: .cancel) { [weak self] _ in self?.model.drive.stop() }
        }
    }

    /// Connects with the car's usual adapter. A first drive needs the picker, which is a phone job.
    private func start() {
        guard !model.quickStartDrive() else { return }
        let ok = CPAlertAction(title: "OK", style: .default) { [weak self] _ in self?.interface?.dismissTemplate(animated: true, completion: nil) }
        interface?.presentTemplate(CPAlertTemplate(titleVariants: ["Pick your adapter on iPhone first", "Pick adapter on iPhone"], actions: [ok]),
                                   animated: true, completion: nil)
    }

    // MARK: lists

    private func refreshLists(_ cars: [Vehicle]) {
        let ctx = model.container.mainContext
        var d = FetchDescriptor<Trip>(predicate: #Predicate { $0.status != "ACTIVE" }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        d.fetchLimit = 12
        let owner = model.auth.ownerId
        let trips = ((try? ctx.fetch(d)) ?? []).filter { $0.ownerId == owner }

        // Only touch the lists when they would change; the drive screen updates every second, these do not.
        let key = trips.map { "\($0.id)\($0.status)" }.joined() + "|" + cars.map { "\($0.id)\($0.updatedAt.timeIntervalSince1970)" }.joined()
        guard key != listKey else { return }
        listKey = key

        let names = Dictionary(uniqueKeysWithValues: cars.map { ($0.id, $0.displayName) })
        let tripItems = trips.map { t -> CPListItem in
            let secs = (t.endedAt ?? t.startedAt).timeIntervalSince(t.startedAt)
            let item = CPListItem(text: CarPlayContent.tripTitle(t.startedAt),
                                  detailText: [CarPlayContent.duration(secs), t.vehicleId.flatMap { names[$0] }].compactMap { $0 }.joined(separator: " · "))
            item.accessoryType = .none
            return item
        }
        drivesTemplate.updateSections([CPListSection(items: tripItems.isEmpty ? [CPListItem(text: "No drives yet", detailText: "Start one from the Drive tab")] : tripItems)])

    }
}
