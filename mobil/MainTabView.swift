import SwiftUI
import Foundation
import Combine
import Charts
import UIKit
import SafariServices

// Image önbellek sınıfı
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 50 // 50 MB
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
}

// Önbellekli görüntü yükleme görünümü
struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    
    init(url: URL?, scale: CGFloat = 1.0, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        Group {
            if let cachedImage = getCachedImage() {
                content(.success(Image(uiImage: cachedImage)))
            } else if let image = loadedImage {
                content(.success(Image(uiImage: image)))
            } else {
                content(.empty)
                    .onAppear {
                        if !isLoading {
                            loadImage()
                        }
                    }
            }
        }
    }
    
    private func getCachedImage() -> UIImage? {
        guard let url = url else { return nil }
        return ImageCache.shared.get(forKey: url.absoluteString)
    }
    
    private func loadImage() {
        guard let url = url else { return }
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    ImageCache.shared.set(image, forKey: url.absoluteString)
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// UIImage dönüşümü için uzantı
extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        if let view = controller.view {
            let size = view.intrinsicContentSize
            view.bounds = CGRect(origin: .zero, size: size)
            view.backgroundColor = .clear
            
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
        return nil
    }
}

// MARK: - Custom SafariView
struct CustomSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// SearchViewModel modelini ekleyelim
class SearchViewModelLight: ObservableObject {
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var coins: [Coin] = []
    @Published var news: [NewsItem] = []
    @Published var filteredCoins: [Coin] = []
    @Published var filteredNews: [NewsItem] = []
    @Published var selectedCoin: Coin? = nil
    
    // Coin listesi
    @Published var coinNames: [String] = [
        "Bitcoin", "Ethereum", "Cardano", "Solana",
        "Ripple", "Polkadot", "Avalanche", "Dogecoin",
        "Shiba Inu", "Litecoin", "Chainlink", "BNB",
        "Uniswap", "Polygon", "Tron", "Cosmos"
    ]
    
    // Logo önbelleği başlangıçta kullanılacak sabit URL'ler
    @Published var initialLogos: [String: String] = [
        "Bitcoin": "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
        "Ethereum": "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
        "Cardano": "https://assets.coingecko.com/coins/images/975/large/cardano.png",
        "Solana": "https://assets.coingecko.com/coins/images/4128/large/solana.png",
        "Ripple": "https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png",
        "Polkadot": "https://assets.coingecko.com/coins/images/12171/large/polkadot.png",
        "Avalanche": "https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png",
        "Dogecoin": "https://assets.coingecko.com/coins/images/5/large/dogecoin.png",
        "Shiba Inu": "https://assets.coingecko.com/coins/images/11939/large/shiba.png",
        "Litecoin": "https://assets.coingecko.com/coins/images/2/large/litecoin.png",
        "Chainlink": "https://assets.coingecko.com/coins/images/877/large/chainlink-new-logo.png",
        "BNB": "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png",
        "Polygon": "https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png",
        "Tron": "https://assets.coingecko.com/coins/images/1094/large/tron-logo.png",
        "Cosmos": "https://assets.coingecko.com/coins/images/1481/large/cosmos_hub.png",
        "Uniswap": "https://assets.coingecko.com/coins/images/12504/large/uniswap-uni.png"
    ]
    
