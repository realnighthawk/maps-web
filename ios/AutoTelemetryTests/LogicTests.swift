import CoreLocation
import XCTest
@testable import AutoTelemetry

final class LogicTests: XCTestCase {
    func testPolylineDecodesGoogleExample() {
        let p = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(p.count, 3)
        XCTAssertEqual(p[0].latitude, 38.5, accuracy: 1e-5)
        XCTAssertEqual(p[0].longitude, -120.2, accuracy: 1e-5)
        XCTAssertEqual(p[2].latitude, 43.252, accuracy: 1e-5)
        XCTAssertEqual(p[2].longitude, -126.453, accuracy: 1e-5)
    }

    func testVinDecoderParsesAndTitleCasesMake() {
        let json = #"{"Results":[{"Make":"HONDA","Model":"Accord","ModelYear":"2003","FuelTypePrimary":"Gasoline","ErrorCode":"0"}]}"#
        guard case .found(let m, let ok) = VinDecoder.parse("1HGCM82633A004352", Data(json.utf8)) else { return XCTFail() }
        XCTAssertEqual(m.make, "Honda"); XCTAssertEqual(m.year, 2003); XCTAssertFalse(m.isEv); XCTAssertTrue(ok)
        XCTAssertTrue(VinDecoder.isValid("1HGCM82633A004352"))
        XCTAssertFalse(VinDecoder.isValid("1HGCM82633A00435O")) // letter O is never in a VIN
        XCTAssertEqual(VinDecoder.titleCase("BMW"), "BMW")
    }

    func testObdParsesRpmAndVin() {
        XCTAssertEqual(ObdParser.dataBytes("41 0C 1A F8"), [0x1A, 0xF8])
        XCTAssertEqual(PidRegistry.all.first { $0.pid == "0C" }?.decode([0x1A, 0xF8]), 1726)
        XCTAssertTrue(ObdParser.dataBytes("NO DATA").isEmpty)
        // 49 02 01 + "1HGCM82633A004352" as hex
        let hex = "1HGCM82633A004352".utf8.map { String(format: "%02X", $0) }.joined()
        XCTAssertEqual(ObdParser.vin("490201" + hex), "1HGCM82633A004352")
    }

    func testSupportedBitmap() {
        // 0xBE1FA813: PID 01 set, 02 clear, 03 set...
        let s = ObdParser.supported(base: 0, bytes: [0xBE, 0x1F, 0xA8, 0x13])
        XCTAssertTrue(s.contains("01")); XCTAssertFalse(s.contains("02")); XCTAssertTrue(s.contains("0C")); XCTAssertTrue(s.contains("0D"))
    }

    func testBatchOmitsNonFiniteReadingsAndUnownedJourneys() {
        let car = Vehicle(vin: "1HGCM82633A004352", make: "Honda", model: nil, year: 2003, fuelType: nil, isEv: false, ownerId: "u")
        let trip = Trip(vehicleId: nil, ownerId: "u", startLat: nil, startLng: nil)
        let s = Sample(tripId: nil, vehicleId: car.id, ownerId: "u", lat: 1, lng: nil, speedKmh: 10,
                       readings: ["0C": Reading(label: "RPM", value: .nan, unit: "rpm"), "0D": Reading(label: "Speed", value: 10, unit: "km/h")])
        let j = BatchMapper.json(deviceId: "d", vehicles: [car], trips: [trip], samples: [s])
        XCTAssertEqual((j["journeys"] as? [Any])?.count, 0)
        let o = (j["observations"] as? [[String: Any]])?.first
        XCTAssertNil(o?["lat"]) // both coordinates or neither
        XCTAssertEqual((o?["readings"] as? [[String: Any]])?.count, 1)
    }

    func testHandoffUrl() {
        let u = MapsHandoff.url(origin: .init(latitude: 1, longitude: 2), destination: .init(latitude: 3, longitude: 4),
                                via: [.init(latitude: 5, longitude: 6)])?.absoluteString
        XCTAssertEqual(u, "https://www.google.com/maps/dir/?api=1&travelmode=driving&origin=1.000000,2.000000&destination=3.000000,4.000000&waypoints=5.000000,6.000000")
    }

    func testEvProfileCarriesBatteryAndAConnector() {
        let p = VehicleProfiles.ev(vin: "5YJ3E1EA7KF317000", make: "Tesla", model: "Model 3", year: 2019,
                                   batteryKwh: 75, rangeMiles: nil, connector: "TESLA")
        XCTAssertEqual(p["drivetrain"] as? String, "EV")
        XCTAssertEqual(p["battery_capacity_kwh"] as? Double, 75)
        XCTAssertEqual(p["connector_types"] as? [String], ["TESLA"])
        XCTAssertNil(p["epa_range_miles"]); XCTAssertNil(p["fuel_tank_size_liters"])
    }

