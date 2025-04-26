import SwiftUI
import Foundation
// Views klasöründeki view'ları kullanmak için import gerekmez, ancak derleyiciye yardımcı olması için aşağıdaki gibi bir not ekleyebilirim:
// Eğer modül ayrımı varsa: @testable import mobil.Views
// Ancak SwiftUI'da aynı target içindeyse otomatik olarak bulur. Eğer bulamıyorsa, dosya yollarını ve target membership'ı kontrol et.

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
        .preferredColorScheme(.dark)
    }
}

struct MarketView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            CoinListView()
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
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.gray)
                            .padding(.leading, 10)
                        TextField("Search coins, news...", text: .constant(""))
                            .foregroundColor(.white)
                            .padding(10)
                        Button(action: {}) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.gray)
                                .padding(.trailing, 10)
                        }
                    }
                    .background(Color(UIColor.darkGray).opacity(0.3))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Popular Searches")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(["Bitcoin", "Ethereum", "XRP", "Solana", "Cardano"], id: \.self) { item in
                                        Text(item)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(AppColors.gold.opacity(0.15))
                                            .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            Text("Popular Categories")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(["DeFi", "NFTs", "Metaverse", "GameFi", "Layer-1", "Stablecoins"], id: \.self) { category in
                                    VStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(height: 110)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    Image(systemName: iconForCategory(category))
                                                        .font(.system(size: 36))
                                                        .foregroundColor(AppColors.gold)
                                                    Text(category)
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.white)
                                                }
                                            )
                                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
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
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
            case "DeFi": return "chart.line.uptrend.xyaxis"
            case "NFTs": return "square.grid.3x3.fill"
            case "Metaverse": return "headset"
            case "GameFi": return "gamecontroller.fill"
            case "Layer-1": return "square.stack.3d.up.fill"
            case "Stablecoins": return "dollarsign.circle.fill"
            default: return "questionmark.circle"
        }
    }
}

struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Total Portfolio Value")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.gray)
                        Text("$24,856.73")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.green)
                            Text("+3.2% ($789.23)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)), Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    HStack(spacing: 15) {
                        Button(action: {}) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.gold)
                                Text("Deposit")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.darkGray).opacity(0.5))
                            )
                        }
                        Button(action: {}) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.gold)
                                Text("Send")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.darkGray).opacity(0.5))
                            )
                        }
                        Button(action: {}) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.left.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.gold)
                                Text("Receive")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.darkGray).opacity(0.5))
                            )
                        }
                    }
                    .padding(.horizontal)
                    HStack {
                        Text("Your Assets")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {}) {
                            Text("See All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.gold)
                        }
                    }
                    .padding(.horizontal)
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(["Bitcoin", "Ethereum", "Solana"], id: \.self) { coin in
                                HStack {
                                    Image(systemName: iconForCoin(coin))
                                        .font(.system(size: 32))
                                        .foregroundColor(colorForCoin(coin))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(colorForCoin(coin).opacity(0.15))
                                        )
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(coin)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(symbolForCoin(coin))
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.gray)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(amountForCoin(coin))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(valueForCoin(coin))
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.darkGray).opacity(0.3))
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
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
    private func iconForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "bitcoinsign.circle.fill"
            case "Ethereum": return "ethereum"
            case "Solana": return "s.circle.fill"
            default: return "questionmark.circle"
        }
    }
    private func colorForCoin(_ coin: String) -> Color {
        switch coin {
            case "Bitcoin": return AppColors.gold
            case "Ethereum": return Color.purple
            case "Solana": return Color.green
            default: return Color.gray
        }
    }
    private func symbolForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "BTC"
            case "Ethereum": return "ETH"
            case "Solana": return "SOL"
            default: return "???"
        }
    }
    private func amountForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "0.42 BTC"
            case "Ethereum": return "3.21 ETH"
            case "Solana": return "24.5 SOL"
            default: return "0.00"
        }
    }
    private func valueForCoin(_ coin: String) -> String {
        switch coin {
            case "Bitcoin": return "$15,750.32"
            case "Ethereum": return "$7,452.26"
            case "Solana": return "$1,654.15"
            default: return "$0.00"
        }
    }
}

struct CommunityView: View {
    @Binding var showingLoginView: Bool
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 16) {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(1...5, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(AppColors.gold)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Crypto User \(index)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("\(index * 3) hours ago")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.gray)
                                        }
                                        Spacer()
                                        Button(action: {}) {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color.gray)
                                        }
                                    }
                                    Text(communityPostForIndex(index))
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .lineLimit(nil)
                                    if index % 2 == 0 {
                                        ZStack {
                                            Rectangle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(height: 180)
                                                .cornerRadius(16)
                                            HStack(spacing: 24) {
                                                Image(systemName: iconForCommunityPost(index))
                                                    .font(.system(size: 40))
                                                    .foregroundColor(AppColors.gold)
                                            }
                                        }
                                    }
                                    HStack(spacing: 20) {
                                        Button(action: {}) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "heart")
                                                    .font(.system(size: 16))
                                                Text("\(index * 15)")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color.gray)
                                        }
                                        Button(action: {}) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "bubble.right")
                                                    .font(.system(size: 16))
                                                Text("\(index * 3)")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color.gray)
                                        }
                                        Spacer()
                                        Button(action: {}) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color.gray)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)), Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "plus.bubble.fill")
                            .foregroundColor(AppColors.gold)
                            .imageScale(.large)
                    }
                }
            }
        }
    }
    private func communityPostForIndex(_ index: Int) -> String {
        let posts = [
            "Just bought some more #Bitcoin on the dip! Looking like a great entry point right now. What do you all think?",
            "Has anyone checked out the new DeFi protocol that launched yesterday? Impressive APY so far but I'm cautious.",
            "NFT market seems to be recovering slowly. I've seen some interesting collections gaining traction again. #NFTs #CryptoArt",
            "Ethereum gas fees are finally reasonable again! Managed to move some assets for under $5. #ETH",
            "What are your thoughts on the upcoming regulations? I think some clarity might actually be good for the market in the long run."
        ]
        return posts[min(index - 1, posts.count - 1)]
    }
    private func iconForCommunityPost(_ index: Int) -> String {
        let icons = ["bitcoinsign.circle.fill", "ethereum", "arrow.triangle.2.circlepath.circle.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis.circle.fill"]
        return icons[min(index % icons.count, icons.count - 1)]
    }
}

#Preview {
    MainTabView()
} 