    func loadInitialData() {
        isLoading = true
        Task {
            await fetchCoins()
            await fetchNews()
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    func fetchCoins() async {
        do {
            let fetchedCoins = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
            self.coins = fetchedCoins
            
            // Coin isimlerini ve logolarını güncelle
            let names = fetchedCoins.map { $0.name }
            if !names.isEmpty {
                self.coinNames = names.count >= 16 ? Array(names.prefix(16)) : names
            }
            
            // URL'leri güncelle
            var logos: [String: String] = [:]
            for coin in fetchedCoins {
                logos[coin.name] = coin.image
            }
            if !logos.isEmpty {
                self.initialLogos = logos
            }
            
        } catch {
            print("Coin verileri yüklenemedi: \(error)")
        }
    }
    
    @MainActor
    func fetchNews() async {
        do {
            let fetchedNews = try await APIService.shared.fetchNews()
            self.news = fetchedNews
        } catch {
            print("Haber verileri yüklenemedi: \(error)")
        }
    }
    
    func searchCoins(_ query: String) {
        if query.isEmpty {
            filteredCoins = []
            filteredNews = []
        } else {
            filteredCoins = coins.filter { $0.name.lowercased().contains(query.lowercased()) || $0.symbol.lowercased().contains(query.lowercased()) }
            filteredNews = news.filter { $0.title.lowercased().contains(query.lowercased()) }
        }
    }
}

// CryptoSearchAnimation enumunu ekleyelim
enum CryptoSearchAnimation {
    case bouncingLogos
    static func random() -> CryptoSearchAnimation { .bouncingLogos }
}

// MARK: - App Colors Theme
// AppColorsTheme modeli mobil/Colors.swift dosyasında zaten tanımlı
/*
struct AppColorsTheme {
    static let gold = Color(red: 0.984, green: 0.788, blue: 0.369)
    static let darkGray = Color(UIColor.darkGray)
    static let black = Color.black
}
*/

// NewsItem modeli zaten Models/NewsItem.swift'te tanımlı
/*
struct NewsItem: Identifiable, Hashable, Comparable {
    let id: String
    let title: String
    let description: String
    let url: String
    let imageUrl: String
    let source: String
    let publishedAt: String
    
    static func < (lhs: NewsItem, rhs: NewsItem) -> Bool {
        // ISO 8601 tarih formatını parse etmeye çalışalım
        let dateFormatter = ISO8601DateFormatter()
        let lhsDate = dateFormatter.date(from: lhs.publishedAt) ?? Date.distantPast
        let rhsDate = dateFormatter.date(from: rhs.publishedAt) ?? Date.distantPast
        return lhsDate > rhsDate
    }
    
    static func > (lhs: NewsItem, rhs: NewsItem) -> Bool {
        let dateFormatter = ISO8601DateFormatter()
        let lhsDate = dateFormatter.date(from: lhs.publishedAt) ?? Date.distantPast
        let rhsDate = dateFormatter.date(from: rhs.publishedAt) ?? Date.distantPast
        return lhsDate < rhsDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
        lhs.id == rhs.id
    }
}
*/

// Ana uygulamanın tab view yapısı
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
        .accentColor(AppColorsTheme.gold)
        .sheet(isPresented: $showingLoginView) {
            LoginView(isPresented: $showingLoginView)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Market View
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
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

// MARK: - News View
struct NewsViewSimple: View {
    @State private var isLoading = false
    @State private var showingNewsDetail = false
    @State private var selectedCategory: NewsCategory = .all
    @State private var searchText = ""
    
    enum NewsCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case crypto = "Crypto"
        case blockchain = "Blockchain"
        case nft = "NFT"
        case defi = "DeFi"
        
        var id: String { self.rawValue }
    }
    
    init(showDefaultContent: Bool) {
        // Empty initializer to resolve the ambiguity
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(NewsCategory.allCases) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category.rawValue)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? AppColorsTheme.gold : Color.gray.opacity(0.3))
                                    .foregroundColor(selectedCategory == category ? .black : .white)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    // Demo için örnek haberler
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(1...10, id: \.self) { i in
                                NewsCardView(
                                    title: "Kripto Para Haberi \(i)",
                                    description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam eu turpis molestie, dictum est a, mattis tellus.",
                                    source: "Crypto News",
                                    date: Date(),
                                    category: selectedCategory.rawValue
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Crypto News")
            .searchable(text: $searchText, prompt: "Search news...")
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
    }
}

struct NewsCardView: View {
    let title: String
    let description: String
    let source: String
    let date: Date
    let category: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Text(source)
                    .font(.caption)
                    .foregroundColor(AppColorsTheme.gold)
                
                Spacer()
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray)
        .cornerRadius(10)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Login View
struct LoginViewSimple: View {
    @Binding var isPresented: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = "Lütfen kullanıcı adı ve şifre girin"
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Giriş Yap")
                        .font(.largeTitle)
                        .padding(.bottom, 30)
                    
                    // Kullanıcı adı
                    TextField("Kullanıcı Adı", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                    
                    // Şifre
                    SecureField("Şifre", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    
                    Button("Giriş Yap") {
                        if username.isEmpty || password.isEmpty {
                            alertMessage = "Lütfen kullanıcı adı ve şifre girin"
                            showingAlert = true
                        } else if username == "demo" && password == "123456" {
                            // Giriş başarılı - demo kullanıcı
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            UserDefaults.standard.set(username, forKey: "username")
                            NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                            isPresented = false
                        } else {
                            // Hatalı giriş
                            alertMessage = "Kullanıcı adı veya şifre hatalı"
                            showingAlert = true
                        }
                    }
                    .foregroundColor(.black)
                    .padding()
                    .frame(width: 200)
                    .background(AppColorsTheme.gold)
                    .cornerRadius(10)
                    
                    // Demo giriş bilgileri
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Demo Giriş:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Kullanıcı Adı: demo")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Şifre: 123456")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Button("Kapat") {
                        isPresented = false
                    }
                    .foregroundColor(AppColorsTheme.gold)
                    .padding(.top, 20)
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Hata"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    @Binding var showingLoginView: Bool
    @StateObject private var viewModel = SearchViewModelLight()
    @State private var searchText = ""
    @State private var animationType: CryptoSearchAnimation = .bouncingLogos
    @State private var showingCoinDetail = false
    @State private var selectedCoinID = ""
    @State private var showingNewsDetail = false
    @State private var selectedNewsURL = URL(string: "https://example.com")!
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    TextField("Kripto para ara...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .onChange(of: searchText) { newValue in
                            viewModel.searchCoins(newValue)
                        }
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        Spacer()
                    } else if !searchText.isEmpty {
                        // Arama sonuçları
                        ScrollView {
                            VStack(alignment: .leading, spacing: 15) {
                                if !viewModel.filteredCoins.isEmpty {
                                    Text("Coinler")
                                        .font(.headline)
                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    ForEach(viewModel.filteredCoins) { coin in
                                        Button(action: {
                                            selectedCoinID = coin.id
                                            showingCoinDetail = true
                                        }) {
                                            SearchCoinRow(coin: coin)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                if !viewModel.filteredNews.isEmpty {
                                    Text("Haberler")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                                    ForEach(viewModel.filteredNews) { news in
                                        Button(action: {
                                            if let url = URL(string: news.url) {
                                                selectedNewsURL = url
                                                showingNewsDetail = true
                                            }
                                        }) {
                                            SearchNewsRow(news: news)
                                        }
                        .padding(.horizontal)
                                    }
                                }
                                
                                if viewModel.filteredCoins.isEmpty && viewModel.filteredNews.isEmpty {
                                    Text("Arama sonucu bulunamadı")
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 30)
                                }
                            }
                            .padding(.vertical)
                        }
                    } else {
                        // Coin logoları matrisi
                        CryptoSearchAnimationView(type: animationType, coinNames: viewModel.coinNames, logos: viewModel.initialLogos) { coinName in
                            if let coin = viewModel.coins.first(where: { $0.name == coinName }) {
                                selectedCoinID = coin.id
                                showingCoinDetail = true
                            }
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLoginView = true
                    }) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppColorsTheme.gold)
                            .imageScale(.large)
                }
            }
        }
        .onAppear {
                // Verileri yükle
            viewModel.loadInitialData()
        }
            .sheet(isPresented: $showingCoinDetail) {
                CoinDetailView(coinId: selectedCoinID)
            }
            .sheet(isPresented: $showingNewsDetail) {
                CustomSafariView(url: selectedNewsURL)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

// MARK: - CryptoSearchAnimationView
struct CryptoSearchAnimationView: View {
    let type: CryptoSearchAnimation
    let coinNames: [String]
    let logos: [String: String]
    let onCoinTap: (String) -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 25) {
                    ForEach(0..<4, id: \.self) { column in
                        let index = row * 4 + column
                        if index < coinNames.count {
                            CoinLogoCircle(name: coinNames[index], logoURL: logos[coinNames[index]], onTap: {
                                onCoinTap(coinNames[index])
                            })
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 15)
    }
}

// Coin logo dairesi
struct CoinLogoCircle: View {
    let name: String
    let logoURL: String?
    let onTap: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(AppColorsTheme.darkGray)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 5)
                
                if let logoURL = logoURL, let url = URL(string: logoURL) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 55, height: 55)
                                .clipShape(Circle())
                        case .empty, .failure:
                            Image(systemName: "bitcoinsign.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(AppColorsTheme.gold)
                                .frame(width: 50, height: 50)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(AppColorsTheme.gold)
                        .frame(width: 50, height: 50)
                }
            }
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// Search - Coin satırı
struct SearchCoinRow: View {
    let coin: Coin
    
