import SwiftData
import SwiftUI

struct GarageView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var all: [Vehicle]
    @State private var adding = false
    @State private var removing: Vehicle?
    @State private var path: [String] = []

    private var cars: [Vehicle] { all.filter { $0.ownerId == model.auth.ownerId } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if cars.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Add your first car").font(.title3.bold())
                                Text("Enter its VIN and we'll fill in the make, model and year. Then pair an OBD adapter to see live data on the map.")
                                    .foregroundStyle(Tok.muted)
                                Button("Add car") { adding = true }.buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
                            }
                        }
                    } else {
                        ForEach(cars) { car in
                            NavigationLink(value: car.id) { CarRow(car: car) { removing = car } }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Tok.background)
            .navigationTitle("Garage")
            .navigationDestination(for: String.self) { id in
                if let car = cars.first(where: { $0.id == id }) { VehicleDetailView(car: car) }
            }
            // The map sends you here when a drive can't start because the car has no adapter yet.
            .onChange(of: model.openCarId) { _, id in
                guard let id else { return }
                path = [id]
                model.openCarId = nil
            }
            .toolbar {
                if !cars.isEmpty {
                    ToolbarItem(placement: .primaryAction) { Button("Add car", systemImage: "plus") { adding = true } }
                }
            }
            .sheet(isPresented: $adding) { AddVehicleSheet() }
            // Deletes that did not reach the server last time (offline, signed out) go through now.
            .task { await model.carRemoval.flush() }
            .confirmationDialog("Remove \(removing?.displayName ?? "car")?", isPresented: .constant(removing != nil),
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let v = removing {
                        model.carRemoval.queue(id: v.id, vin: v.vin)
                        context.delete(v)
                        try? context.save()
                    }
                    removing = nil
                }
                Button("Keep", role: .cancel) { removing = nil }
            } message: {
                Text("It will leave your garage, and its recorded drives will no longer be listed here.")
            }
        }
    }
}

private struct CarRow: View {
    let car: Vehicle
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: car.isEv ? "bolt.car.fill" : "car.fill")
                .font(.title3).foregroundStyle(Tok.accent)
                .frame(width: 48, height: 48).background(Tok.raised, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(car.displayName).font(.headline).lineLimit(2)
                Text(car.details).font(.subheadline).foregroundStyle(Tok.muted).lineLimit(2)
                if !car.vin.isEmpty { Text("VIN \(car.vin)").font(.caption).foregroundStyle(Tok.muted) }
                // The card is the way in to connecting the adapter, so say where it stands.
                Text(AdapterPrefs.get(car.id) == nil ? "Connect OBD adapter" : "Adapter: \(AdapterPrefs.name(car.id) ?? "connected before")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AdapterPrefs.get(car.id) == nil ? Tok.accent : Tok.muted).lineLimit(1).padding(.top, 2)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Remove car", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(car.displayName)")
        }
        .padding(16)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Tok.hairline))
    }
}

/// Add a car by VIN: public lookup fills in the rest. Manual entry is the fallback when the lookup can't help.
struct AddVehicleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vinText = ""
    @State private var looking = false
    @State private var found: VehicleMetadata?
    @State private var note: String?
    @State private var nickname = ""
    @State private var manual = false
    @State private var make = ""
    @State private var carModel = ""
    @State private var year = ""
    @State private var isEv = false

    private var vin: String { VinDecoder.normalize(vinText) }

    var body: some View {
        NavigationStack {
            Form {
                if !manual {
                    Section {
                        TextField("17-character VIN", text: $vinText)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .onChange(of: vinText) { _, _ in found = nil; note = nil }
                    } footer: {
                        Text(note ?? "It's on the driver-side dashboard, by the windshield, and on your registration.")
                            .foregroundStyle(note == nil ? Tok.muted : Tok.warn)
                    }
                    if let f = found {
                        Section("We found") {
                            Text([f.year.map(String.init), f.make, f.model].compactMap { $0 }.joined(separator: " ")).font(.headline)
                            Text(f.isEv ? "Electric" : (f.fuelType ?? "Combustion")).foregroundStyle(Tok.muted)
                            TextField("Nickname (optional)", text: $nickname)
                        }
                    }
                    Section {
                        if let f = found {
                            Button("Add to garage") { save(f) }
                        } else {
                            Button { Task { await lookUp() } } label: {
                                if looking { ProgressView() } else { Text("Look up") }
                            }.disabled(!VinDecoder.isValid(vin) || looking)
                        }
                        Button("Enter details by hand") { manual = true }.foregroundStyle(Tok.muted)
                    }
                } else {
                    Section("Car") {
                        TextField("Nickname (optional)", text: $nickname)
                        TextField("Make", text: $make)
                        TextField("Model", text: $carModel)
                        TextField("Year", text: $year).keyboardType(.numberPad)
                        Toggle("Electric", isOn: $isEv)
                    }
                    Section {
                        TextField("VIN (needed for route planning)", text: $vinText)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    }
                    Section {
                        Button("Add to garage") { saveManual() }.disabled(make.isEmpty && carModel.isEmpty)
                        Button("Look up by VIN instead") { manual = false }.foregroundStyle(Tok.muted)
                    }
                }
            }
            .navigationTitle("Add car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func lookUp() async {
        looking = true
        defer { looking = false }
        switch await VinDecoder.decode(vin) {
        case .found(let m, let ok):
            found = m
            if !ok { note = "This VIN decoded, but its check digit doesn't match. Double-check it for typos." }
        case .unknown(let why): note = why
        case .unavailable(let why): note = "\(why) You can enter the details by hand."
        }
    }

    private func save(_ m: VehicleMetadata) {
        guard let owner = model.auth.ownerId else { return }
        model.carRemoval.cancel(vin: m.vin)
        context.insert(Vehicle(vin: m.vin, make: m.make, model: m.model, year: m.year, fuelType: m.fuelType,
                               electrificationLevel: m.electrificationLevel, isEv: m.isEv,
                               nickname: nickname.isEmpty ? nil : nickname, ownerId: owner))
        try? context.save()
        dismiss()
    }

    private func saveManual() {
        guard let owner = model.auth.ownerId else { return }
        context.insert(Vehicle(vin: VinDecoder.isValid(vin) ? vin : "", make: make.isEmpty ? nil : make,
                               model: carModel.isEmpty ? nil : carModel, year: Int(year), fuelType: nil, isEv: isEv,
                               nickname: nickname.isEmpty ? nil : nickname, ownerId: owner))
        try? context.save()
        dismiss()
    }
}
