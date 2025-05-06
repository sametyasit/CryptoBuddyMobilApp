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
    @State private var loadTask: Task<Void, Never>? = nil
    
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
                            startLoading()
                        }
                    }
                    .onDisappear {
                        cancelLoading()
                    }
            }
        }
    }
    
    private func startLoading() {
        guard let url = url, loadTask == nil else { return }
        isLoading = true
        
        loadTask = Task {
            do {
                // Düşük öncelikli yükleme
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms gecikme
                
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    ImageCache.shared.set(image, forKey: url.absoluteString)
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                        loadTask = nil
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
                await MainActor.run {
                    isLoading = false
                    loadTask = nil
                }
            }
        }
    }
    
    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
    
    private func getCachedImage() -> UIImage? {
        guard let url = url else { return nil }
        return ImageCache.shared.get(forKey: url.absoluteString)
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
class SearchViewModelLight: ObservableObject, @unchecked Sendable {
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
    
    // Önbellek kontrolü için tarih
    private var lastCoinFetchTime: Date? = nil
    private var lastNewsFetchTime: Date? = nil
    private let refreshInterval: TimeInterval = 60 // 60 saniye
    
    init() {
        // App açılışında UserDefaults'tan kayıtlı verileri yükleme
        loadCachedData()
    }
    
    func loadInitialData() {
        if shouldRefreshCoins() || coins.isEmpty {
            isLoading = true
            Task {
                await fetchCoins()
                await fetchNews()
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        } else {
            // Sadece coin isimlerini ve logoları güncelle
            updateCoinNamesAndLogos()
        }
    }
    
    private func shouldRefreshCoins() -> Bool {
        guard let lastFetch = lastCoinFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > refreshInterval
    }
    
    private func shouldRefreshNews() -> Bool {
        guard let lastFetch = lastNewsFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > refreshInterval
    }
    
    private func loadCachedData() {
        // UserDefaults'tan veri yükleme
        if let coinsData = UserDefaults.standard.data(forKey: "cachedCoins"),
           let cachedCoins = try? JSONDecoder().decode([Coin].self, from: coinsData) {
            self.coins = cachedCoins
            updateCoinNamesAndLogos()
        }
        
        if let newsData = UserDefaults.standard.data(forKey: "cachedNews"),
           let cachedNews = try? JSONDecoder().decode([NewsItem].self, from: newsData) {
            self.news = cachedNews
        }
        
        // Son yükleme tarihlerini al
        if let lastCoinsTimeStamp = UserDefaults.standard.object(forKey: "lastCoinFetchTime") as? Date {
            self.lastCoinFetchTime = lastCoinsTimeStamp
        }
        
        if let lastNewsTimeStamp = UserDefaults.standard.object(forKey: "lastNewsFetchTime") as? Date {
            self.lastNewsFetchTime = lastNewsTimeStamp
        }
    }
    
    private func cacheData() {
        // Coin verilerini önbelleğe kaydet
        if !coins.isEmpty, let encodedCoins = try? JSONEncoder().encode(coins) {
            UserDefaults.standard.set(encodedCoins, forKey: "cachedCoins")
            UserDefaults.standard.set(Date(), forKey: "lastCoinFetchTime")
        }
        
        // Haber verilerini önbelleğe kaydet
        if !news.isEmpty, let encodedNews = try? JSONEncoder().encode(news) {
            UserDefaults.standard.set(encodedNews, forKey: "cachedNews")
            UserDefaults.standard.set(Date(), forKey: "lastNewsFetchTime") 
        }
    }
    
    private func updateCoinNamesAndLogos() {
        // Coin isimlerini ve logo URL'lerini güncelle
        if !coins.isEmpty {
            let names = coins.map { $0.name }
            self.coinNames = names.count >= 16 ? Array(names.prefix(16)) : names
            
            var logos: [String: String] = [:]
            for coin in coins {
                logos[coin.name] = coin.image
            }
            self.initialLogos = logos
        }
    }
    
    @MainActor
    @Sendable
    func fetchCoins() async {
        do {
            let response = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
            self.coins = response.coins
            updateCoinNamesAndLogos()
            self.lastCoinFetchTime = Date()
            
            // Önbelleğe kaydet
            Task {
                cacheData()
            }
        } catch {
            print("Coin verileri yüklenemedi: \(error)")
        }
    }
    
    @MainActor
    @Sendable
    func fetchNews() async {
        do {
            let fetchedNews = try await APIService.shared.fetchNews()
            self.news = fetchedNews
            self.lastNewsFetchTime = Date()
            
            // Önbelleğe kaydet
            Task {
                cacheData()
            }
        } catch {
            print("Haber verileri yüklenemedi: \(error)")
        }
    }
    
    func searchCoins(_ query: String) {
        if query.isEmpty {
            filteredCoins = []
            filteredNews = []
        } else {
            // Arama sorgusunu optimize et
            let lowercasedQuery = query.lowercased()
            
            // Coin araması
            filteredCoins = coins.filter { 
                $0.name.lowercased().contains(lowercasedQuery) || 
                $0.symbol.lowercased().contains(lowercasedQuery)
            }
            
            // Haberlerde arama
            filteredNews = news.filter { 
                $0.title.lowercased().contains(lowercasedQuery)
            }
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
                        .onChange(of: searchText) { oldValue, newValue in
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
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 15),
            GridItem(.flexible(), spacing: 15),
            GridItem(.flexible(), spacing: 15),
            GridItem(.flexible(), spacing: 15)
        ], spacing: 15) {
            ForEach(coinNames.prefix(16), id: \.self) { coinName in
                CoinLogoCircle(name: coinName, logoURL: logos[coinName], onTap: {
                    onCoinTap(coinName)
                })
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
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
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.2), radius: 3)
                
                if let logoURL = logoURL, let url = URL(string: logoURL) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
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
            }
            .scaleEffect(isAnimating ? 1.03 : 1.0)
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
    @State private var errorMessage: String? = nil
    @State private var selectedChartPeriod: ChartPeriod = .week
    @State private var retryCount = 0
    @State private var showFullDescription = false
    @State private var isAppearing = false
    
    enum ChartPeriod: String, CaseIterable {
        case day = "24s"
        case week = "1h"
        case month = "1a"
        case year = "1y"
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Başlık çubuğu
                CoinDetailHeaderView(
                    coinName: coin?.name,
                    onClose: {
                        print("🔴 CoinDetailView kapatılıyor, ID: \(coinId)")
                        isAppearing = false
                        // Animasyon için küçük bir gecikme
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
                
                if isLoading {
                    // Yükleniyor
                    LoadingView(message: "Yükleniyor...")
                } else if let error = errorMessage {
                    // Hata durumu
                    ErrorView(
                        error: error,
                        onRetry: {
                            isLoading = true
                            errorMessage = nil
                            retryCount += 1
                            loadCoinDetails()
                        }
                    )
                } else if let coin = coin {
                    // Coin bilgileri
                    ScrollView {
                        CoinDetailContentView(
                            coin: coin,
                            selectedChartPeriod: $selectedChartPeriod,
                            showFullDescription: $showFullDescription,
                            coinNews: coinNews,
                            onChartPeriodSelect: { period in
                                loadPriceHistory(for: coin.id, period: period)
                            },
                            onOpenURL: { urlString in
                                openURL(urlString)
                            },
                            onNewsSelect: { url in
                                selectedNewsURL = url
                                showingSafari = true
                            }
                        )
                    }
                } else {
                    // Coin bulunamadı
                    CoinNotFoundView(
                        coinId: coinId,
                        onRetry: {
                            isLoading = true
                            retryCount += 1
                            loadCoinDetails()
                        }
                    )
                }
            }
        }
        .onAppear {
            print("🚀 CoinDetailView.onAppear çağrıldı, coinId: \(coinId)")
            isAppearing = true
            loadCoinDetails()
        }
        .onDisappear {
            print("🔴 CoinDetailView.onDisappear çağrıldı")
            isAppearing = false
        }
        .sheet(isPresented: $showingSafari) {
            CustomSafariView(url: selectedNewsURL)
                .ignoresSafeArea()
        }
    }
    
    // Coin detay içerik yükleme fonksiyonları
    private func loadCoinDetails() {
        print("📱 Loading coin details for ID: \"\(coinId)\"")
        
        guard !coinId.isEmpty else {
            print("❌ Boş coinId! Detaylar yüklenemez.")
            errorMessage = "Geçersiz coin ID"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("🔍 API'den detaylı coin bilgisi alınıyor...")
                let detailedCoin = try await APIService.shared.fetchCoinDetails(coinId: coinId)
                print("✅ Detaylı coin bilgisi alındı: \(detailedCoin.name)")
                
                await MainActor.run {
                    self.coin = detailedCoin
                    self.isLoading = false
                }
                
                // Haberleri yüklemeye çalış
                await loadNews(for: detailedCoin)
            } catch APIError.coinNotFound {
                print("⚠️ Coin bulunamadı: \(coinId)")
                
                // Fallback olarak temel coin verileri almaya çalış
                do {
                    try await loadBasicCoinData()
                } catch {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Bu coin için veri bulunamadı. Lütfen daha sonra tekrar deneyin."
                    }
                }
            } catch APIError.invalidResponse {
                print("❌ API'den geçersiz yanıt alındı")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Sunucu şu anda yanıt vermiyor. Lütfen daha sonra tekrar deneyin."
                }
            } catch APIError.allAPIsFailed {
                print("❌ Tüm API kaynakları başarısız oldu")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
                }
            } catch {
                print("❌ Coin detayları yüklenirken hata: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    // URLError durumunda daha anlaşılır mesaj göster
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            self.errorMessage = "İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin."
                        case .timedOut:
                            self.errorMessage = "Bağlantı zaman aşımına uğradı. Lütfen daha sonra tekrar deneyin."
                        default:
                            self.errorMessage = "Ağ hatası: \(urlError.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "Hata: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func loadBasicCoinData() async throws {
        print("🔍 Backup: Temel coin verilerini almaya çalışıyor...")
        let coins = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
        
        if let foundCoin = coins.first(where: { $0.id == coinId }) {
            print("✅ Temel coin verisi bulundu: \(foundCoin.name)")
            
            await MainActor.run {
                self.coin = foundCoin
                self.isLoading = false
            }
            
            // Grafik verilerini almaya çalış
            try? await loadPriceHistory(for: coinId)
            
            // Haberleri almaya çalış
            await loadNews(for: foundCoin)
        } else {
            throw APIError.coinNotFound
        }
    }
    
    private func loadPriceHistory(for coinId: String, period: ChartPeriod = .week) {
        Task {
            do {
                print("📈 Fiyat geçmişi alınıyor: \(coinId) - \(period.rawValue)")
                let historyData = try await APIService.shared.fetchCoinPriceHistory(coinId: coinId, days: period.days)
                
                guard !historyData.isEmpty else {
                    print("⚠️ Fiyat geçmişi boş")
                    return
                }
                
                print("✅ \(historyData.count) adet grafik noktası alındı")
                
                await MainActor.run {
                    if var updatedCoin = self.coin {
                        updatedCoin.graphData = historyData
                        self.coin = updatedCoin
                    }
                }
            } catch {
                print("⚠️ Fiyat geçmişi alınamadı: \(error)")
            }
        }
    }
    
    private func loadNews(for coin: Coin) async {
        do {
            print("📰 \(coin.name) için haberler yükleniyor...")
            let allNews = try await APIService.shared.fetchNews()
            print("✅ \(allNews.count) haber alındı")
            
            // Coin adı, sembolü ve related keywords ile filtrele
            let keywords = [coin.name.lowercased(), coin.symbol.lowercased()]
            
            let filteredNews = allNews.filter { news in
                let content = news.title.lowercased() + " " + news.description.lowercased()
                return keywords.contains { content.contains($0) }
            }
            print("📰 \(filteredNews.count) ilgili haber bulundu")
            
            await MainActor.run {
                self.coinNews = filteredNews
            }
        } catch {
            print("⚠️ Haberler yüklenirken hata oluştu: \(error), sadece log")
            // Haber hatası kritik değil, sadece log
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            selectedNewsURL = url
            showingSafari = true
        }
    }
}

// MARK: - Alt Görünüm Bileşenleri
struct CoinDetailHeaderView: View {
    let coinName: String?
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            // Coin ismi veya varsayılan başlık
            Text(coinName ?? "Coin Detayları")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.leading)
            
            Spacer()
            
            Button(action: onClose) {
                Text("Kapat")
                    .foregroundColor(AppColorsTheme.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
            }
            .padding(.trailing)
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                .padding()
            
            Text(message)
                .foregroundColor(.gray)
                .padding()
            
            Spacer()
        }
    }
}

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(AppColorsTheme.gold)
                .padding()
            
            Text("Veriler yüklenemedi")
                .font(.title)
                .foregroundColor(.white)
            
            Text(error)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                Text("Tekrar Dene")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .background(AppColorsTheme.gold)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
}

