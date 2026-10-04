import MapKit
import SwiftData
import SwiftUI

/// The home screen: a map and nothing else but what the moment needs. Search sits on top; one card sits below
/// and changes with what's happening (idle, connecting, driving, a planned route, a drive under review).
struct MapHome: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var allCars: [Vehicle]
    let openGarage: () -> Void
    let openLive: () -> Void

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showSearch = false
    @State private var reviewSamples: [Sample] = []
    @State private var scrub = 0.0

    private var cars: [Vehicle] { allCars.filter { $0.ownerId == model.auth.ownerId } }
    private var car: Vehicle? { cars.first }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer.ignoresSafeArea(edges: .top)
            VStack(spacing: 10) {
                SearchPill(text: planTitle, onTap: { showSearch = true }, onClear: clearAll)
                HStack {
                    StatusChip(title: car?.displayName, state: model.drive.state, pending: model.sync.pending,
                               streaming: model.prefs.streaming && isSignedIn)
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .overlay(alignment: .trailing) {
            Button { withAnimation { camera = .userLocation(fallback: .automatic) } } label: {
                Image(systemName: "location.fill").frame(width: 48, height: 48)
                    .background(Tok.surface, in: Circle()).overlay(Circle().stroke(Tok.hairline))
            }
            .accessibilityLabel("Center on my location")
            .padding(.trailing, 16).padding(.bottom, 220).frame(maxHeight: .infinity, alignment: .bottom)
        }
        .safeAreaInset(edge: .bottom) {
            bottomCard.padding(.horizontal, 16).padding(.bottom, 8)
                .animation(.spring(duration: 0.35), value: cardKey)
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(cars: cars) { showSearch = false }
        }
        .onAppear { if model.location.authorization == .notDetermined { model.location.requestPermission() } }
        .onChange(of: model.location.authorization) { _, _ in model.plan.onLocationPermissionResult() }
        .onChange(of: planKey) { _, _ in fitRoute() }
        .task(id: model.reviewTrip?.id) { await loadReview() }
    }

    private var isSignedIn: Bool { if case .signedIn = model.auth.state { true } else { false } }

    // MARK: map

    private var mapLayer: some View {
        Map(position: $camera) {
            UserAnnotation()
            switch model.plan.plan {
            case .ready(let dest, _, let plan, _):
                MapPolyline(coordinates: plan.points).stroke(Tok.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                ForEach(plan.stops) { s in
                    Marker(s.name.isEmpty ? (s.isCharge ? "Charge" : "Fuel") : s.name,
                           systemImage: s.isCharge ? "bolt.fill" : "fuelpump.fill", coordinate: s.coordinate).tint(Tok.warn)
                }
                Marker(dest.name, coordinate: dest.coordinate).tint(Tok.critical)
            default:
                if let d = model.plan.plan.destination { Marker(d.name, coordinate: d.coordinate).tint(Tok.critical) }
            }
            if model.reviewTrip != nil, trail.count > 1 {
                MapPolyline(coordinates: trail).stroke(Tok.accent, lineWidth: 5)
                if let p = scrubPoint { Annotation("", coordinate: p) { Circle().fill(Tok.accent).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3)) } }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { MapCompass() }
    }

    private var trail: [CLLocationCoordinate2D] {
        reviewSamples.compactMap { s in s.lat.flatMap { a in s.lng.map { .init(latitude: a, longitude: $0) } } }
    }

    private var scrubPoint: CLLocationCoordinate2D? {
        guard !reviewSamples.isEmpty else { return nil }
        let s = reviewSamples[min(reviewSamples.count - 1, Int(scrub * Double(reviewSamples.count - 1)))]
        return s.lat.flatMap { a in s.lng.map { .init(latitude: a, longitude: $0) } }
    }

    /// Fits a planned route (or a drive under review) above the card that covers the bottom of the map.
    private func fitRoute() {
        var pts: [CLLocationCoordinate2D] = []
        if case .ready(_, let origin, let plan, _) = model.plan.plan { pts = plan.points + [origin] }
        else if let d = model.plan.plan.destination { pts = [d.coordinate] }
        else if model.reviewTrip != nil { pts = trail }
        guard let first = pts.first else { return }
        var rect = MKMapRect.null
        for c in pts { rect = rect.union(MKMapRect(origin: MKMapPoint(c), size: MKMapSize(width: 0, height: 0))) }
        if pts.count == 1 || rect.isNull {
            camera = .region(MKCoordinateRegion(center: first, latitudinalMeters: 3000, longitudinalMeters: 3000))
            return
        }
        // Pad all round, then give the south side extra room for the bottom card.
        let padX = rect.width * 0.25 + 400, padY = rect.height * 0.25 + 400
        rect = MKMapRect(x: rect.minX - padX, y: rect.minY - padY * 1.6, width: rect.width + padX * 2, height: rect.height + padY * 1.6 + padY * 3)
        withAnimation { camera = .rect(rect) }
    }

    private func loadReview() async {
        guard let t = model.reviewTrip else { reviewSamples = []; return }
        let id = t.id
        let ctx = model.container.mainContext
        reviewSamples = (try? ctx.fetch(FetchDescriptor<Sample>(predicate: #Predicate { $0.tripId == id }, sortBy: [SortDescriptor(\.at)]))) ?? []
        scrub = 1
        fitRoute()
    }

    // MARK: cards

    private var planKey: String {
        switch model.plan.plan {
        case .idle: "idle"
        case .planning(let p): "planning-\(p.id)"
        case .ready(let p, _, _, _): "ready-\(p.id)"
        case .needsVehicleDetails(let p, _): "details-\(p.id)"
        case .failed(let p, _, _): "failed-\(p.id)"
        }
    }

    private var cardKey: String { "\(model.drive.state)-\(planKey)-\(model.reviewTrip?.id ?? "")" }

    private var planTitle: String? { model.plan.plan.destination?.name ?? (model.reviewTrip != nil ? "Drive review" : nil) }

    private func clearAll() { model.plan.clear(); model.reviewTrip = nil }

    @ViewBuilder private var bottomCard: some View {
        switch model.drive.state {
        case .connecting(let title):
            Card { HStack(spacing: 14) { ProgressView(); VStack(alignment: .leading) { Text("Connecting to \(title)").font(.headline); Text("Keep the ignition on.").font(.subheadline).foregroundStyle(Tok.muted) } } }
        case .error(let message):
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Couldn't connect").font(.headline)
                    Text(message).font(.subheadline).foregroundStyle(Tok.muted)
                    Button("Try again") { model.drive.dismissError(); startDrive() }.buttonStyle(PrimaryButtonStyle())
                    HStack {
                        Button("Choose another adapter") { model.drive.dismissError(); openAdapterSetup() }
                        Spacer()
                        Button("Dismiss") { model.drive.dismissError() }
                    }.buttonStyle(QuietButtonStyle())
                }
            }
        case .live:
            DrivePill(openLive: openLive)
        case .idle:
            switch model.plan.plan {
            case .idle:
                if let t = model.reviewTrip {
                    TripReviewCard(trip: t, samples: reviewSamples, scrub: $scrub, carName: cars.first { $0.id == t.vehicleId }?.displayName) {
                        model.reviewTrip = nil
                    }
                } else {
                    startCard
                }
            default:
                RouteCard(openGarage: openGarage)
            }
        }
    }

    private var startCard: some View {
        VStack(spacing: 4) {
            Button { startDrive() } label: { Label("Start drive", systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            if cars.isEmpty {
                Button("Add your car first", action: openGarage).buttonStyle(QuietButtonStyle())
            }
        }
    }

    // MARK: driving

    /// The car's usual adapter connects straight away; anything else (first drive, adapter gone) opens the sheet.
    private func startDrive() {
        guard model.auth.ownerId != nil else { return }
        if model.quickStartDrive() { return }
        openAdapterSetup()
    }

    /// A car with no adapter yet is set up on its own screen; with no car at all, add one first.
    private func openAdapterSetup() {
        if let car { model.openCarId = car.id }
        openGarage()
    }
}

private struct SearchPill: View {
    let text: String?
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(Tok.muted)
            Text(text ?? "Where to?").font(.title3).foregroundStyle(text == nil ? Tok.muted : Tok.text).lineLimit(1)
            Spacer()
            if text != nil {
                Button(action: onClear) { Image(systemName: "xmark.circle.fill").foregroundStyle(Tok.muted).frame(width: 44, height: 44) }
                    .accessibilityLabel("Clear")
            }
        }
        .padding(.leading, 16).padding(.trailing, text == nil ? 16 : 4).frame(minHeight: 56)
        .background(Tok.surface, in: Capsule()).overlay(Capsule().stroke(Tok.hairline))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .contentShape(Capsule()).onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
    }
}

/// Which car, and is it recording / uploading? One pill answers both.
struct StatusChip: View {
    let title: String?
    let state: DriveState
    let pending: Int
    let streaming: Bool

    private var live: Bool { state == .live }
    private var label: String {
        if live { return streaming ? "Streaming" : "Saving on phone" }
        if case .connecting = state { return "Connecting" }
        if case .error = state { return "Connection error" }
        return pending > 0 ? "\(pending) to sync" : "Up to date"
    }
    private var dot: Color {
        if live && streaming { return Tok.live }
        if case .error = state { return Tok.critical }
        return pending > 0 && !live ? Tok.warn : Tok.muted
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 8, height: 8).animation(.easeInOut(duration: 0.25), value: dot)
            if let title { Text(title).font(.subheadline.weight(.semibold)).lineLimit(1) }
            Text(title == nil ? label : "·  \(label)").font(.footnote).foregroundStyle(title == nil ? Tok.text : Tok.muted).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Tok.surface, in: Capsule()).overlay(Capsule().stroke(Tok.hairline))
    }
}
