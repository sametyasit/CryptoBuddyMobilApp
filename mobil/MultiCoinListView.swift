import SwiftUI
import Charts
import Foundation

struct MultiCoinListView: View {
    @StateObject private var viewModel = MultiCoinViewModel()
    @State private var selectedCoinId: String? = nil
    @State private var showCoinDetail = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // API source indicator and refresh button
                HStack {
                    if viewModel.isLoaded {
                        HStack(spacing: 6) {
                            ForEach(viewModel.activeAPIs, id: \.self) { source in
                                Text(source)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(viewModel.allCoins.count) Coins")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    } else {
                        Spacer()
                    }
                    
                    Button(action: {
                        viewModel.refreshCoins()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColorsTheme.gold)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Market stats overview
                if viewModel.isLoaded {
                    CoinMarketOverview()
                }
                
                // Headings
                CoinListHeader()
                
                // Main coin list
                if viewModel.isLoaded {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.allCoins.enumerated()), id: \.element.id) { index, coin in
                                Button(action: {
                                    print("🔍 Coin seçildi: \(coin.name) (\(coin.symbol)) - ID: \(coin.id)")
                                    selectedCoinId = coin.id
                                    showCoinDetail = true
                                }) {
                                    CoinRow(coin: coin, displayRank: index + 1)
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if !viewModel.isLoadingMore && !viewModel.isRefreshing && viewModel.hasMorePages {
                                Button(action: {
                                    viewModel.loadMoreCoins()
                                }) {
                                    HStack {
                                        Text("Load More")
                                            .font(.system(size: 16, weight: .medium))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(AppColorsTheme.gold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.darkGray).opacity(0.3))
                                    .cornerRadius(12)
                                    .padding()
                                }
                            } else if !viewModel.isLoadingMore && !viewModel.isRefreshing && !viewModel.hasMorePages {
                                Text("You've reached the end")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                                    .padding()
                            }
                        }
                    }
                    .refreshable {
                        viewModel.refreshCoins()
                    }
                } else if viewModel.isRefreshing {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        .scaleEffect(1.5)
                    Spacer()
                } else if let error = viewModel.error {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text("Unable to load coins")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(error)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button(action: {
                            viewModel.refreshCoins()
                        }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(AppColorsTheme.gold)
                                .cornerRadius(20)
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            if viewModel.allCoins.isEmpty {
                viewModel.refreshCoins()
            }
        }
        .fullScreenCover(isPresented: $showCoinDetail) {
            if let coinId = selectedCoinId {
                NavigationView {
                    CoinDetailView(coinId: coinId)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Kapat") {
                                    showCoinDetail = false
                                }
                                .foregroundColor(AppColorsTheme.gold)
                            }
                        }
                }
            }
        }
    }
}

struct CoinRow: View {
    let coin: Coin
    let displayRank: Int
    
    init(coin: Coin, displayRank: Int? = nil) {
        self.coin = coin
        self.displayRank = displayRank ?? coin.rank
    }
    