struct CoinNotFoundView: View {
    let coinId: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("Coin bulunamadı")
                .font(.title)
                .foregroundColor(.white)
                .padding()
            
            Text("ID: \(coinId)")
                .font(.body)
                .foregroundColor(.gray)
                .padding()
            
            Button(action: onRetry) {
                Text("Tekrar Dene")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .background(AppColorsTheme.gold)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
}

struct CoinDetailContentView: View {
    let coin: Coin
    @Binding var selectedChartPeriod: CoinDetailView.ChartPeriod
    @Binding var showFullDescription: Bool
    let coinNews: [NewsItem]
    let onChartPeriodSelect: (CoinDetailView.ChartPeriod) -> Void
    let onOpenURL: (String) -> Void
    let onNewsSelect: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Coin başlık
            CoinHeaderView(coin: coin)
            
            // Fiyat grafiği
            if !coin.graphData.isEmpty {
                CoinChartView(
                    coin: coin,
                    selectedPeriod: $selectedChartPeriod,
                    onPeriodSelect: onChartPeriodSelect
                )
            }
            
            // Market bilgisi
            CoinMarketInfoView(coin: coin)
            
            // Açıklama
            if !coin.description.isEmpty {
                CoinDescriptionView(
                    description: coin.description,
                    showFull: $showFullDescription
                )
            }
            