    var body: some View {
        HStack {
            // Logo
            if let url = URL(string: coin.image) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    case .empty, .failure:
                        Image(systemName: "bitcoinsign.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(AppColorsTheme.gold)
                            .frame(width: 40, height: 40)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "bitcoinsign.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(AppColorsTheme.gold)
                    .frame(width: 40, height: 40)
            }
            
            // Coin bilgileri
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(coin.symbol)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Fiyat bilgileri
            VStack(alignment: .trailing, spacing: 4) {
                Text(coin.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(coin.formattedChange)
                    .font(.subheadline)
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(10)
    }
}

// Search - Haber satırı
struct SearchNewsRow: View {
    let news: NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(news.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(news.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Text(news.source)
                    .font(.caption)
                    .foregroundColor(AppColorsTheme.gold)
                
                Spacer()
                
                if let date = ISO8601DateFormatter().date(from: news.publishedAt) {
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(10)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Coin Detay Görünümü
struct CoinDetailView: View {
    let coinId: String
    @Environment(\.presentationMode) var presentationMode
    @State private var coin: Coin?
    @State private var coinNews: [NewsItem] = []
    @State private var isLoading = true
    @State private var showingSafari = false
    @State private var selectedNewsURL = URL(string: "https://example.com")!
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                                    .padding(.top, 50)
                                Spacer()
                            }
                        } else if let coin = coin {
                            // Coin başlık ve fiyat
                            HStack {
                                if let url = URL(string: coin.image) {
                                    CachedAsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                        case .empty, .failure:
                                            Image(systemName: "bitcoinsign.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundColor(AppColorsTheme.gold)
                                                .frame(width: 60, height: 60)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(coin.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text(coin.symbol)
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(coin.formattedPrice)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text(coin.formattedChange)
                                        .font(.headline)
                                        .foregroundColor(coin.change24h >= 0 ? .green : .red)
                                }
                            }
                            .padding()
                            .background(AppColorsTheme.darkGray.opacity(0.3))
                            .cornerRadius(15)
                            
                            // Market bilgisi
                            VStack(alignment: .leading) {
                                Text("Market Bilgisi")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.bottom, 5)
                                
                                HStack {
                                    DetailInfoView(title: "Market Cap", value: coin.formattedMarketCap)
                                    DetailInfoView(title: "Sıralama", value: "#\(coin.rank)")
                                }
                            }
                            .padding()
                            .background(AppColorsTheme.darkGray.opacity(0.3))
                            .cornerRadius(15)
                            
                            // İlgili haberler
                            VStack(alignment: .leading) {
                                Text("İlgili Haberler")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.bottom, 5)
                                
                                if coinNews.isEmpty {
                                    Text("Haber bulunamadı")
                                        .foregroundColor(.gray)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    ForEach(coinNews) { news in
                                        Button(action: {
                                            if let url = URL(string: news.url) {
                                                selectedNewsURL = url
                                                showingSafari = true
                                            }
                                        }) {
                                            SearchNewsRow(news: news)
                                                .padding(.vertical, 5)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(AppColorsTheme.darkGray.opacity(0.3))
                            .cornerRadius(15)
                            
                        } else {
                            Text("Coin bulunamadı")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 50)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Coin Detayları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Kapat")
                            .foregroundColor(AppColorsTheme.gold)
                    }
                }
            }
            .onAppear {
                loadCoinDetails()
            }
            .sheet(isPresented: $showingSafari) {
                CustomSafariView(url: selectedNewsURL)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    private func loadCoinDetails() {
        Task {
            // Coin verilerini yükle
            do {
                let coins = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
                if let foundCoin = coins.first(where: { $0.id == coinId }) {
                    await MainActor.run {
                        self.coin = foundCoin
                    }
                    
                    // İlgili haberleri yükle
                    let allNews = try await APIService.shared.fetchNews()
                    let filteredNews = allNews.filter { 
                        $0.title.lowercased().contains(foundCoin.name.lowercased()) ||
                        $0.description.lowercased().contains(foundCoin.name.lowercased()) ||
                        (foundCoin.symbol.count > 2 && $0.title.lowercased().contains(foundCoin.symbol.lowercased()))
                    }
                    
                    await MainActor.run {
                        self.coinNews = filteredNews
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("Error loading coin details: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct DetailInfoView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Portfolio View
struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if !isLoggedIn {
                    // Kullanıcı giriş yapmamışsa gösterilecek görünüm
                    VStack(spacing: 20) {
                        Image(systemName: "lock.circle")
                            .font(.system(size: 70))
                            .foregroundColor(AppColorsTheme.gold)
                            .padding(.bottom, 30)
                        
                        Text("Portföyünüzü görüntülemek için \ngiriş yapmalısınız")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Text("Giriş Yap")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColorsTheme.gold)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 50)
                    }
                } else {
                    // Kullanıcı giriş yapmışsa portföy görünümü
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Hoş Geldiniz, \(username)")
                                .font(.title)
                                .foregroundColor(AppColorsTheme.gold)
                                .padding(.top)
                            
                            // Portföy özeti
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Toplam Değer")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Text("$15,482.65")
                                        .font(.title3)
                                        .fontWeight(.bold)
                        .foregroundColor(.white)
                                    
                                    Text("+5.2%")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.darkGray).opacity(0.3))
                                .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("24s Değişim")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Text("$842.59")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("+3.8%")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.darkGray).opacity(0.3))
                                .cornerRadius(12)
                            }
                            
                            // Portföy dağılımı
                            Text("Portföy Dağılımı")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top, 10)
                            
                            // Demo kripto paralar
                            cryptoAssetRow(name: "Bitcoin", symbol: "BTC", amount: "0.42", value: "$8,245.36", change: "+2.3%")
                            cryptoAssetRow(name: "Ethereum", symbol: "ETH", amount: "3.15", value: "$4,721.58", change: "+4.1%")
                            cryptoAssetRow(name: "Solana", symbol: "SOL", amount: "24.8", value: "$1,254.46", change: "+8.7%")
                            cryptoAssetRow(name: "Cardano", symbol: "ADA", amount: "1450", value: "$956.85", change: "-1.2%")
                            cryptoAssetRow(name: "Binance Coin", symbol: "BNB", amount: "1.3", value: "$304.00", change: "+0.5%")
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Portföy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoggedIn {
                        Button(action: {
                            // Çıkış yap
                            UserDefaults.standard.set(false, forKey: "isLoggedIn")
                            UserDefaults.standard.removeObject(forKey: "username")
                            isLoggedIn = false
                            username = ""
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(AppColorsTheme.gold)
                        }
                    } else {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                        }
                    }
                }
            }
            .onAppear {
                // Kullanıcının giriş durumunu kontrol et
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
                username = UserDefaults.standard.string(forKey: "username") ?? "Kullanıcı"
            }
            .onChange(of: showingLoginView) { _ in
                if !showingLoginView {
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
                    username = UserDefaults.standard.string(forKey: "username") ?? "Kullanıcı"
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserLoggedIn"))) { _ in
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
                username = UserDefaults.standard.string(forKey: "username") ?? "Kullanıcı"
            }
        }
    }
    
    // Kripto varlık satırı
    private func cryptoAssetRow(name: String, symbol: String, amount: String, value: String, change: String) -> some View {
        HStack {
            // Coin bilgileri
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(amount) \(symbol)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Değer bilgileri
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(change)
                    .font(.subheadline)
                    .foregroundColor(change.hasPrefix("+") ? .green : .red)
            }
        }
        .padding()
        .background(Color(UIColor.darkGray).opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Community View
struct CommunityView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    @State private var newPostText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Community View")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    if !isLoggedIn {
                        // Giriş yapmayan kullanıcılar için bilgi kartı
                        HStack(spacing: 16) {
                            Image(systemName: "lock.circle")
                                .font(.system(size: 24))
                                .foregroundColor(AppColorsTheme.gold)
                            
                            Text("Yorum yapmak için giriş yapmalısınız")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                showingLoginView = true
                            }) {
                                Text("Giriş Yap")
                                    .font(.footnote.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppColorsTheme.gold)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.darkGray).opacity(0.3))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoggedIn {
                        Button(action: {
                            // Çıkış yap
                            isLoggedIn = false
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(AppColorsTheme.gold)
                        }
                    } else {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                        }
                    }
                }
            }
            .onAppear {
                // Kullanıcının giriş durumunu kontrol et
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
            .onChange(of: showingLoginView) { _ in
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
        }
    }
}

// MARK: - Geçici Coin Detay Görünümü
struct TemporaryCoinDetailView: View {
    let coinId: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Coin ID: \(coinId)")
                .font(.headline)
                .padding()
            
            Text("Coin detayları yakında burada olacak")
                .foregroundColor(.gray)
                .padding()
            
            Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(AppColorsTheme.gold)
            .foregroundColor(.black)
            .cornerRadius(8)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationTitle("Coin Detayları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Kapat")
                        .foregroundColor(AppColorsTheme.gold)
                }
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
        }
    }
}