    var body: some View {
        HStack {
            // Rank & Image
            HStack(spacing: 12) {
                Text("\(displayRank)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 30, alignment: .center)
                
                // Logo görünümü - DirectCoinLogoView kullan
                DirectCoinLogoView(
                    symbol: coin.symbol,
                    size: 30,
                    coinId: coin.id,
                    imageUrl: coin.image
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(coin.symbol.uppercased())
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 170, alignment: .leading)
            
            Spacer()
            
            // Price
            Text(coin.formattedPrice)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 100, alignment: .trailing)
            
            // 24h Change
            HStack(spacing: 2) {
                Image(systemName: coin.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
                
                Text(coin.formattedChange)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
}

struct CoinListHeader: View {
    var body: some View {
        HStack {
            Text("Coin")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 170, alignment: .leading)
            
            Spacer()
            
            Text("Price")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .trailing)
            
            Text("24h")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(UIColor.darkGray).opacity(0.3))
    }
}

struct CoinMarketOverview: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Market cap
                VStack(spacing: 4) {
                    Text("Market Cap")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("$1.38T")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                // 24h Volume
                VStack(spacing: 4) {
                    Text("24h Volume")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("$42.8B")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                // BTC Dominance
                VStack(spacing: 4) {
                    Text("BTC Dom.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("48.2%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color(UIColor.darkGray).opacity(0.3))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }
}

// ViewModel for MultiCoinList
class MultiCoinViewModel: ObservableObject {
    @Published var allCoins: [Coin] = []
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var isLoaded = false
    @Published var error: String? = nil
    @Published var activeAPIs: [String] = []
    @Published var hasMorePages = true
    
    private let apiService = APIService.shared
    private var currentPage = 1
    private let coinsPerPage = 100 // 20'den 100'e çıkarıyoruz - daha çok coin yüklenecek
    private let logoPreloader = LogoPreloader.shared
    
    // Initialize and load coins
    init() {
        if allCoins.isEmpty {
            refreshCoins()
        }
    }
    
    // Refresh coin list (reset to page 1)
    func refreshCoins() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        currentPage = 1
        error = nil
        
        // Mevcut coinleri temizle ve tüm sayfalama bilgilerini sıfırla 
        allCoins = []
        hasMorePages = true
        
        // API önbelleğini temizle
        APIService.shared.clearCoinsCache()
        
        // Yüklenen coin ID'lerini temizle
        APIService.shared.clearLoadedCoinIds()
        
        print("🔄 Coinler yenileniyor ve önbellek temizleniyor...")
        
        Task {
            await fetchCoinData(isRefresh: true)
        }
    }
    
    // Load more coins (next page)
    func loadMoreCoins() {
        guard !isLoadingMore && !isRefreshing else { return }
        
        // Maksimum coin sınırını kontrol et
        if allCoins.count >= 200 {
            hasMorePages = false
            print("📊 Maksimum coin sayısına ulaşıldı (200+), daha fazla yüklenemiyor")
            return
        }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            await fetchCoinData(isRefresh: false)
        }
    }
    
    // Main fetch function
    @MainActor
    private func fetchCoinData(isRefresh: Bool) async {
        do {
            print("📊 \(isRefresh ? "Yenileniyor" : "Daha fazla yükleniyor") - Sayfa \(currentPage)")
            
            // Eğer maksimum coin sayısına ulaştıysak ve yenileme değilse, işlemi durdur
            if !isRefresh && allCoins.count >= 200 {
                hasMorePages = false
                isLoadingMore = false
                print("📊 Maksimum coin sayısına ulaşıldı (200+)")
                return
            }
            
            // Yüklemeye başladığını bildir
            if isRefresh {
                activeAPIs = ["Yükleniyor..."]
            }
            
            // Her seferinde 20 coin yükle
            let response = try await apiService.fetchCoins(page: currentPage, perPage: coinsPerPage)
            
            // Update active API source
            activeAPIs = [response.source]
            
            // Gelen veri boş mu kontrol et
            if response.coins.isEmpty && isRefresh {
                error = "Hiç coin bulunamadı. Lütfen internet bağlantınızı kontrol edin."
                isLoaded = false
                return
            }
            
            print("📊 API'den \(response.coins.count) coin alındı")
            
            // Update coins
            if isRefresh {
                // İlk yükleme veya yenileme - tüm listeyi sıfırlayıp yeni coinleri yükle
                allCoins = response.coins
                hasMorePages = response.coins.count >= coinsPerPage
                print("📊 Liste yenilendi: \(allCoins.count) coin")
                
                // Coin logolarını önbelleğe al
                logoPreloader.preloadLogos(for: response.coins)
            } else {
                // Gelen verileri incele
                if response.coins.isEmpty {
                    // Hiç coin yoksa, daha fazla yok demektir
                    hasMorePages = false
                    print("📊 Daha fazla coin yok")
                } else {
                    // Yeni sayfa yükleme - sadece benzersiz coinleri ekle
                    let existingIds = Set(allCoins.map { $0.id })
                    let uniqueNewCoins = response.coins.filter { !existingIds.contains($0.id) }
                    
                    print("�� Benzersiz coin sayısı: \(uniqueNewCoins.count)")
                    
                    if uniqueNewCoins.isEmpty {
                        // API farklı coinleri döndüremiyorsa, başka bir API servisine geçmeyi dene
                        print("📊 Bu API'den benzersiz coin kalmamış, farklı API denenecek")
                        // Bu sayfayı atlayıp bir sonraki sayfaya geç
                        currentPage += 1
                        await fetchCoinData(isRefresh: false) // Rekursif çağrı
                        return
                    } else {
                        // Yeni coinleri ekle
                        allCoins.append(contentsOf: uniqueNewCoins)
                        print("📊 Şu anki toplam coin sayısı: \(allCoins.count)")
                        
                        // Yeni eklenen coinlerin logolarını önbelleğe al
                        logoPreloader.preloadLogos(for: uniqueNewCoins)
                        
                        // Toplam coin sayısı kontrol et
                        if allCoins.count >= 200 {
                            hasMorePages = false
                            print("📊 Maksimum coin sayısına ulaşıldı (200+)")
                        } else {
                            // Eğer beklenenden az coin geldiyse, ama hala 200'den az coinimiz varsa devam et
                            hasMorePages = uniqueNewCoins.count >= coinsPerPage || allCoins.count < 200
                        }
                    }
                }
            }
            
            isLoaded = true
            error = nil
            
        } catch APIService.APIError.allAPIsFailed {
            self.error = "Hiçbir API kaynağından veri alınamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.\n\nUygulamamız CoinGecko, CoinMarketCap, CoinStats, CoinCap, CryptoCompare, CoinLayer ve CoinPaprika API'lerini kullanır."
        } catch APIService.APIError.rateLimitExceeded {
            self.error = "API hız limiti aşıldı. Lütfen bir süre sonra tekrar deneyin."
        } catch URLError.timedOut {
            self.error = "Sunucuya bağlanırken zaman aşımı oluştu. İnternet bağlantınızı kontrol edin."
        } catch URLError.notConnectedToInternet {
            self.error = "İnternet bağlantısı bulunamadı. Lütfen ağ ayarlarınızı kontrol edin."
        } catch {
            self.error = "Veri yüklenirken bir hata oluştu: \(error.localizedDescription)"
        }
        
        isRefreshing = false
        isLoadingMore = false
    }
} 