            // Bağlantılar
            CoinLinksView(
                website: coin.website,
                twitter: coin.twitter,
                reddit: coin.reddit,
                github: coin.github,
                onOpenURL: onOpenURL
            )
            
            // İlgili haberler
            CoinNewsView(
                news: coinNews,
                onNewsSelect: onNewsSelect
            )
        }
        .padding()
    }
}

struct CoinHeaderView: View {
    let coin: Coin
    
    var body: some View {
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
            } else {
                Image(systemName: "bitcoinsign.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(AppColorsTheme.gold)
                    .frame(width: 60, height: 60)
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
    }
}

struct CoinChartView: View {
    let coin: Coin
    @Binding var selectedPeriod: CoinDetailView.ChartPeriod
    let onPeriodSelect: (CoinDetailView.ChartPeriod) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fiyat Grafiği")
                .font(.headline)
                .foregroundColor(.white)
            
            // Zaman seçici
            HStack {
                ForEach(CoinDetailView.ChartPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        withAnimation {
                            selectedPeriod = period
                        }
                        onPeriodSelect(period)
                    }) {
                        Text(period.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedPeriod == period ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedPeriod == period ? AppColorsTheme.gold : Color.clear)
                            )
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Grafik
            PriceChart(data: coin.graphData)
                .frame(height: 200)
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

struct CoinMarketInfoView: View {
    let coin: Coin
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Market Bilgisi")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                DetailInfoView(title: "Market Cap", value: coin.formattedMarketCap)
                DetailInfoView(title: "Sıralama", value: "#\(coin.rank)")
                DetailInfoView(title: "İşlem Hacmi", value: coin.formattedVolume)
                DetailInfoView(title: "ATH", value: coin.formattedAth)
                DetailInfoView(title: "24s Yüksek", value: coin.formattedHigh24h)
                DetailInfoView(title: "24s Düşük", value: coin.formattedLow24h)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

struct CoinDescriptionView: View {
    let description: String
    @Binding var showFull: Bool
    