    func testCarPlayDriveScreens() {
        let idle = CarPlayContent.drive(state: .idle, car: "Accord", live: [:], speedKmh: nil, signedIn: true, streaming: true, pending: 3)
        XCTAssertEqual(idle.action, .start)
        XCTAssertEqual(idle.rows.last, .init(label: "Waiting to upload", value: "3"))

        let live = CarPlayContent.drive(state: .live, car: nil, live: ["0C": Reading(label: "RPM", value: 2100, unit: "rpm")],
                                        speedKmh: 50, signedIn: false, streaming: true, pending: 0)
        XCTAssertEqual(live.action, .stop)
        XCTAssertEqual(live.title, "AutoTelemetry")
        XCTAssertEqual(live.rows.first?.label, "Speed")
        XCTAssertTrue(live.rows.contains(.init(label: "RPM", value: "2100")))
        XCTAssertFalse(live.rows.contains { $0.label == "Coolant" }, "no reading, no row")
        XCTAssertEqual(live.rows.last?.value, "Saving on phone", "a guest never streams")
        XCTAssertLessThanOrEqual(live.rows.count, 10, "CarPlay shows at most 10 rows")

        XCTAssertEqual(CarPlayContent.drive(state: .error("x"), car: nil, live: [:], speedKmh: nil, signedIn: true, streaming: true, pending: 0).action, .retry)
        XCTAssertNil(CarPlayContent.drive(state: .connecting("Veepeak"), car: nil, live: [:], speedKmh: nil, signedIn: true, streaming: true, pending: 0).action)
        XCTAssertEqual(CarPlayContent.duration(20), "1 min")
        XCTAssertEqual(CarPlayContent.duration(65 * 60), "1 h 5 min")
    }

    func testEachPidIsAskedOfOneModuleThatSupportsIt() {
        let route = PidPlan.route(perModule: ["7E0": ["0D", "0C"], "7E4": ["0D", "5B"], "7E6": ["42"]])
        XCTAssertEqual(route["0D"], "7E0", "the lowest address wins a tie")
        XCTAssertEqual(route["5B"], "7E4")
        XCTAssertEqual(route["42"], "7E6")
        XCTAssertNil(route["11"], "nothing is asked of a car that doesn't report it")
    }

    func testTiersKeepFastReadingsEveryCycle() {
        XCTAssertTrue(PidPlan.isDue(.fast, cycle: 7))
        XCTAssertTrue(PidPlan.isDue(.normal, cycle: 1) && PidPlan.isDue(.slow, cycle: 1), "the first cycle reads everything")
        XCTAssertFalse(PidPlan.isDue(.normal, cycle: 3)); XCTAssertTrue(PidPlan.isDue(.normal, cycle: 5))
        XCTAssertFalse(PidPlan.isDue(.slow, cycle: 5)); XCTAssertTrue(PidPlan.isDue(.slow, cycle: 30))
    }

    func testModulesAreReadFromHeaderedReplies() {
        // From the Mach-E scan: four modules answer 0100, each with its own id.
        let r = ElmProtocol.canReplies("7EE06410098180003\n7E8064100AA082013\n7EC06410098180003")
        XCTAssertEqual(r.map(\.module), ["7EE", "7E8", "7EC"])
        XCTAssertEqual(r[1].data, [0x41, 0x00, 0xAA, 0x08, 0x20, 0x13])
        XCTAssertEqual(ElmProtocol.requestAddress(forResponse: "7EC"), "7E4")
        XCTAssertEqual(ElmProtocol.requestAddress(forResponse: "7E8"), "7E0")
        XCTAssertTrue(ElmProtocol.canReplies("NO DATA").isEmpty)
        XCTAssertEqual(ObdParser.udsData("6248014486", did: "4801"), [0x44, 0x86])
        XCTAssertNil(ObdParser.udsData("7F2231", did: "4801"), "a refusal is not a reading")
    }

    func testTheVinPicksTheMachEProfile() {
        func car(_ make: String, _ model: String, _ year: Int) -> Vehicle {
            Vehicle(vin: "", make: make, model: model, year: year, fuelType: nil, isEv: true, ownerId: "u")
        }
        XCTAssertEqual(CarProfiles.match(car("Ford", "Mustang Mach-E", 2023))?.name, "Ford Mustang Mach-E")
        XCTAssertNil(CarProfiles.match(car("Ford", "F-150", 2023)))
        XCTAssertNil(CarProfiles.match(car("Ford", "Mustang Mach-E", 2019)))
        XCTAssertEqual(CarProfiles.raw([0x44, 0x86]), 17542)
        XCTAssertTrue(CarProfiles.machE.pids.allSatisfy { $0.key.count <= 16 }, "the server limits a reading id to 16 characters")
    }

