import SwiftData
import SwiftUI

/// Where to? Destination results, and (when the box is empty) your recent drives, as in Google Maps.
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Trip.startedAt, order: .reverse) private var allTrips: [Trip]
    let cars: [Vehicle]
    let onDone: () -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private var trips: [Trip] { allTrips.filter { $0.ownerId == model.auth.ownerId && $0.status != TripStatus.active.rawValue }.prefix(30).map { $0 } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onDone) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Back")
                TextField("Where to?", text: $query)
                    .focused($focused).submitLabel(.search).autocorrectionDisabled().font(.title3)
                    .onChange(of: query) { _, q in model.plan.onQuery(q) }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Tok.muted).frame(width: 44, height: 44) }
                        .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 8).frame(minHeight: 56)
            .background(Tok.surface, in: Capsule()).overlay(Capsule().stroke(Tok.hairline))
            .padding(.horizontal, 16).padding(.vertical, 8)

            List {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    if trips.isEmpty {
                        Text("Type a place or an address. Your recent drives will show up here.").foregroundStyle(Tok.muted)
                            .listRowBackground(Color.clear)
                    } else {
                        Section("Recent drives") {
                            ForEach(trips) { t in
                                Button {
                                    model.plan.clear(); model.reviewTrip = t; onDone()
                                } label: { TripRow(trip: t, carName: cars.first { $0.id == t.vehicleId }?.displayName) }
                            }
                        }
                    }
                } else {
                    switch model.plan.search {
                    case .idle: EmptyView()
                    case .loading: HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                    case .error(let m): Text(m).foregroundStyle(Tok.muted).listRowBackground(Color.clear)
                    case .results(let places):
                        if places.isEmpty { Text("No places found.").foregroundStyle(Tok.muted).listRowBackground(Color.clear) }
                        ForEach(places) { p in
                            Button {
                                model.reviewTrip = nil; model.plan.choose(p); onDone()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(Tok.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name).font(.headline).foregroundStyle(Tok.text)
                                        Text(p.address).font(.subheadline).foregroundStyle(Tok.muted).lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden).scrollDismissesKeyboard(.immediately)
        }
        .background(Tok.background.ignoresSafeArea())
        .onAppear { focused = true; model.plan.beginSearch() }
    }
}

struct TripRow: View {
    let trip: Trip
    let carName: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath").font(.title3).foregroundStyle(Tok.muted).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline).foregroundStyle(Tok.text)
                let mins = Int(((trip.endedAt ?? trip.startedAt).timeIntervalSince(trip.startedAt) / 60).rounded())
                Text([carName, "\(max(mins, 1)) min"].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(Tok.muted)
            }
        }
    }
}
