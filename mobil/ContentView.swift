import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                CoinListView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Markets")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: ProfileView()) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppColors.gold)
                                    .font(.system(size: 24))
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Markets")
            }
            .tag(0)
            
            NavigationView {
                Text("News")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("News")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: ProfileView()) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppColors.gold)
                                    .font(.system(size: 24))
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "newspaper.fill")
                Text("News")
            }
            .tag(1)
            
            NavigationView {
                Text("Search")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Search")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: ProfileView()) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppColors.gold)
                                    .font(.system(size: 24))
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(2)
            
            NavigationView {
                Text("Portfolio")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Portfolio")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: ProfileView()) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppColors.gold)
                                    .font(.system(size: 24))
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Portfolio")
            }
            .tag(3)
            
            NavigationView {
                Text("Community")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Community")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: ProfileView()) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppColors.gold)
                                    .font(.system(size: 24))
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("Community")
            }
            .tag(4)
        }
        .accentColor(AppColors.gold)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.backgroundColor = UIColor(AppColors.darkGray)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithOpaqueBackground()
            navigationBarAppearance.backgroundColor = UIColor(AppColors.darkGray)
            navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().standardAppearance = navigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
} 