    func testMotionIsSummarisedPerSecond() {
        var m = MotionAggregate()
        XCTAssertNil(m.takeSummary())
        m.add(accel: 0.1, gyro: 0.2); m.add(accel: 0.3, gyro: 0.0)
        let s = m.takeSummary()
        XCTAssertEqual(s?.accelAvg ?? 0, 0.2, accuracy: 1e-9); XCTAssertEqual(s?.accelMax, 0.3); XCTAssertEqual(s?.gyroMax, 0.2)
        XCTAssertNil(m.takeSummary(), "starts over after each summary")
    }

    func testDisplayAdaptsToTheDrivetrain() {
        let live: [String: Reading] = [
            "0C": Reading(label: "", value: 2100, unit: ""), "5B": Reading(label: "", value: 74, unit: "%"),
            "49": Reading(label: "", value: 30, unit: "%"), "2F": Reading(label: "", value: 60, unit: "%"),
        ]
        XCTAssertEqual(DriveDisplay.stats(.ev, live: live).map(\.label), ["Charge", "Pedal"], "no rpm or fuel on an EV")
        XCTAssertEqual(DriveDisplay.stats(.gas, live: live).map(\.label), ["RPM", "Throttle", "Fuel"], "only what the car reports")
        XCTAssertEqual(DriveDisplay.stats(.hybrid, live: live).map(\.label), ["Charge", "RPM", "Fuel"])
        XCTAssertTrue(DriveDisplay.stats(.ev, live: [:]).isEmpty)
    }

    func testDrivetrainComesFromTheVinDecode() {
        func car(ev: Bool = false, level: String? = nil, fuel: String? = nil) -> Vehicle {
            Vehicle(vin: "", make: nil, model: nil, year: nil, fuelType: fuel, electrificationLevel: level, isEv: ev, ownerId: "u")
        }
        XCTAssertEqual(car(ev: true).drivetrain, .ev)
        XCTAssertEqual(car(level: "PHEV (Plug-in Hybrid Electric Vehicle)").drivetrain, .hybrid)
        XCTAssertEqual(car(fuel: "Diesel").drivetrain, .diesel)
        XCTAssertEqual(car(fuel: "Gasoline").drivetrain, .gas)
    }

    func testCarScanOnlyReadsAndSweepsTheModuleThatAnswers() async {
        final class FakeLink: ElmLink {
            var sent: [String] = []
            private var header = "7DF"
            func open() async throws {}
            func close() {}
            func send(_ command: String, timeout: TimeInterval) async throws -> String {
                sent.append(command)
                if command.hasPrefix("ATSH ") { header = String(command.dropFirst(5)) }
                // Only module 7E4 speaks the battery request.
                if command == "0100" { return "7E8 06 41 00 BE 3F A8 13" }
                if header == "7E4", command.hasPrefix("2248") { return "7EC 05 62 48 01 12 34" }
                return command.hasPrefix("AT") ? "OK" : "NO DATA"
            }
        }
        let car = Vehicle(vin: "", make: "Ford", model: "Mustang Mach-E", year: 2021, fuelType: nil, isEv: true, ownerId: "u")
        let link = FakeLink()
        await CarScan.run(link: link, car: car) { _ in }

        // Read-only: adapter setup (AT), standard reads (01, 09) and service 22 reads. Nothing that writes or
        // starts a session (10, 27, 2E, 2F, 31, 04, 14...).
        let allowed = ["AT", "01", "09", "22"]
        XCTAssertTrue(link.sent.allSatisfy { c in allowed.contains { c.hasPrefix($0) } }, "unexpected request: \(link.sent)")
        XCTAssertEqual(link.sent.filter { $0 == "224801" }.count, 8 + 1 + 3, "8 module probes, the sweep's own 4801, and 3 repeats on the module that answers")
        XCTAssertTrue(link.sent.contains("22481F"), "swept the module that answered")
        XCTAssertEqual(link.sent.filter { $0 == "22481F" }.count, 1, "only that module is swept")
    }

    func testLiveScreenGroupsEverythingTheDriveCaptures() {
        func r(_ label: String, _ v: Double, _ unit: String) -> Reading { Reading(label: label, value: v, unit: unit) }
        let live = [
            "0D": r("Vehicle Speed", 50, "km/h"), "42": r("Control Module Voltage", 13.45, "V"),
            "7E4.4801": r("Mach-E battery module 4801 (raw)", 17410, "raw"),
            "gps.lat": r("Latitude", 37.123456, "°"), "gps.acc": r("GPS accuracy", 5, "m"), "gps.alt": r("GPS altitude", -1.8, "m"),
            "phone.baro_kpa": r("Air pressure", 100.99, "kPa"), "phone.accel_max": r("Phone acceleration (peak)", 0.13, "g"),
        ]
        let groups = LiveGroups.make(live)
        XCTAssertEqual(groups.map(\.title), ["Car", "Module 7E4 (raw values)", "Location", "Phone sensors"])
        XCTAssertEqual(groups[0].rows.map(\.key), ["0D", "42"])
        XCTAssertEqual(groups[2].rows.map(\.key), ["gps.lat", "gps.acc", "gps.alt"], "location in a fixed, readable order")
        XCTAssertEqual(groups[0].rows[1].value, "13.4", "one decimal for small numbers")
        XCTAssertEqual(groups[1].rows[0].value, "17410", "raw values as whole numbers")
        XCTAssertEqual(groups[2].rows[0].value, "37.12346", "coordinates in full")
        XCTAssertTrue(LiveGroups.make([:]).isEmpty)
    }

