import SwiftUI
import Charts
import Foundation

struct CoinListView: View {
    @StateObject private var viewModel = CoinListViewModel()
    @State private var showCoinDetail = false
    @State private var selectedCoinId: String? = nil
    @State private var isFirstLoad = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // API Kaynağı ve Yenileme Butonu
                if !viewModel.coins.isEmpty {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .foregroundColor(AppColorsTheme.gold)
                                .font(.caption)
                            Text("Kaynak: \(viewModel.currentAPI)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        
                        Spacer()
                        
                        Button(action: {
                            Task { 
                                await viewModel.refresh()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(AppColorsTheme.gold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                
                // List veya error/loading
                if viewModel.coins.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                    // İlk yükleme
                    Text("Coinler yükleniyor...")
                        .foregroundColor(.gray)
                        .onAppear {
                            if isFirstLoad {
                                Task {
                                    await viewModel.fetchCoins()
                                    isFirstLoad = false
                                }
                            }
                        }
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                            .padding(.bottom, 10)
                        
                        Text("Hata Oluştu")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            Task {
                                await viewModel.refresh()
                            }
                        }) {
                            Text("Tekrar Dene")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(AppColorsTheme.gold)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                        
                        // API kaynakları hakkında bilgi
                        VStack(alignment: .leading, spacing: 8) {
                            Text("İpucu:")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            
                            Text("Uygulamamız CoinGecko, CoinMarketCap, CoinStats, CoinCap, CryptoCompare, CoinLayer ve CoinPaprika API'lerini kullanır, internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                } else {
                    // Header
                    HStack {
                        Text("#")
                            .frame(width: 30, alignment: .center)
                        
                        Text("Coin")
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        Text("Fiyat")
                            .frame(width: 100, alignment: .trailing)
                        
                        Text("24s")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                    
                    // Coin Listesi
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(Array(viewModel.coins.enumerated()), id: \.element.id) { index, coin in
                                NavigationLink(destination: CoinDetailView(coinId: coin.id)) {
                                    CoinRowView(coin: coin, displayRank: index + 1)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Sonraki Sayfa Yükleme
                            if !viewModel.allPagesLoaded && !viewModel.isLoadingMore {
                                Button(action: {
                                    Task {
                                        await viewModel.loadMoreCoins()
                                    }
                                }) {
                                    Text("Daha Fazla Yükle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColorsTheme.gold)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                            } else if viewModel.allPagesLoaded && !viewModel.isLoadingMore {
                                Text("Tüm coinler yüklendi")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 10)
                            }
                            
                            if viewModel.isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                                        .scaleEffect(1.0)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            
            // CoinDetailView sheet
            .fullScreenCover(isPresented: $showCoinDetail) {
                if let coinId = selectedCoinId {
                    NavigationView {
                        CoinDetailView(coinId: coinId)
                            .navigationBarItems(leading: Button(action: {
                                self.showCoinDetail = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColorsTheme.gold)
                                    .imageScale(.large)
                                    .padding(8)
                            })
                    }
                }
            }
            
            // Tam ekran yükleme indikatörü
            if viewModel.isLoading && viewModel.coins.isEmpty {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                    
                    Text("Veriler yükleniyor...")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
            
            // Mini yükleme indikatörü (zaten veriler varken)
            if viewModel.isLoading && !viewModel.coins.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                            .padding(10)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.bottom, 20)
                            .padding(.trailing, 20)
                    }
                }
            }
        }
    }

    // Content View Preview
    struct CoinListView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                CoinListView()
            }
        }
    }
}

// CoinListViewModel'i daha verimli hale getirelim
final class CoinListViewModel: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String? = nil
    @Published var currentAPI = ""
    @Published var allPagesLoaded = false
    
    private var currentPage = 1
    private let coinsPerPage = 100 // 20'den 100'e çıkarıyoruz - daha çok coin görüntülenmesi için
    
    @MainActor
    func fetchCoins() async {
        isLoading = true
        do {
            // API'nin varsayılan olarak denendiğini belirten API kaynağı
            currentAPI = "API'ye bağlanıyor..."
            
            let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: coinsPerPage)
            let newCoins = fetchResult.coins
            let apiSource = fetchResult.source
            
            if currentPage == 1 {
                coins = newCoins
            } else {
                coins.append(contentsOf: newCoins)
            }
            
            // API kaynağını güncelle
            currentAPI = apiSource
            
            // Başarılı veri geldi mi kontrol et
            if newCoins.isEmpty && currentPage == 1 {
                errorMessage = "Hiç coin bulunamadı. Lütfen internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin."
            } else {
                // Tüm sayfalar yüklendi mi kontrol et
                allPagesLoaded = newCoins.count < coinsPerPage
                errorMessage = nil
            }
            
        } catch APIService.APIError.allAPIsFailed {
            errorMessage = "Hiçbir API kaynağından veri alınamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.\n\nİpucu: Uygulamamız CoinGecko, CoinMarketCap ve CoinCap API'lerini kullanır."
        } catch APIService.APIError.rateLimitExceeded {
            errorMessage = "API hız limiti aşıldı. Lütfen bir süre sonra tekrar deneyin.\n\nİpucu: Birkaç dakika bekleyip tekrar deneyin."
        } catch URLError.timedOut {
            errorMessage = "Sunucuya bağlanırken zaman aşımı oluştu. İnternet bağlantınızı kontrol edin."
        } catch URLError.notConnectedToInternet {
            errorMessage = "İnternet bağlantısı bulunamadı. Lütfen ağ ayarlarınızı kontrol edin ve Wi-Fi veya mobil verinin açık olduğundan emin olun."
        } catch {
            errorMessage = "Veri yüklenirken bir hata oluştu: \(error.localizedDescription)\n\nLütfen daha sonra tekrar deneyin."
        }
        isLoading = false
    }
    
    @MainActor
    func loadMoreCoins() async {
        guard !isLoadingMore else { return }
        
        // Eğer toplam coin sayısı 200'ü geçtiyse daha fazla yükleme
        if coins.count >= 200 {
            allPagesLoaded = true
            print("📱 Maksimum coin sayısına ulaşıldı (200+)")
            return
        }
        
        // Yüklemede değilse ve maksimum sayıya ulaşılmadıysa devam et
        isLoadingMore = true
        currentPage += 1
        
        print("📱 Sayfa \(currentPage) için yeni coinler yükleniyor...")
        
        do {
            // Her sayfada 20 coin yükleyelim
            let perPage = 20
            let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: perPage)
            let newCoins = fetchResult.coins
            
            print("📱 API'den \(newCoins.count) yeni coin alındı")
            
            if newCoins.isEmpty {
                // Hiç coin gelmezse tüm sayfalar yüklenmiş demektir
                allPagesLoaded = true
                print("📱 Tüm coinler yüklenmiş, başka coin yok")
            } else {
                // Mevcut coinlerin ID'lerini tutacak bir set oluştur
                let existingIds = Set(coins.map { $0.id })
                
                // Yalnızca yeni ve benzersiz coinleri filtrele
                let uniqueNewCoins = newCoins.filter { !existingIds.contains($0.id) }
                
                print("📱 Benzersiz coin sayısı: \(uniqueNewCoins.count)")
                
                if uniqueNewCoins.isEmpty {
                    // API farklı coinleri döndüremiyorsa, başka bir API servisine geçmeyi dene
                    print("📱 Bu API'den benzersiz coin kalmamış, farklı API denenecek")
                    // Bu sayfayı atlayıp bir sonraki sayfaya geç
                    currentPage += 1
                    await loadMoreCoins() // Rekursif çağrı
                    return
                } else {
                    // Yeni coinleri ekle
                    coins.append(contentsOf: uniqueNewCoins)
                    print("📱 Şu anki toplam coin sayısı: \(coins.count)")
                    
                    // Toplam coin sayısı kontrol et
                    if coins.count >= 200 {
                        allPagesLoaded = true
                        print("📱 Maksimum coin sayısına ulaşıldı (200+)")
                    } else {
                        // Eğer beklenenden az coin geldiyse, ama hala 200'den az coinimiz varsa devam et
                        allPagesLoaded = uniqueNewCoins.count < perPage && coins.count >= 200
                    }
                }
            }
        } catch {
            // Hata durumunda sayfa sayısını geri al
            currentPage -= 1
            errorMessage = "Daha fazla coin yüklenirken hata oluştu: \(error.localizedDescription)"
            print("❌ Hata: \(error.localizedDescription)")
        }
        
        isLoadingMore = false
    }
    
