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
    
    private func loadPriceHistory(for coinId: String, period: ChartPeriod = .week) {
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
                Color.black.ignoresSafeArea()
                
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

// API modellerini yerel modellere dönüştürme uzantıları
extension GraphPoint {
    static func fromAPIModel(_ apiModel: APIService.APIGraphPoint) -> GraphPoint {
        return GraphPoint(
            timestamp: apiModel.timestamp,
            price: apiModel.price
        )
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


