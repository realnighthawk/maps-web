import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = model.prefs
        NavigationStack {
            List {
                Section {
                    switch model.auth.state {
                    case .signedIn(_, let email):
                        LabeledContent("Signed in", value: email ?? "Account")
                        Button("Sign out", role: .destructive) { Task { await model.auth.signOut() } }
                    default:
                        Text("You're using the app without an account. Drives stay on this phone.").foregroundStyle(Tok.muted)
                        Button("Sign in") { Task { await model.auth.signOut() } }
                    }
                }
                Section {
                    Toggle("Start and end drives with my car", isOn: $prefs.autoStart)
                } header: { Text("Driving") } footer: {
                    Text("Connects to the adapter in the car you drove last when CarPlay connects, and ends that drive a minute after CarPlay disconnects. Without CarPlay, make Shortcuts automations: when your car connects run Start drive, when it disconnects run Stop drive.")
                }
                if case .signedIn = model.auth.state {
                    Section {
                        Toggle("Stream drives to my garage", isOn: $prefs.streaming)
                        Toggle("Wi-Fi only", isOn: $prefs.wifiOnly).disabled(!prefs.streaming)
                        LabeledContent("Waiting to upload", value: "\(model.sync.pending)")
                        Button {
                            Task { await model.sync.sync(manual: true) }
                        } label: {
                            HStack {
                                Text("Sync now")
                                Spacer()
                                switch model.sync.phase {
                                case .syncing: ProgressView()
                                case .done: Image(systemName: "checkmark").foregroundStyle(Tok.live)
                                case .failed(let m): Text(m).font(.caption).foregroundStyle(Tok.critical)
                                case .idle: EmptyView()
                                }
                            }
                        }
                    } header: { Text("Streaming") } footer: {
                        Text("Readings are saved on this phone first and uploaded when streaming is on.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tok.background)
            .navigationTitle("You")
        }
    }
}
