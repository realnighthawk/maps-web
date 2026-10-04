import SwiftUI

/// The drive, in full: speed and the readings that matter for this kind of car at the top, then every reading the
/// drive captures (the car's, its model-specific ones, the location fix and the phone's sensors), exactly as streamed.
struct LiveView: View {
    @Environment(AppModel.self) private var model
    let openGarage: () -> Void

    var body: some View {
        let d = model.drive
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch d.state {
                    case .live: liveContent
                    case .connecting(let what): statusCard("Connecting to \(what)…", "Keep the car on.", spinner: true)
                    case .error(let message): errorCard(message)
                    case .idle: idleCard
                    }
                }
                .padding(20)
            }
            .background(Tok.background)
            .navigationTitle("Live")
            .safeAreaInset(edge: .bottom) {
                if d.state == .live {
                    Button("Stop drive") { d.stop() }
                        .buttonStyle(PrimaryButtonStyle(destructive: true))
                        .padding(.horizontal, 20).padding(.vertical, 8).background(.bar)
                }
            }
        }
    }

    // MARK: while driving

    @ViewBuilder private var liveContent: some View {
        let d = model.drive
        let drivetrain = d.vehicle?.drivetrain ?? .gas
        let stats = DriveDisplay.stats(drivetrain, live: d.live)

        VStack(alignment: .leading, spacing: 14) {
            if let name = d.vehicle?.displayName { Text(name).font(.subheadline).foregroundStyle(Tok.muted) }
            HStack(alignment: .firstTextBaseline) {
                Text(d.speedKmh.map { "\(Speed.value($0))" } ?? "–")
                    .font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit()
                Text(Speed.unit.symbol).foregroundStyle(Tok.muted)
                Spacer()
                if let s = d.startedAt {
                    TimelineView(.periodic(from: s, by: 1)) { ctx in
                        Text(Duration.seconds(ctx.date.timeIntervalSince(s)).formatted(.time(pattern: .minuteSecond)))
                            .monospacedDigit().foregroundStyle(Tok.muted)
                    }
                }
            }
            HStack(spacing: 8) {
                badge(model.prefs.streaming && isSignedIn ? "Streaming" : "Saving on phone", color: model.prefs.streaming && isSignedIn ? Tok.live : Tok.muted)
                if model.sync.pending > 0 { badge("\(model.sync.pending) waiting to upload", color: Tok.warn) }
            }
            if !stats.isEmpty {
                HStack { ForEach(stats, id: \.label) { stat($0) } }
            } else {
                Text(d.live.isEmpty ? "Reading your car…" : "Your car shares only its speed over the OBD port.")
                    .font(.subheadline).foregroundStyle(Tok.muted)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundRectangle(radius: 24))

        Text("Everything below is recorded and streamed with the drive.").font(.footnote).foregroundStyle(Tok.muted)

        ForEach(LiveGroups.make(d.live)) { group in
            VStack(alignment: .leading, spacing: 0) {
                Text(group.title).font(.headline).padding(.bottom, 8)
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { Divider().overlay(Tok.hairline) }
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label).font(.subheadline).foregroundStyle(Tok.text)
                        Spacer(minLength: 12)
                        Text(row.value).font(.subheadline.weight(.semibold)).monospacedDigit()
                        if !row.unit.isEmpty { Text(row.unit).font(.caption).foregroundStyle(Tok.muted).frame(minWidth: 28, alignment: .leading) }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Tok.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundRectangle(radius: 20))
        }
    }

    private var isSignedIn: Bool { if case .signedIn = model.auth.state { true } else { false } }

    private func badge(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 6).background(Tok.raised, in: Capsule())
    }

    private func stat(_ s: DriveStat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(s.label).font(.caption).foregroundStyle(Tok.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: not driving

    private var idleCard: some View {
        Card {
            Text("No drive running").font(.title3.bold())
            Text("Start a drive to see everything your car and phone report, live. It's recorded and streamed as you go.")
                .foregroundStyle(Tok.muted)
            Button("Start drive") { if !model.quickStartDrive() { openAdapterSetup() } }
                .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
        }
    }

    private func statusCard(_ title: String, _ detail: String, spinner: Bool) -> some View {
        Card {
            HStack(spacing: 14) {
                if spinner { ProgressView() }
                VStack(alignment: .leading) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(Tok.muted) }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Card {
            Text("Couldn't connect").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Tok.muted)
            Button("Try again") { model.drive.dismissError(); if !model.quickStartDrive() { openAdapterSetup() } }
                .buttonStyle(PrimaryButtonStyle())
            Button("Dismiss") { model.drive.dismissError() }.buttonStyle(QuietButtonStyle())
        }
    }

    /// A car with no adapter yet is set up on its own screen.
    private func openAdapterSetup() {
        if let car = model.ownedVehicles().first { model.openCarId = car.id }
        openGarage()
    }
}

/// A hairline outline matching the app's cards.
private struct RoundRectangle: View {
    let radius: CGFloat
    var body: some View { RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Tok.hairline) }
}