    var cleanDescription: String {
        description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Hakkında")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            if showFull {
                Text(cleanDescription)
                    .font(.body)
                    .foregroundColor(.gray)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button("Daha Az Göster") {
                    withAnimation {
                        showFull = false
                    }
                }
                .foregroundColor(AppColorsTheme.gold)
                .padding(.top, 8)
            } else {
                Text(cleanDescription)
                    .font(.body)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                
                Button("Daha Fazla Göster") {
                    withAnimation {
                        showFull = true
                    }
                }
                .foregroundColor(AppColorsTheme.gold)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

struct CoinLinksView: View {
    let website: String
    let twitter: String
    let reddit: String
    let github: String
    let onOpenURL: (String) -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            if !website.isEmpty {
                SocialButton(icon: "globe", color: .blue) {
                    onOpenURL(website)
                }
            }
            
            if !twitter.isEmpty {
                SocialButton(icon: "bird", color: .cyan) {
                    onOpenURL(twitter)
                }
            }
            
            if !reddit.isEmpty {
                SocialButton(icon: "message.fill", color: .orange) {
                    onOpenURL(reddit)
                }
            }
            
            if !github.isEmpty {
                SocialButton(icon: "chevron.left.forwardslash.chevron.right", color: .white) {
                    onOpenURL(github)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

struct CoinNewsView: View {
    let news: [NewsItem]
    let onNewsSelect: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("İlgili Haberler")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            if news.isEmpty {
                Text("Haber bulunamadı")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(news) { news in
                    Button(action: {
                        if let url = URL(string: news.url) {
                            onNewsSelect(url)
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

// Sosyal medya butonu
struct SocialButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(AppColorsTheme.darkGray)
                .clipShape(Circle())
        }
    }
}

// Market bilgi hücresi
struct DetailInfoView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.5))
        .cornerRadius(8)
    }
}

// Fiyat grafiği
struct PriceChart: View {
    let data: [GraphPoint]
    @State private var selectedPoint: GraphPoint? = nil
    @State private var lineHeight: CGFloat = 0
    
    var minValue: Double {
        data.map { $0.price }.min() ?? 0
    }
    
    var maxValue: Double {
        data.map { $0.price }.max() ?? 0
    }
    
    var latestPrice: Double {
        data.last?.price ?? 0
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack {
            // Seçili nokta bilgisi
            if let point = selectedPoint {
                HStack {
                    VStack(alignment: .leading) {
                        Text(dateFormatter.string(from: point.date))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(String(format: "$%.2f", point.price))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    let changePercent = ((point.price / latestPrice) - 1) * 100
                    Text(String(format: "%.2f%%", changePercent))
                        .foregroundColor(changePercent >= 0 ? .green : .red)
                        .font(.subheadline)
                }
                .padding(.bottom, 8)
            } else {
                HStack {
                    Text(String(format: "$%.2f", latestPrice))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            
            GeometryReader { geometry in
                ZStack {
                    // Çizgi grafiği
                    if data.count > 1 {
                        Path { path in
                            let step = geometry.size.width / CGFloat(data.count - 1)
                            let range = maxValue - minValue
                            
                            path.move(to: CGPoint(
                                x: 0,
                                y: geometry.size.height - CGFloat((data[0].price - minValue) / range) * geometry.size.height
                            ))
                            
                            for i in 1..<data.count {
                                let x = step * CGFloat(i)
                                let y = geometry.size.height - CGFloat((data[i].price - minValue) / range) * geometry.size.height
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(lineGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // Altlık alan
                        Path { path in
                            let step = geometry.size.width / CGFloat(data.count - 1)
                            let range = maxValue - minValue
                            
                            path.move(to: CGPoint(
                                x: 0,
                                y: geometry.size.height - CGFloat((data[0].price - minValue) / range) * geometry.size.height
                            ))
                            
                            for i in 1..<data.count {
                                let x = step * CGFloat(i)
                                let y = geometry.size.height - CGFloat((data[i].price - minValue) / range) * geometry.size.height
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                            path.closeSubpath()
                        }
                        .fill(areaGradient)
                        
                        // Etkileşimli dokunmatik alan
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let step = geometry.size.width / CGFloat(data.count - 1)
                                        let index = Int(value.location.x / step)
                                        if index >= 0 && index < data.count {
                                            selectedPoint = data[index]
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPoint = nil
                                    }
                            )
                    } else {
                        Text("Yeterli veri yok")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
    
    // Gradients
    var lineGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [AppColorsTheme.gold, .orange]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var areaGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                AppColorsTheme.gold.opacity(0.3),
                AppColorsTheme.gold.opacity(0.1),
                AppColorsTheme.gold.opacity(0.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Portfolio View
struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        // Portfolio view content
        Text("Portfolio View")
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
            .onChange(of: showingLoginView) { oldValue, newValue in
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
        }
    }
}


