import SwiftUI

@main
struct NavigationTabApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

struct HomeView: View {
    var body: some View {
        VStack {
            Text("Home Screen")
                .font(.largeTitle)
                .padding()

            NavigationLink("Go to Detail") {
                DetailView()
            }
            .padding()
        }
        .navigationTitle("Home")
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings Screen")
                .font(.largeTitle)
                .padding()

            NavigationLink("Go to About") {
                AboutView()
            }
            .padding()
        }
        .navigationTitle("Settings")
    }
}

struct DetailView: View {
    var body: some View {
        VStack {
            Text("Detail Screen")
                .font(.largeTitle)
                .padding()
        }
        .navigationTitle("Detail")
    }
}

struct AboutView: View {
    var body: some View {
        VStack {
            Text("About Screen")
                .font(.largeTitle)
                .padding()
        }
        .navigationTitle("About")
    }
}