    @MainActor
    func refresh() async {
        // Sayfalama bilgilerini sıfırla
        currentPage = 1
        errorMessage = nil
        allPagesLoaded = false
        
        // Mevcut coin listesini temizle
        coins = []
        
        // API önbelleğini temizle
        APIService.shared.clearCoinsCache()
        
        // Yüklenen coin ID'lerini temizle
        APIService.shared.clearLoadedCoinIds()
        
        print("🔄 Coinler yenileniyor ve önbellek temizleniyor...")
        
        // Yeni coinleri yükle
        await fetchCoins()
    }
}

// Coin satırı görünümü
struct CoinRowView: View {
    let coin: Coin
    let displayRank: Int
    
    // Varsayılan değer ekleyelim
    init(coin: Coin, displayRank: Int? = nil) {
        self.coin = coin
        self.displayRank = displayRank ?? coin.rank
    }
    
    var body: some View {
        HStack(spacing: 5) {
            // Sıralama
            Text("\(displayRank)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .center)
            
            // Logo ve isim
            HStack(spacing: 8) {
                // Logo
                if let url = URL(string: coin.image) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 30, height: 30)
                        case .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(coin.symbol.prefix(1))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 30, height: 30)
                } else {
                    // Coin logosu yoksa sembolün ilk harfini göster
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(coin.symbol.prefix(1))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(coin.symbol)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            // Fiyat
            Text(coin.formattedPrice)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 100, alignment: .trailing)
            
            // 24 saatlik değişim
            HStack(spacing: 3) {
                Image(systemName: coin.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundColor(coin.changeColor)
                
                Text(coin.formattedChange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(coin.changeColor)
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.001)) // Daha iyi tap alanı için
    }
}

#Preview {
    NavigationView {
        CoinListView()
    }
} 