    func testCarPlayShowsThePlannedTripForAnyDrivetrain() {
        let dest = Place(id: "p", name: "Union Station", address: "", coordinate: .init(latitude: 34.05, longitude: -118.23))
        let origin = CLLocationCoordinate2D(latitude: 37.4, longitude: -121.9)
        func plan(charge: Bool) -> RoutePlan {
            RoutePlan(points: [], distanceKm: 573, durationSec: 5 * 3600 + 46 * 60,
                      stops: [PlanStop(type: charge ? "charging" : "fuel", name: "", coordinate: .init(latitude: 35.1, longitude: -119.3), minutes: 16, cost: 4.2)],
                      totalCost: 11.03, arrivalPercent: 38, arrivalIsCharge: charge, warnings: [])
        }
        let ev = CarPlayContent.plan(.ready(dest: dest, origin: origin, plan: plan(charge: true), assumption: nil))
        XCTAssertEqual(ev.title, "Union Station")
        XCTAssertTrue(ev.summary.contains(.init(label: "Arrive with", value: "38% charge")))
        XCTAssertEqual(ev.stops.first?.name, "Charge stop"); XCTAssertEqual(ev.stops.first?.detail, "16 min · $4.20")
        XCTAssertTrue(ev.stops[0].isCharge)

        let gas = CarPlayContent.plan(.ready(dest: dest, origin: origin, plan: plan(charge: false), assumption: nil))
        XCTAssertTrue(gas.summary.contains(.init(label: "Arrive with", value: "38% fuel")))
        XCTAssertEqual(gas.stops.first?.name, "Fuel stop"); XCTAssertFalse(gas.stops[0].isCharge)

        XCTAssertNotNil(CarPlayContent.plan(.idle).message, "no plan yet: say where to make one")
        XCTAssertEqual(CarPlayContent.plan(.failed(dest, message: "No fuel stops found", action: .retry)).message, "No fuel stops found")
    }

    func testAutoConnectUsesTheCarYouDroveLastThatHasAnAdapter() {
        // Newest drive first. The Mach-E was driven last, so it wins over the car added most recently.
        XCTAssertEqual(LastUsedCar.pick(carsWithAdapter: ["accord", "mache"], recentTripCars: ["mache", "accord"]), "mache")
        // A drive's car with no adapter can't be connected: fall to the next drive's car.
        XCTAssertEqual(LastUsedCar.pick(carsWithAdapter: ["accord"], recentTripCars: ["mache", "accord"]), "accord")
        // No drives yet: the first car with an adapter.
        XCTAssertEqual(LastUsedCar.pick(carsWithAdapter: ["accord", "mache"], recentTripCars: []), "accord")
        XCTAssertEqual(LastUsedCar.pick(carsWithAdapter: ["mache"], recentTripCars: [nil, "mache"]), "mache", "a drive with no car is skipped")
        XCTAssertNil(LastUsedCar.pick(carsWithAdapter: [], recentTripCars: ["mache"]), "no adapters, nothing to connect")
    }

    func testLeavingTheCarEndsOnlyTheDriveThatBeganWithIt() {
        let connected = Date(timeIntervalSince1970: 1000)
        // Started after CarPlay connected (auto-start or by hand in the car): ends with the car.
        XCTAssertTrue(CarSessionRule.shouldStop(driveBusy: true, driveRequestedAt: connected.addingTimeInterval(3), carConnectedAt: connected))
        // Started before CarPlay connected: not the car's to end.
        XCTAssertFalse(CarSessionRule.shouldStop(driveBusy: true, driveRequestedAt: connected.addingTimeInterval(-60), carConnectedAt: connected))
        // Nothing running, or never started: nothing to end.
        XCTAssertFalse(CarSessionRule.shouldStop(driveBusy: false, driveRequestedAt: connected.addingTimeInterval(3), carConnectedAt: connected))
        XCTAssertFalse(CarSessionRule.shouldStop(driveBusy: true, driveRequestedAt: nil, carConnectedAt: connected))
    }
}
