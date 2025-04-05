import SwiftUI

struct MainTabView: View {
    @State private var showingLoginView = false
    
    var body: some View {
        TabView {
            MarketView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Markets")
                }
            
            NewsView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("News")
                }
            
            SearchView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            PortfolioView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Portfolio")
                }
            
            CommunityView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Community")
                }
        }
        .accentColor(AppColors.gold)
        .sheet(isPresented: $showingLoginView) {
            LoginView(isPresented: $showingLoginView)
        }
    }
}

struct MarketView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            Text("Markets")
                .navigationTitle("Markets")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColors.gold)
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

struct SearchView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            Text("Search")
                .navigationTitle("Search")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColors.gold)
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            Text("Portfolio")
                .navigationTitle("Portfolio")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColors.gold)
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

struct CommunityView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            Text("Community")
                .navigationTitle("Community")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColors.gold)
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

#Preview {
    MainTabView()
} 