import SwiftUI

/// One car, in full: what it is, and its OBD adapter. This is where an adapter is connected: it connects straight
/// from the app, so there is no pairing in the phone's Bluetooth settings.
struct VehicleDetailView: View {
    @Environment(AppModel.self) private var model
    let car: Vehicle
    @State private var picking = false
    @State private var showLog = false
    /// Bumped when an adapter is remembered or forgotten, so this screen re-reads it.
    @State private var tick = 0

    private var adapterId: UUID? { _ = tick; return AdapterPrefs.get(car.id) }
    private var adapterName: String? { _ = tick; return AdapterPrefs.name(car.id) }
    private var state: DriveState { model.drive.state }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                adapterCard
                Button("Try a demo drive") { model.drive.start(source: SimulatedSource(ev: car.isEv), title: "the demo", vehicle: car) }
                    .buttonStyle(QuietButtonStyle()).disabled(model.drive.busy)
                Text("A demo drive records simulated readings, so you can see the app work without an adapter.")
                    .font(.footnote).foregroundStyle(Tok.muted)
                if adapterId != nil {
                    Button {
                        Task { await model.scanCar(car); showLog = true }
                    } label: {
                        Text(model.scanning ? model.scanProgress : "Scan car for battery data")
                    }
                    .buttonStyle(QuietButtonStyle()).disabled(model.scanning || model.drive.busy)
                    Text("Reads what your car reports and saves it in the connection log, so battery data can be set up for your model. Read-only, takes a minute or two. Turn the car on first.")
                        .font(.footnote).foregroundStyle(Tok.muted)
                }
                Button("Connection log") { showLog = true }.buttonStyle(QuietButtonStyle())
            }
            .padding(20)
        }
        .background(Tok.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLog) { DiagLogView() }
        .sheet(isPresented: $picking) {
            ConnectSheet { a in
                AdapterPrefs.set(car.id, a.id, name: a.name)
                tick += 1
                picking = false
                model.startDrive(car: car)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: car.isEv ? "bolt.car.fill" : "car.fill")
                .font(.title).foregroundStyle(Tok.accent)
                .frame(width: 64, height: 64).background(Tok.raised, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(car.displayName).font(.title2.bold()).lineLimit(2)
                Text([car.isEv ? "Electric" : (car.fuelType ?? "Combustion"), car.year.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                    .foregroundStyle(Tok.muted)
                if !car.vin.isEmpty { Text("VIN \(car.vin)").font(.caption).foregroundStyle(Tok.muted) }
            }
        }
    }

    private var adapterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OBD adapter").font(.headline)
            if adapterId == nil {
                Text("Plug your adapter into the car's OBD port, turn the ignition on, then connect it here. It connects right in the app. You don't need to pair it in Settings.")
                    .foregroundStyle(Tok.muted)
                Button("Connect adapter") { picking = true }.buttonStyle(PrimaryButtonStyle())
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Tok.accent)
                        .frame(width: 40, height: 40).background(Tok.raised, in: Circle())
                    VStack(alignment: .leading) {
                        Text(adapterName ?? "Your adapter").font(.headline).lineLimit(1)
                        Text("Bluetooth LE").font(.subheadline).foregroundStyle(Tok.muted)
                    }
                }
                switch state {
                case .live:
                    statusLine("Live", model.drive.speedKmh.map(Speed.text) ?? "", Tok.live)
                    Button("End drive") { model.drive.stop() }.buttonStyle(PrimaryButtonStyle(destructive: true))
                case .connecting:
                    HStack(spacing: 10) { ProgressView(); Text("Connecting. Keep the ignition on.").font(.subheadline) }
                case .idle, .error:
                    if case .error(let m) = state { statusLine("Couldn't connect", m, Tok.critical) }
                    else { statusLine("Ready", "Starts a drive when connected.", Tok.muted) }
                    Button { model.drive.dismissError(); if !model.startDrive(car: car) { picking = true } } label: {
                        Text({ if case .error = state { "Try again" } else { "Connect" } }())
                    }.buttonStyle(PrimaryButtonStyle()).disabled(model.scanning)
                    HStack {
                        Button("Change adapter") { picking = true }
                        Spacer()
                        Button("Forget", role: .destructive) { AdapterPrefs.forget(car.id); tick += 1 }
                    }.buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Tok.hairline))
    }

    private func statusLine(_ title: String, _ detail: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(.semibold))
                if !detail.isEmpty { Text(detail).font(.subheadline).foregroundStyle(Tok.muted) }
            }
        }
    }
}

/// What happened on the last connection attempts, to copy or share when an adapter won't connect.
struct DiagLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var lines = Diag.lines

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(lines.isEmpty ? "Nothing yet. Try connecting, then come back here." : lines.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16).textSelection(.enabled)
            }
            .navigationTitle("Connection log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") { lines = Diag.lines }
                    ShareLink(item: lines.joined(separator: "\n"))
                }
            }
        }
    }
}
