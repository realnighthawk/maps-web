import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.auth.state {
            case .loading: Tok.background.ignoresSafeArea()
            case .signedOut: WelcomeView()
            case .guest, .signedIn: Shell()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.auth.state)
        .onChange(of: model.auth.state) { _, new in
            if case .signedIn(let id, _) = new { model.adoptGuestData(into: id) }
        }
    }
}

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "car.side.fill").font(.system(size: 44)).foregroundStyle(Tok.accent)
            Text("Your car, on the map.").font(.largeTitle.bold()).padding(.top, 20)
            Text("Plan routes that know your fuel, record every drive from your OBD adapter, and keep it all in your own garage.")
                .font(.body).foregroundStyle(Tok.muted).padding(.top, 8)
            Spacer()
            if let error { Text(error).font(.callout).foregroundStyle(Tok.critical).padding(.bottom, 12) }
            Button {
                busy = true
                Task { error = await model.auth.signInWithGoogle(); busy = false }
            } label: {
                if busy { ProgressView().tint(Tok.onAccent) } else { Text("Continue with Google") }
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(busy)
            Button("Look around without an account") { model.auth.continueAsGuest() }
                .buttonStyle(QuietButtonStyle()).frame(maxWidth: .infinity).padding(.top, 8)
            Text("Without an account, drives stay on this phone and route planning is off.")
                .font(.footnote).foregroundStyle(Tok.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Tok.background.ignoresSafeArea())
    }
}

private enum Tab: Hashable { case map, live, garage, you }

struct Shell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var tab: Tab = .map

    var body: some View {
        TabView(selection: $tab) {
            MapHome(openGarage: { tab = .garage }, openLive: { tab = .live })
                .tabItem { Label("Map", systemImage: "map") }.tag(Tab.map)
            LiveView(openGarage: { tab = .garage })
                .tabItem { Label("Live", systemImage: "gauge.with.needle") }.tag(Tab.live)
            GarageView()
                .tabItem { Label("Garage", systemImage: "car") }.tag(Tab.garage)
            AccountView()
                .tabItem { Label("You", systemImage: "person") }.tag(Tab.you)
        }
        .onChange(of: phase) { _, p in if p == .active { Task { await model.sync.sync() } } }
        .task { await model.sync.sync() }
    }
}
