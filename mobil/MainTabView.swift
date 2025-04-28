import SwiftUI
import Foundation
import Combine
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
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedNews: NewsService.NewsItem? = nil
    @State private var showingNewsDetail = false
    @State private var animationType: CryptoSearchAnimation = .random()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    // Arama kutusu
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.gray)
                            .padding(.leading, 10)
                        TextField("Search coins or news...", text: $viewModel.searchText)
                            .foregroundColor(.white)
                            .padding(10)
                        if !viewModel.searchText.isEmpty {
                            Button(action: { viewModel.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.gray)
                                    .padding(.trailing, 10)
                            }
                        }
                    }
                    .background(Color(UIColor.darkGray).opacity(0.3))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                        Spacer()
                    } else if viewModel.searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .padding(.bottom, 4)
                            Text("Start typing to search coins or news")
                                .foregroundColor(.gray)
                                .font(.headline)
                                .padding(.bottom, 8)
                            CryptoSearchAnimationView(type: animationType)
                                .environmentObject(viewModel)
                                .frame(height: 4 * 44 + 3 * 12)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else if viewModel.filteredCoins.isEmpty && viewModel.filteredNews.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.yellow)
                            Text("No results found")
                                .foregroundColor(.gray)
                                .font(.headline)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                if !viewModel.filteredCoins.isEmpty {
                                    Text("Coins")
                                        .font(.title2.bold())
                                        .foregroundColor(AppColors.gold)
                                        .padding(.horizontal)
                                    ForEach(viewModel.filteredCoins) { coin in
                                        CoinSearchCard(coin: coin)
                                            .padding(.horizontal)
                                    }
                                }
                                if !viewModel.filteredNews.isEmpty {
                                    Text("News")
                                        .font(.title2.bold())
                                        .foregroundColor(AppColors.gold)
                                        .padding(.horizontal)
                                    ForEach(viewModel.filteredNews) { news in
                                        NewsSearchCard(news: news)
                                            .padding(.horizontal)
                                            .onTapGesture {
                                                selectedNews = news
                                                showingNewsDetail = true
                                            }
                                    }
                                }
                            }
                            .padding(.top)
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
            .onAppear {
                viewModel.loadInitialData()
                animationType = .random()
            }
            .sheet(isPresented: $showingNewsDetail) {
                if let news = selectedNews {
                    NewsDetailView(news: news)
                }
            }
        }
    }
}

// Animasyon tipi enumu
enum CryptoSearchAnimation {
    case bouncingLogos
    static func random() -> CryptoSearchAnimation { .bouncingLogos }
}

// Animasyon View: 4x4 sabit coin logolu matris (16 farklı coin)
struct CryptoSearchAnimationView: View {
    let type: CryptoSearchAnimation
    @EnvironmentObject var searchViewModel: SearchViewModel
    // 16 farklı popüler coin için logo URL'leri ve isimleri
    let coinData: [(name: String, symbol: String, url: String)] = [
        ("Bitcoin", "BTC", "https://assets.coingecko.com/coins/images/1/large/bitcoin.png"),
        ("Ethereum", "ETH", "https://assets.coingecko.com/coins/images/279/large/ethereum.png"),
        ("XRP", "XRP", "https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png"),
        ("Dogecoin", "DOGE", "https://assets.coingecko.com/coins/images/5/large/dogecoin.png"),
        ("Cardano", "ADA", "https://assets.coingecko.com/coins/images/975/large/cardano.png"),
        ("Binance Coin", "BNB", "https://assets.coingecko.com/coins/images/825/large/binance-coin-logo.png"),
        ("Solana", "SOL", "https://assets.coingecko.com/coins/images/4128/large/solana.png"),
        ("USD Coin", "USDC", "https://assets.coingecko.com/coins/images/6319/large/USD_Coin_icon.png"),
        ("Litecoin", "LTC", "https://assets.coingecko.com/coins/images/2/large/litecoin.png"),
        ("Polkadot", "DOT", "https://assets.coingecko.com/coins/images/12171/large/polkadot.png"),
        ("TRON", "TRX", "https://assets.coingecko.com/coins/images/1094/large/tron-logo.png"),
        ("Avalanche", "AVAX", "https://assets.coingecko.com/coins/images/4685/large/avalanche.png"),
        ("Chainlink", "LINK", "https://assets.coingecko.com/coins/images/877/large/chainlink-new-logo.png"),
        ("Polygon", "MATIC", "https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png"),
        ("Shiba Inu", "SHIB", "https://assets.coingecko.com/coins/images/11939/large/shiba.png"),
        ("Uniswap", "UNI", "https://assets.coingecko.com/coins/images/12504/large/uniswap-uni.png"),
        ("Aptos", "APT", "https://assets.coingecko.com/coins/images/26455/large/aptos_round.png")
    ]
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<16, id: \ .self) { i in
                let coin = coinData[i]
                ZStack {
                    Circle()
                        .fill(AppColors.gold.opacity(0.13))
                        .frame(width: 44, height: 44)
                    AsyncImage(url: URL(string: coin.url)) { phase in
                        switch phase {
                        case .empty:
                            Color.clear.frame(width: 26, height: 26)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 26, height: 26)
                        case .failure:
                            Image(systemName: "questionmark.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 26, height: 26)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .onTapGesture {
                    // Kısayol: Coin adına veya sembolüne göre arama
                    searchViewModel.searchText = coin.symbol
                }
                .accessibilityLabel(coin.name)
            }
        }
        .frame(height: 4 * 44 + 3 * 12)
    }
}

struct CoinSearchCard: View {
    let coin: Coin
    var body: some View {
        HStack(spacing: 12) {
            if let url = URL(string: coin.image), !coin.image.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "bitcoinsign.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: "bitcoinsign.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(coin.symbol)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(coin.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(coin.formattedChange)
                    .font(.subheadline)
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(AppColors.darkGray)
        .cornerRadius(12)
    }
}

struct NewsSearchCard: View {
    let news: NewsService.NewsItem
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: news.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(UIColor.darkGray).opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color(UIColor.darkGray).opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.gold)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(news.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(news.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                Text(news.source)
                    .font(.caption)
                    .foregroundColor(AppColors.gold)
            }
            Spacer()
        }
        .padding(12)
        .background(AppColors.darkGray)
        .cornerRadius(12)
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
