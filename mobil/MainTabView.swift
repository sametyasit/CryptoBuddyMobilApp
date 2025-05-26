import SwiftUI
import Foundation
import Combine
import Charts
import UIKit
import SafariServices

// MARK: - SearchViewModel modelini ekleyelim
class SearchViewModelLight: ObservableObject, @unchecked Sendable {
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var coins: [Coin] = []
    @Published var news: [NewsItem] = []
    @Published var filteredCoins: [Coin] = []
    @Published var filteredNews: [NewsItem] = []
    @Published var selectedCoin: Coin? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoadingMoreCoins = false
    
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
    private var currentPage = 1
    
    init() {
        // App açılışında UserDefaults'tan kayıtlı verileri yükleme
        loadCachedData()
    }
    
    func loadInitialData() {
        if shouldRefreshCoins() || coins.isEmpty {
            isLoading = true
            Task {
                await fetchCoins(page: 1)
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
    func fetchCoins(page: Int) async {
        do {
            isLoading = true
            let response = try await APIService.shared.fetchCoins(page: page, perPage: 200)
            
            if page == 1 {
                // İlk sayfa ise, mevcut listeyi temizle
                self.coins = response.coins
            } else {
                // Sonraki sayfalar ise, mevcut listeye ekle
                // Zaten eklenen coinleri önle (ID'ye göre)
                let existingIds = Set(self.coins.map { $0.id })
                let newCoins = response.coins.filter { !existingIds.contains($0.id) }
                self.coins.append(contentsOf: newCoins)
            }
            
            updateCoinNamesAndLogos()
            self.lastCoinFetchTime = Date()
            
            // Arama terimi varsa, sonuçları güncelle
            if !searchText.isEmpty {
                self.searchCoins(searchText)
            }
            
            // Önbelleğe kaydet
            Task {
                cacheData()
            }
            
            // Sayfa numarasını güncelle
            self.currentPage = page
            self.isLoading = false
        } catch {
            print("Coin verileri yüklenemedi: \(error)")
            self.isLoading = false
            self.errorMessage = "Coin verileri yüklenirken bir hata oluştu: \(error.localizedDescription)"
        }
    }
    
    // Daha fazla coin yükle
    @MainActor
    func loadMoreCoins() async {
        guard !isLoadingMoreCoins else { return }
        
        isLoadingMoreCoins = true
        let nextPage = currentPage + 1
        
        do {
            let response = try await APIService.shared.fetchCoins(page: nextPage, perPage: 200)
            
            // Zaten eklenen coinleri önle (ID'ye göre)
            let existingIds = Set(self.coins.map { $0.id })
            let newCoins = response.coins.filter { !existingIds.contains($0.id) }
            
            if !newCoins.isEmpty {
                self.coins.append(contentsOf: newCoins)
                
                // Arama terimi varsa, sonuçları güncelle
                if !searchText.isEmpty {
                    self.searchCoins(searchText)
                }
                
                // Sayfa numarasını güncelle
                self.currentPage = nextPage
                
                // Önbelleğe kaydet
                Task {
                    cacheData()
                }
            }
            
            isLoadingMoreCoins = false
        } catch {
            print("Daha fazla coin yüklenirken hata: \(error)")
            isLoadingMoreCoins = false
        }
    }
    
    @MainActor
    @Sendable
    func fetchNews() async {
        do {
            let fetchedNews = try await APIService.shared.fetchNews()
            // Convert API model to app model
            self.news = fetchedNews.map { apiItem in
                NewsItem(
                    id: apiItem.id,
                    title: apiItem.title,
                    description: apiItem.description,
                    url: apiItem.url,
                    imageUrl: apiItem.imageUrl,
                    source: apiItem.source,
                    publishedAt: apiItem.publishedAt
                )
            }
            self.lastNewsFetchTime = Date()
            
            // Önbelleğe kaydet
            Task {
                cacheData()
            }
        } catch {
            print("Haber verileri yüklenemedi: \(error)")
        }
    }
    
    // Arama işlevini geliştir
    func searchCoins(_ query: String) {
        searchText = query
        
        if query.isEmpty {
            filteredCoins = []
            filteredNews = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Arama sorgusunu optimize et
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Coin araması - daha kapsamlı arama yapabilmek için
        filteredCoins = coins.filter { coin in
            coin.name.lowercased().contains(lowercasedQuery) || 
            coin.symbol.lowercased().contains(lowercasedQuery)
        }
        
        // Eğer yeterli sonuç yoksa ve daha fazla coin yüklenebiliyorsa
        if filteredCoins.count < 10 && coins.count < 500 {
            // Daha fazla coin yükle ve sonra sonuçları güncelle
            Task {
                await loadMoreCoins()
            }
        }
        
        // Haberlerde arama
        filteredNews = news.filter { news in
            news.title.lowercased().contains(lowercasedQuery) ||
            news.description.lowercased().contains(lowercasedQuery)
        }
        
        isSearching = false
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
// Using the implementation from SimpleNewsView.swift

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
                Color.black.ignoresSafeArea()
                
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
    @State private var selectedNewsURL: URL? = URL(string: "https://example.com")
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Arama Çubuğu
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        
                        TextField("Kripto para ara...", text: $searchText)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: searchText) { oldValue, newValue in
                                viewModel.searchCoins(newValue)
                            }
                            .foregroundColor(.white)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.searchCoins("")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    if viewModel.isLoading && viewModel.coins.isEmpty {
                        // İlk yükleme durumu
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        Text("Kripto paralar yükleniyor...")
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        Spacer()
                    } else if !searchText.isEmpty {
                        // Arama Sonuçları
                        ScrollView {
                            VStack(alignment: .leading, spacing: 15) {
                                if !viewModel.filteredCoins.isEmpty {
                                    HStack {
                                        Text("Coinler")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        if viewModel.isSearching {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                                                .scaleEffect(0.7)
                                        } else {
                                            Text("\(viewModel.filteredCoins.count) sonuç")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
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
                                    
                                    // Daha fazla sonuç yükleme butonu
                                    if viewModel.filteredCoins.count >= 10 && !viewModel.isLoadingMoreCoins {
                                        Button(action: {
                                            Task {
                                                await viewModel.loadMoreCoins()
                                            }
                                        }) {
                                            HStack {
                                                Text("Daha Fazla Sonuç")
                                                    .font(.subheadline)
                                                    .foregroundColor(AppColorsTheme.gold)
                                                
                                                Image(systemName: "arrow.down.circle")
                                                    .foregroundColor(AppColorsTheme.gold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    if viewModel.isLoadingMoreCoins {
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                                            Spacer()
                                        }
                                        .padding()
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
                                    VStack(spacing: 15) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        
                                        Text("Arama sonucu bulunamadı")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                        
                                        Text("Farklı bir arama terimi deneyin veya daha fazla coin yükleyin")
                                            .font(.subheadline)
                                            .foregroundColor(.gray.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                        
                                        Button(action: {
                                            Task {
                                                await viewModel.loadMoreCoins()
                                            }
                                        }) {
                                            Text("Daha Fazla Coin Yükle")
                                                .font(.headline)
                                                .foregroundColor(.black)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 20)
                                                .background(AppColorsTheme.gold)
                                                .cornerRadius(10)
                                        }
                                        .padding(.top, 10)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 50)
                                }
                            }
                            .padding(.vertical)
                        }
                    } else {
                        // Coin logoları matrisi
                        VStack(spacing: 20) {
                            Text("Popüler Kripto Paralar")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            CryptoSearchAnimationView(type: animationType, coinNames: viewModel.coinNames, logos: viewModel.initialLogos) { coinName in
                                if let coin = viewModel.coins.first(where: { $0.name == coinName }) {
                                    selectedCoinID = coin.id
                                    showingCoinDetail = true
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Ara")
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
                Button("Safari'de Aç") {
                    if let url = selectedNewsURL {
                        UIApplication.shared.open(url)
                    }
                    showingNewsDetail = false
                }
                .padding()
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
                    AsyncImage(url: url) { phase in
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
                AsyncImage(url: url) { phase in
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
    @State private var selectedNewsURL: URL? = URL(string: "https://example.com")
    @State private var errorMessage: String? = nil
    @State private var selectedChartPeriod: ChartPeriod = .hour
    @State private var retryCount = 0
    @State private var showFullDescription = false
    @State private var isAppearing = false
    
    enum ChartPeriod: String, CaseIterable {
        case hour = "1s"
        case day = "24s"
        case week = "7g"
        case month = "30g"
        
        var days: Int {
            switch self {
            case .hour: return 1
            case .day: return 1
            case .week: return 7
            case .month: return 30
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
            Button("Safari'de Aç") {
                if let url = selectedNewsURL {
                    UIApplication.shared.open(url)
                }
                showingSafari = false
            }
            .padding()
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
            } catch APIService.APIError.coinNotFound {
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
            } catch APIService.APIError.invalidResponse {
                print("❌ API'den geçersiz yanıt alındı")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Sunucu şu anda yanıt vermiyor. Lütfen daha sonra tekrar deneyin."
                }
            } catch APIService.APIError.allAPIsFailed {
                print("❌ Tüm API kaynakları başarısız oldu")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
                }
            } catch URLError.timedOut {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Bağlantı zaman aşımına uğradı. Lütfen daha sonra tekrar deneyin."
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
            throw APIService.APIError.coinNotFound
        }
    }
    
    private func loadPriceHistory(for coinId: String, period: ChartPeriod = .hour) {
        Task {
            do {
                print("📈 Fiyat geçmişi alınıyor: \(coinId) - \(period.rawValue)")
                let apiHistoryData = try await APIService.shared.fetchCoinPriceHistory(coinId: coinId, days: period.days)
                
                guard !apiHistoryData.isEmpty else {
                    print("⚠️ Fiyat geçmişi boş")
                    return
                }
                
                // API modellerini uygulama modellerine dönüştür
                let historyData = apiHistoryData.map { GraphPoint.fromAPIModel($0) }
                
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
            let apiNews = try await APIService.shared.fetchNews()
            
            // API modellerini uygulama modellerine dönüştür
            let allNews = apiNews.map { apiItem in
                NewsItem(
                    id: apiItem.id,
                    title: apiItem.title,
                    description: apiItem.description,
                    url: apiItem.url,
                    imageUrl: apiItem.imageUrl,
                    source: apiItem.source,
                    publishedAt: apiItem.publishedAt
                )
            }
            
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
                AsyncImage(url: url) { phase in
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
    @State private var isShowingGainers = true
    @State private var selectedTimeFrame = 0
    @State private var coins: [Coin] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showingCoinDetail = false
    @State private var selectedCoinID = ""
    @State private var timeframeParam = "24h"
    
    // Farklı zaman aralıkları için string parametreleri
    var timeFrames = ["1s", "24s", "7g", "30g"]
    var timeFrameParams = ["1h", "24h", "7d", "30d"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Filtre kontrolleri
                    HStack {
                        Picker("Filtreleme", selection: $isShowingGainers) {
                            Text("Yükselenler").tag(true)
                            Text("Düşenler").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: isShowingGainers) { oldValue, newValue in
                            filterAndSortCoins()
                        }
                    }
                    
                    // Zaman aralığı seçimi
                    HStack {
                        Picker("Zaman Aralığı", selection: $selectedTimeFrame) {
                            ForEach(0..<timeFrames.count, id: \.self) { index in
                                Text(timeFrames[index]).tag(index)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: selectedTimeFrame) { oldValue, newValue in
                            timeframeParam = timeFrameParams[newValue]
                            loadCoins()
                        }
                    }
                    
                    if isLoading {
                        // Yükleniyor görünümü
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        Text("Coinler yükleniyor...")
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        Spacer()
                    } else if let error = errorMessage {
                        // Hata görünümü
                        Spacer()
                        Text("Hata: \(error)")
                            .foregroundColor(.red)
                            .padding()
                        Button("Tekrar Dene") {
                            loadCoins()
                        }
                        .foregroundColor(.black)
                        .padding()
                        .background(AppColorsTheme.gold)
                        .cornerRadius(10)
                        Spacer()
                    } else if coins.isEmpty {
                        // Boş veri görünümü
                        Spacer()
                        Text("Veri bulunamadı")
                            .foregroundColor(.white)
                            .padding()
                        Button("Tekrar Dene") {
                            loadCoins()
                        }
                        .foregroundColor(.black)
                        .padding()
                        .background(AppColorsTheme.gold)
                        .cornerRadius(10)
                        Spacer()
                    } else {
                        // Coin listesi
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(coins.prefix(20)) { coin in
                                    Button(action: {
                                        selectedCoinID = coin.id
                                        showingCoinDetail = true
                                    }) {
                                        coinRow(coin: coin)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .refreshable {
                            await loadCoinsAsync()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 10)
            }
            .navigationTitle("Piyasa")
            .onAppear {
                loadCoins()
            }
            .sheet(isPresented: $showingCoinDetail) {
                CoinDetailView(coinId: selectedCoinID)
            }
        }
    }
    
    private func coinRow(coin: Coin) -> some View {
        HStack(spacing: 12) {
            // Sıralama
            Text("\(coin.rank)")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 30, alignment: .center)
            
            // Coin ikonu - Geliştirilmiş logo görünümü
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 40, height: 40)
                
                if let url = URL(string: coin.image) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                        case .empty:
                            ProgressView()
                                .frame(width: 34, height: 34)
                        case .failure:
                            Image(systemName: "bitcoinsign.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(AppColorsTheme.gold)
                                .frame(width: 34, height: 34)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(AppColorsTheme.gold)
                        .frame(width: 34, height: 34)
                }
            }
            
            // Coin adı ve sembol
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Text(coin.symbol.uppercased())
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            
            Spacer()
            
            // Fiyat bilgisi
            VStack(alignment: .trailing, spacing: 4) {
                Text(coin.formattedPrice)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                
                // Değişim yüzdesi için geliştirilmiş görünüm
                HStack(spacing: 2) {
                    // Seçilen zaman aralığına göre doğru değişim değerini al
                    let changeValue = getChangeValueForTimeFrame(coin: coin)
                    
                    Image(systemName: changeValue >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10))
                        .foregroundColor(changeValue >= 0 ? .green : .red)
                    
                    Text(String(format: "%.1f%%", abs(changeValue)))
                        .foregroundColor(changeValue >= 0 ? .green : .red)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(getChangeValueForTimeFrame(coin: coin) >= 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
    
    // Zaman aralığına göre değişim değerini getiren yardımcı fonksiyon
    private func getChangeValueForTimeFrame(coin: Coin) -> Double {
        switch timeframeParam {
        case "1h":
            // Eğer 1h verisi yoksa 24h verisini kullan
            return coin.changeHour != 0 ? coin.changeHour : coin.change24h
        case "7d":
            // Eğer 7d verisi yoksa 24h verisini kullan
            return coin.changeWeek != 0 ? coin.changeWeek : coin.change24h
        case "30d":
            // Eğer 30d verisi yoksa 24h verisini kullan
            return coin.changeMonth != 0 ? coin.changeMonth : coin.change24h
        default:
            return coin.change24h
        }
    }
    
    private func loadCoins() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadCoinsAsync()
        }
    }
    
    @MainActor
    private func loadCoinsAsync() async {
        do {
            // Gerçek zaman aralığı parametresini kullan
            print("🔄 Seçilen zaman aralığı: \(timeframeParam)")
            
            // Timeframe parametresini API'ye geçir
            let response = try await APIService.shared.fetchCoins(
                page: 1, 
                perPage: 100,
                priceChangePercentage: timeframeParam
            )
            
            print("✅ API'den \(response.coins.count) coin alındı")
            
            // Veri doğruluğunu kontrol et
            let validCoins = response.coins.filter { coin in
                coin.price > 0 && !coin.name.isEmpty && coin.rank > 0
            }
            
            print("📊 Geçerli coin sayısı: \(validCoins.count)")
            
            if validCoins.isEmpty {
                print("❌ Geçerli coin bulunamadı!")
                errorMessage = "Geçerli coin verisi bulunamadı. Lütfen tekrar deneyin."
                isLoading = false
                return
            }
            
            self.coins = validCoins
            
            // Debug: İlk birkaç coin'in değişim verilerini logla
            for (index, coin) in validCoins.prefix(5).enumerated() {
                print("🪙 Coin \(index + 1): \(coin.name) - 24h: \(coin.change24h)%, 1h: \(coin.changeHour)%, 7d: \(coin.changeWeek)%, 30d: \(coin.changeMonth)%")
            }
            
            filterAndSortCoins()
            isLoading = false
        } catch {
            print("❌ Coin verileri yüklenemedi: \(error)")
            errorMessage = "Coin verileri yüklenirken bir hata oluştu: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func filterAndSortCoins() {
        print("🔄 Filtreleme başlıyor - Zaman aralığı: \(timeframeParam), Yükselenler: \(isShowingGainers)")
        
        // Önce tüm coinlerin geçerli olduğundan emin ol
        let validCoins = coins.filter { coin in
            coin.price > 0 && !coin.name.isEmpty && coin.rank > 0
        }
        
        print("📊 Geçerli coin sayısı: \(validCoins.count)")
        
        // Zaman aralığına göre sıralama yap
        let sortedCoins: [Coin]
        
        if isShowingGainers {
            // Yükselenler - en yüksek değişimden en düşüğe
            sortedCoins = validCoins.sorted { coin1, coin2 in
                let change1 = getChangeValueForTimeFrame(coin: coin1)
                let change2 = getChangeValueForTimeFrame(coin: coin2)
                
                // Önce pozitif değişimleri sırala, sonra negatif olanları
                if change1 > 0 && change2 <= 0 {
                    return true
                } else if change1 <= 0 && change2 > 0 {
                    return false
                } else {
                    return change1 > change2
                }
            }
        } else {
            // Düşenler - en düşük değişimden en yükseğe
            sortedCoins = validCoins.sorted { coin1, coin2 in
                let change1 = getChangeValueForTimeFrame(coin: coin1)
                let change2 = getChangeValueForTimeFrame(coin: coin2)
                
                // Önce negatif değişimleri sırala, sonra pozitif olanları
                if change1 < 0 && change2 >= 0 {
                    return true
                } else if change1 >= 0 && change2 < 0 {
                    return false
                } else {
                    return change1 < change2
                }
            }
        }
        
        self.coins = sortedCoins
        
        // Debug için ilk 5 coin'i logla
        print("📊 Sıralama sonrası ilk 5 coin:")
        for (index, coin) in sortedCoins.prefix(5).enumerated() {
            let changeValue = getChangeValueForTimeFrame(coin: coin)
            print("  \(index + 1). \(coin.name): \(String(format: "%.2f", changeValue))%")
        }
        
        print("✅ Filtreleme tamamlandı - Toplam: \(coins.count) coin")
    }
}

// MARK: - Community View
struct CommunityView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    @State private var newPostText = ""
    @State private var comments: [CommunityComment] = []
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
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
                        .padding(.top, 10)
                    } else {
                        // Yorum yazma alanı
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppColorsTheme.gold)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(username)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Bir şeyler paylaş...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            
                            // Yorum yazma alanı
                            VStack(spacing: 8) {
                                TextField("Düşüncelerinizi paylaşın...", text: $newPostText, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding()
                                    .background(Color(UIColor.systemGray6).opacity(0.2))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .lineLimit(3...6)
                                
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        addComment()
                                    }) {
                                        Text("Paylaş")
                                            .font(.headline)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(AppColorsTheme.gold)
                                            .cornerRadius(20)
                                    }
                                    .disabled(newPostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .opacity(newPostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6).opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    // Yorumlar listesi
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(comments) { comment in
                                CommentCard(comment: comment)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
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
                            UserDefaults.standard.set(false, forKey: "isLoggedIn")
                            UserDefaults.standard.removeObject(forKey: "username")
                            UserDefaults.standard.removeObject(forKey: "userEmail")
                            isLoggedIn = false
                            comments = []
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
                checkLoginStatus()
                loadComments()
            }
            .onChange(of: showingLoginView) { oldValue, newValue in
                checkLoginStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserLoggedIn"))) { _ in
                checkLoginStatus()
            }
        }
    }
    
    private func checkLoginStatus() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn {
            username = UserDefaults.standard.string(forKey: "username") ?? "Kullanıcı"
        }
    }
    
    private func addComment() {
        let trimmedText = newPostText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let newComment = CommunityComment(
            id: UUID().uuidString,
            username: username,
            content: trimmedText,
            timestamp: Date(),
            likes: 0,
            isLiked: false
        )
        
        comments.insert(newComment, at: 0)
        saveComments()
        newPostText = ""
    }
    
    private func loadComments() {
        if let data = UserDefaults.standard.data(forKey: "communityComments"),
           let savedComments = try? JSONDecoder().decode([CommunityComment].self, from: data) {
            comments = savedComments
        } else {
            // Demo yorumlar
            comments = [
                CommunityComment(
                    id: "1",
                    username: "CryptoExpert",
                    content: "Bitcoin'in son yükselişi gerçekten etkileyici! Uzun vadeli yatırımcılar için harika fırsatlar var.",
                    timestamp: Date().addingTimeInterval(-3600),
                    likes: 12,
                    isLiked: false
                ),
                CommunityComment(
                    id: "2",
                    username: "BlockchainFan",
                    content: "Ethereum'un yeni güncellemesi ile gas ücretleri düştü. DeFi projelerine yatırım yapmak için iyi bir zaman olabilir.",
                    timestamp: Date().addingTimeInterval(-7200),
                    likes: 8,
                    isLiked: false
                ),
                CommunityComment(
                    id: "3",
                    username: "AltcoinHunter",
                    content: "Küçük cap coinlerde dikkatli olmak lazım. DYOR (Do Your Own Research) unutmayın!",
                    timestamp: Date().addingTimeInterval(-10800),
                    likes: 15,
                    isLiked: false
                )
            ]
        }
    }
    
    private func saveComments() {
        if let data = try? JSONEncoder().encode(comments) {
            UserDefaults.standard.set(data, forKey: "communityComments")
        }
    }
}

// API modellerini yerel modellere dönüştürme uzantıları
extension GraphPoint {
    static func fromAPIModel(_ apiModel: APIService.APIGraphPoint) -> GraphPoint {
        return GraphPoint(
            timestamp: apiModel.timestamp,
            price: apiModel.price
        )
    }
}

// Basit AuthService tanımı
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            let user = User(
                id: "user123",
                username: UserDefaults.standard.string(forKey: "username") ?? "User",
                email: UserDefaults.standard.string(forKey: "userEmail") ?? "user@example.com",
                gender: "Other",
                country: "Global",
                phoneNumber: "",
                favoriteCoins: []
            )
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        // Demo giriş
        if email == "demo@example.com" && password == "123456" {
            let user = User(
                id: "user123",
                username: "DemoUser",
                email: email,
                gender: "Other",
                country: "Global",
                phoneNumber: "",
                favoriteCoins: ["bitcoin", "ethereum"]
            )
            
            self.currentUser = user
            self.isAuthenticated = true
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(user.username, forKey: "username")
            UserDefaults.standard.set(user.email, forKey: "userEmail")
            completion(true)
        } else {
            self.errorMessage = "Geçersiz giriş bilgileri"
            completion(false)
        }
    }
    
    func signUp(username: String, email: String, password: String, gender: String, country: String, phoneNumber: String, completion: @escaping (Bool) -> Void) {
        // Demo kayıt
        let user = User(
            id: UUID().uuidString,
            username: username,
            email: email,
            gender: gender,
            country: country,
            phoneNumber: phoneNumber,
            favoriteCoins: []
        )
        
        self.currentUser = user
        self.isAuthenticated = true
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(user.username, forKey: "username")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        completion(true)
    }
    
    func signOut(completion: @escaping (Bool) -> Void) {
        self.currentUser = nil
        self.isAuthenticated = false
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        completion(true)
    }
}

// Basit User modeli
struct User: Identifiable, Codable {
    let id: String
    let username: String
    let email: String
    let gender: String
    let country: String
    let phoneNumber: String
    var favoriteCoins: [String]
}

// Community Comment modeli
struct CommunityComment: Identifiable, Codable {
    let id: String
    let username: String
    let content: String
    let timestamp: Date
    var likes: Int
    var isLiked: Bool
}

// Comment Card View
struct CommentCard: View {
    @State var comment: CommunityComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kullanıcı bilgisi ve zaman
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColorsTheme.gold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.username)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(timeAgoString(from: comment.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Yorum içeriği
            Text(comment.content)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Beğeni butonu
            HStack {
                Button(action: {
                    toggleLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(comment.isLiked ? .red : .gray)
                        
                        Text("\(comment.likes)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
    
    private func toggleLike() {
        if comment.isLiked {
            comment.likes -= 1
            comment.isLiked = false
        } else {
            comment.likes += 1
            comment.isLiked = true
        }
        
        // Yorumları kaydet
        saveCommentUpdate()
    }
    
    private func saveCommentUpdate() {
        // UserDefaults'tan mevcut yorumları al
        if let data = UserDefaults.standard.data(forKey: "communityComments"),
           var savedComments = try? JSONDecoder().decode([CommunityComment].self, from: data) {
            
            // Bu yorumu güncelle
            if let index = savedComments.firstIndex(where: { $0.id == comment.id }) {
                savedComments[index] = comment
                
                // Geri kaydet
                if let updatedData = try? JSONEncoder().encode(savedComments) {
                    UserDefaults.standard.set(updatedData, forKey: "communityComments")
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Az önce"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) dakika önce"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) saat önce"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) gün önce"
        }
    }
}

// MARK: - More View
struct MoreView: View {
    @Binding var showingLoginView: Bool
    @State private var showingPopularCoins = false
    @State private var showingAIPortfolio = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Ana Özellikler
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Özellikler")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                Button(action: {
                                    showingPopularCoins = true
                                }) {
                                    MoreMenuRow(
                                        icon: "star.fill",
                                        title: "Popüler Coinler",
                                        subtitle: "En çok takip edilen coinler",
                                        color: AppColorsTheme.gold
                                    )
                                }
                                
                                Button(action: {
                                    showingAIPortfolio = true
                                }) {
                                    MoreMenuRow(
                                        icon: "brain.head.profile",
                                        title: "AI Coin Sepeti",
                                        subtitle: "Yapay zeka ile kişisel portföy önerisi",
                                        color: .purple
                                    )
                                }
                                

                            }
                            .padding(.horizontal)
                        }
                        
                        // Topluluk
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Topluluk")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                NavigationLink(destination: CommunityView(showingLoginView: $showingLoginView)) {
                                    MoreMenuRow(
                                        icon: "person.3.fill",
                                        title: "Community",
                                        subtitle: "Topluluk yorumları ve tartışmalar",
                                        color: .green
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Uygulama Bilgileri
                        VStack(spacing: 8) {
                            Text("CryptoBuddy v1.0.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("© 2024 CryptoBuddy. Tüm hakları saklıdır.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 30)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Yapay Zeka Sepeti")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingPopularCoins) {
            PopularCoinsView()
        }
        .sheet(isPresented: $showingAIPortfolio) {
            AIPortfolioView()
        }
    }
}

// More Menu Row
struct MoreMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Popüler Coinler View
struct PopularCoinsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var popularCoins: [Coin] = []
    @State private var isLoading = true
    @State private var selectedCoinID = ""
    @State private var showingCoinDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        
                        Text("Popüler coinler yükleniyor...")
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Başlık
                            VStack(spacing: 8) {
                                Text("🔥 Popüler Coinler")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("En çok takip edilen ve işlem gören coinler")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 20)
                            
                            // Coin listesi
                            LazyVStack(spacing: 12) {
                                ForEach(Array(popularCoins.enumerated()), id: \.element.id) { index, coin in
                                    Button(action: {
                                        selectedCoinID = coin.id
                                        showingCoinDetail = true
                                    }) {
                                        PopularCoinRow(coin: coin, rank: index + 1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Popüler Coinler")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(AppColorsTheme.gold))
            .onAppear {
                loadPopularCoins()
            }
            .sheet(isPresented: $showingCoinDetail) {
                CoinDetailView(coinId: selectedCoinID)
            }
        }
    }
    
    private func loadPopularCoins() {
        Task {
            do {
                let response = try await APIService.shared.fetchCoins(page: 1, perPage: 20)
                await MainActor.run {
                    self.popularCoins = response.coins
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct PopularCoinRow: View {
    let coin: Coin
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Sıralama
            ZStack {
                Circle()
                    .fill(AppColorsTheme.gold.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorsTheme.gold)
            }
            
            // Coin logosu
            if let url = URL(string: coin.image) {
                AsyncImage(url: url) { phase in
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
            }
            
            // Coin bilgileri
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(coin.symbol.uppercased())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Fiyat ve değişim
            VStack(alignment: .trailing, spacing: 4) {
                Text(coin.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: coin.change24h >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundColor(coin.change24h >= 0 ? .green : .red)
                    
                    Text(coin.formattedChange)
                        .font(.caption)
                        .foregroundColor(coin.change24h >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - AI Portfolio View
struct AIPortfolioView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentStep = 0
    @State private var budget = ""
    @State private var riskLevel = 1 // 1: Düşük, 2: Orta, 3: Yüksek
    @State private var investmentPeriod = 0 // 0: Kısa, 1: Orta, 2: Uzun
    @State private var coinCount = 5
    @State private var preferredCategories: Set<String> = []
    @State private var isGenerating = false
    @State private var generatedPortfolio: [AIPortfolioItem] = []
    @State private var showingResults = false
    
    let riskLevels = ["Düşük Risk", "Orta Risk", "Yüksek Risk"]
    let investmentPeriods = ["Kısa Vade (1-6 ay)", "Orta Vade (6-18 ay)", "Uzun Vade (1+ yıl)"]
    let categories = ["DeFi", "Layer 1", "Layer 2", "Meme Coins", "AI & Big Data", "Gaming", "NFT", "Stablecoins"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if showingResults {
                    AIPortfolioResultsView(
                        portfolio: generatedPortfolio,
                        budget: budget,
                        riskLevel: riskLevels[riskLevel],
                        period: investmentPeriods[investmentPeriod],
                        onClose: {
                            presentationMode.wrappedValue.dismiss()
                        },
                        onRegenerate: {
                            showingResults = false
                            generatePortfolio()
                        }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            // Başlık
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 50))
                                    .foregroundColor(.purple)
                                
                                Text("🤖 AI Coin Sepeti")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Yapay zeka ile kişiselleştirilmiş portföy önerisi alın")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 20)
                            
                            // Form Adımları
                            VStack(spacing: 25) {
                                // Bütçe
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("💰 Yatırım Bütçeniz")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    TextField("Örn: 10000", text: $budget)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.numberPad)
                                    
                                    Text("USD cinsinden toplam yatırım miktarınız")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Risk Seviyesi
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("⚡ Risk Seviyeniz")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Picker("Risk Seviyesi", selection: $riskLevel) {
                                        ForEach(0..<riskLevels.count, id: \.self) { index in
                                            Text(riskLevels[index]).tag(index)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    
                                    Text(getRiskDescription())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Yatırım Vadesi
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("⏰ Yatırım Vadesi")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Picker("Yatırım Vadesi", selection: $investmentPeriod) {
                                        ForEach(0..<investmentPeriods.count, id: \.self) { index in
                                            Text(investmentPeriods[index]).tag(index)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                                
                                // Coin Sayısı
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("🎯 Portföydeki Coin Sayısı: \(coinCount)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Slider(value: Binding(
                                        get: { Double(coinCount) },
                                        set: { coinCount = Int($0) }
                                    ), in: 3...15, step: 1)
                                    .accentColor(.purple)
                                    
                                    Text("Çeşitlendirme için önerilen: 5-10 coin")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Tercih Edilen Kategoriler
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("🏷️ İlgi Alanlarınız (Opsiyonel)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 8) {
                                        ForEach(categories, id: \.self) { category in
                                            Button(action: {
                                                if preferredCategories.contains(category) {
                                                    preferredCategories.remove(category)
                                                } else {
                                                    preferredCategories.insert(category)
                                                }
                                            }) {
                                                Text(category)
                                                    .font(.caption)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(preferredCategories.contains(category) ? .purple : Color(UIColor.systemGray6))
                                                    .foregroundColor(preferredCategories.contains(category) ? .white : .gray)
                                                    .cornerRadius(15)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Generate Button
                            Button(action: {
                                generatePortfolio()
                            }) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        
                                        Text("AI Analiz Ediyor...")
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("AI Portföy Oluştur")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.purple, .blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .disabled(budget.isEmpty || isGenerating)
                                .opacity(budget.isEmpty ? 0.6 : 1.0)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("AI Coin Sepeti")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(AppColorsTheme.gold))
        }
    }
    
    private func getRiskDescription() -> String {
        switch riskLevel {
        case 0: return "Stabil coinler ve büyük cap projeler"
        case 1: return "Dengeli portföy, orta cap coinler"
        case 2: return "Yüksek potansiyel, küçük cap coinler"
        default: return ""
        }
    }
    
    private func generatePortfolio() {
        isGenerating = true
        
        // Simulated AI analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let portfolio = AIPortfolioGenerator.generatePortfolio(
                budget: Double(budget) ?? 1000,
                riskLevel: riskLevel,
                period: investmentPeriod,
                coinCount: coinCount,
                categories: preferredCategories
            )
            
            self.generatedPortfolio = portfolio
            self.isGenerating = false
            self.showingResults = true
        }
    }
}

// AI Portfolio Item Model
struct AIPortfolioItem: Identifiable {
    let id = UUID()
    let coinName: String
    let symbol: String
    let allocation: Double // Yüzde
    let amount: Double // USD
    let reasoning: String
    let riskScore: Int // 1-5
    let category: String
    let imageUrl: String
}

// AI Portfolio Generator
struct AIPortfolioGenerator {
    static func generatePortfolio(
        budget: Double,
        riskLevel: Int,
        period: Int,
        coinCount: Int,
        categories: Set<String>
    ) -> [AIPortfolioItem] {
        
        var portfolio: [AIPortfolioItem] = []
        
        // Risk seviyesine göre coin dağılımı
        let coinData = getCoinDataByRisk(riskLevel: riskLevel, period: period, categories: categories)
        let selectedCoins = Array(coinData.shuffled().prefix(coinCount))
        
        // Allocation hesaplama (risk seviyesine göre)
        let allocations = calculateAllocations(coins: selectedCoins, riskLevel: riskLevel, coinCount: coinCount)
        
        for (index, coin) in selectedCoins.enumerated() {
            let allocation = allocations[index]
            let amount = budget * (allocation / 100)
            
            portfolio.append(AIPortfolioItem(
                coinName: coin.name,
                symbol: coin.symbol,
                allocation: allocation,
                amount: amount,
                reasoning: coin.reasoning,
                riskScore: coin.riskScore,
                category: coin.category,
                imageUrl: coin.imageUrl
            ))
        }
        
        return portfolio.sorted { $0.allocation > $1.allocation }
    }
    
    private static func getCoinDataByRisk(riskLevel: Int, period: Int, categories: Set<String>) -> [CoinData] {
        let allCoins = [
            // Düşük Risk
            CoinData(name: "Bitcoin", symbol: "BTC", category: "Layer 1", riskScore: 2, reasoning: "En güvenli ve likidite açısından en güçlü kripto para", imageUrl: "https://assets.coingecko.com/coins/images/1/large/bitcoin.png"),
            CoinData(name: "Ethereum", symbol: "ETH", category: "Layer 1", riskScore: 2, reasoning: "Smart contract lideri, güçlü ekosistem", imageUrl: "https://assets.coingecko.com/coins/images/279/large/ethereum.png"),
            CoinData(name: "BNB", symbol: "BNB", category: "Layer 1", riskScore: 3, reasoning: "Binance ekosistemi desteği", imageUrl: "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png"),
            
            // Orta Risk
            CoinData(name: "Cardano", symbol: "ADA", category: "Layer 1", riskScore: 3, reasoning: "Akademik yaklaşım, sürdürülebilir blockchain", imageUrl: "https://assets.coingecko.com/coins/images/975/large/cardano.png"),
            CoinData(name: "Solana", symbol: "SOL", category: "Layer 1", riskScore: 4, reasoning: "Yüksek performans, NFT ve DeFi ekosistemi", imageUrl: "https://assets.coingecko.com/coins/images/4128/large/solana.png"),
            CoinData(name: "Polygon", symbol: "MATIC", category: "Layer 2", riskScore: 3, reasoning: "Ethereum ölçeklendirme çözümü", imageUrl: "https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png"),
            CoinData(name: "Chainlink", symbol: "LINK", category: "DeFi", riskScore: 3, reasoning: "Oracle ağı lideri", imageUrl: "https://assets.coingecko.com/coins/images/877/large/chainlink-new-logo.png"),
            
            // Yüksek Risk
            CoinData(name: "Avalanche", symbol: "AVAX", category: "Layer 1", riskScore: 4, reasoning: "Hızlı büyüyen DeFi ekosistemi", imageUrl: "https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png"),
            CoinData(name: "Polkadot", symbol: "DOT", category: "Layer 1", riskScore: 4, reasoning: "Interoperability çözümü", imageUrl: "https://assets.coingecko.com/coins/images/12171/large/polkadot.png"),
            CoinData(name: "Uniswap", symbol: "UNI", category: "DeFi", riskScore: 4, reasoning: "DEX lideri, DeFi innovasyonu", imageUrl: "https://assets.coingecko.com/coins/images/12504/large/uniswap-uni.png"),
            CoinData(name: "Dogecoin", symbol: "DOGE", category: "Meme Coins", riskScore: 5, reasoning: "Topluluk desteği, mainstream kabul", imageUrl: "https://assets.coingecko.com/coins/images/5/large/dogecoin.png"),
            CoinData(name: "Shiba Inu", symbol: "SHIB", category: "Meme Coins", riskScore: 5, reasoning: "Güçlü topluluk, ekosistem geliştirme", imageUrl: "https://assets.coingecko.com/coins/images/11939/large/shiba.png")
        ]
        
        // Risk seviyesine göre filtrele
        let filteredByRisk = allCoins.filter { coin in
            switch riskLevel {
            case 0: return coin.riskScore <= 3 // Düşük risk
            case 1: return coin.riskScore >= 2 && coin.riskScore <= 4 // Orta risk
            case 2: return coin.riskScore >= 3 // Yüksek risk
            default: return true
            }
        }
        
        // Kategori tercihine göre filtrele
        if !categories.isEmpty {
            let categoryFiltered = filteredByRisk.filter { categories.contains($0.category) }
            return categoryFiltered.isEmpty ? filteredByRisk : categoryFiltered
        }
        
        return filteredByRisk
    }
    
    private static func calculateAllocations(coins: [CoinData], riskLevel: Int, coinCount: Int) -> [Double] {
        var allocations: [Double] = []
        
        switch riskLevel {
        case 0: // Düşük risk - büyük coinlere ağırlık
            let baseAllocation = 100.0 / Double(coinCount)
            for i in 0..<coinCount {
                if i < 2 { // İlk 2 coin daha fazla
                    allocations.append(baseAllocation * 1.5)
                } else {
                    allocations.append(baseAllocation * 0.75)
                }
            }
        case 1: // Orta risk - dengeli dağılım
            let baseAllocation = 100.0 / Double(coinCount)
            for _ in 0..<coinCount {
                allocations.append(baseAllocation)
            }
        case 2: // Yüksek risk - daha çeşitli dağılım
            let baseAllocation = 100.0 / Double(coinCount)
            for i in 0..<coinCount {
                let variation = Double.random(in: 0.7...1.3)
                allocations.append(baseAllocation * variation)
            }
        default:
            break
        }
        
        // Toplam 100% olacak şekilde normalize et
        let total = allocations.reduce(0, +)
        allocations = allocations.map { ($0 / total) * 100 }
        
        return allocations
    }
}

struct CoinData {
    let name: String
    let symbol: String
    let category: String
    let riskScore: Int
    let reasoning: String
    let imageUrl: String
}

// MARK: - AI Portfolio Results View
struct AIPortfolioResultsView: View {
    let portfolio: [AIPortfolioItem]
    let budget: String
    let riskLevel: String
    let period: String
    let onClose: () -> Void
    let onRegenerate: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Başlık
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("🎉 AI Portföyünüz Hazır!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Kişiselleştirilmiş coin sepetiniz oluşturuldu")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // Portföy Özeti
                VStack(spacing: 16) {
                    Text("📊 Portföy Özeti")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Toplam Bütçe:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(budget)")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Risk Seviyesi:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(riskLevel)
                                .fontWeight(.bold)
                                .foregroundColor(getRiskColor())
                        }
                        
                        HStack {
                            Text("Yatırım Vadesi:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(period)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Coin Sayısı:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(portfolio.count)")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Portföy Dağılımı
                VStack(spacing: 16) {
                    Text("💼 Önerilen Portföy")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(portfolio) { item in
                            AIPortfolioItemRow(item: item)
                        }
                    }
                }
                .padding(.horizontal)
                
                // AI Analiz Özeti
                VStack(spacing: 16) {
                    Text("🤖 AI Analiz Özeti")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        Text(getAIAnalysisSummary())
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Aksiyon Butonları
                VStack(spacing: 12) {
                    Button(action: onRegenerate) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Yeni Portföy Oluştur")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    Button(action: onClose) {
                        Text("Kapat")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray6).opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func getRiskColor() -> Color {
        switch riskLevel {
        case "Düşük Risk": return .green
        case "Orta Risk": return .orange
        case "Yüksek Risk": return .red
        default: return .white
        }
    }
    
    private func getAIAnalysisSummary() -> String {
        let totalCoins = portfolio.count
        let avgRisk = portfolio.reduce(0) { $0 + $1.riskScore } / totalCoins
        let topAllocation = portfolio.first?.allocation ?? 0
        
        return """
        Bu portföy, \(riskLevel.lowercased()) profilinize uygun olarak tasarlandı. Toplam \(totalCoins) coin ile çeşitlendirme sağlanmış, en yüksek ağırlık %\(String(format: "%.1f", topAllocation)) ile \(portfolio.first?.coinName ?? ""). 
        
        Ortalama risk skoru \(avgRisk)/5 seviyesinde. \(period.lowercased()) için optimize edilmiş bu portföy, piyasa dalgalanmalarına karşı dengeli bir yaklaşım sunuyor.
        
        ⚠️ Bu öneri yatırım tavsiyesi değildir. Kendi araştırmanızı yapın.
        """
    }
}

struct AIPortfolioItemRow: View {
    let item: AIPortfolioItem
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingDetails.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Coin logosu
                    if let url = URL(string: item.imageUrl) {
                        AsyncImage(url: url) { phase in
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
                    }
                    
                    // Coin bilgileri
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.coinName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Text(item.symbol.uppercased())
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(item.category)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.3))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    // Allocation ve miktar
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(String(format: "%.1f", item.allocation))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("$\(String(format: "%.0f", item.amount))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Risk göstergesi
                    VStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(index < item.riskScore ? getRiskColor(item.riskScore) : Color.gray.opacity(0.3))
                                .frame(width: 4, height: 4)
                        }
                    }
                    
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    Text("AI Analizi:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(item.reasoning)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func getRiskColor(_ risk: Int) -> Color {
        switch risk {
        case 1...2: return .green
        case 3: return .orange
        case 4...5: return .red
        default: return .gray
        }
    }
}

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
                    Text("Piyasa")
                }
            
            CommunityView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Community")
                }
            
            ProfileView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profil")
                }
            
            MoreView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Yapay Zeka Sepeti")
                }
        }
        .accentColor(AppColorsTheme.gold)
        .sheet(isPresented: $showingLoginView) {
            LoginView(isPresented: $showingLoginView)
        }
        .preferredColorScheme(.dark)
    }
}