import CoreBluetooth
import SwiftUI

/// Remembers which adapter belongs to which car so the next drive connects with one tap.
enum AdapterPrefs {
    static func get(_ vehicleId: String?) -> UUID? {
        guard let vehicleId else { return nil }
        return UserDefaults.standard.string(forKey: "adapter.\(vehicleId)").flatMap(UUID.init)
    }
    static func name(_ vehicleId: String?) -> String? {
        vehicleId.flatMap { UserDefaults.standard.string(forKey: "adapter.name.\($0)") }
    }
    static func set(_ vehicleId: String?, _ id: UUID, name: String? = nil) {
        guard let vehicleId else { return }
        UserDefaults.standard.set(id.uuidString, forKey: "adapter.\(vehicleId)")
        UserDefaults.standard.set(name, forKey: "adapter.name.\(vehicleId)")
    }
    static func forget(_ vehicleId: String) {
        UserDefaults.standard.removeObject(forKey: "adapter.\(vehicleId)")
        UserDefaults.standard.removeObject(forKey: "adapter.name.\(vehicleId)")
    }
}

/// Pick the OBD adapter for a car. Adapters connect straight from the app (Bluetooth Low Energy), so there is no
/// pairing step and nothing to do in Settings.
struct ConnectSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onConnect: (FoundAdapter) -> Void

    var body: some View {
        NavigationStack {
            List {
                switch model.ble.state {
                case .poweredOff:
                    Section { Text("Turn on Bluetooth in Settings to find your adapter.").foregroundStyle(Tok.muted) }
                case .unauthorized:
                    Section {
                        Text("Garage needs Bluetooth permission to find your adapter.").foregroundStyle(Tok.muted)
                        Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                    }
                case .unsupported:
                    Section { Text("This device doesn't support Bluetooth.").foregroundStyle(Tok.muted) }
                default:
                    Section {
                        if model.ble.found.isEmpty {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Looking for adapters. Plug it into the car and turn the ignition on. No pairing in Settings needed.").foregroundStyle(Tok.muted)
                            }
                        }
                        ForEach(model.ble.found) { a in
                            Button { onConnect(a) } label: {
                                HStack {
                                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Tok.accent)
                                    Text(a.name)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Tok.muted)
                                }
                            }.foregroundStyle(Tok.text)
                        }
                    } header: { Text("Adapters nearby") } footer: {
                        Text("iPhone works with Bluetooth Low Energy adapters (for example Veepeak BLE+ or vLinker). Classic Bluetooth adapters can't connect to iOS.")
                    }
                }
            }
            .navigationTitle("Connect to your car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .onAppear { model.ble.startScan() }
        .onDisappear { model.ble.stopScan() }
    }
}
