import SwiftUI
import Charts
import Foundation
import UIKit // UIImage için gerekli

// MARK: - Main View
struct CoinListView: View {
    @StateObject private var viewModel = CoinListViewModel()
    @State private var showCoinDetail = false
    @State private var selectedCoinId: String? = nil
    @State private var isFirstLoad = true
    
    var body: some View {
        ZStack {
            // Arkaplan
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Ana içerik
            mainContent
            
            // Yükleme göstergeleri
            loadingOverlays
        }
    }
    
    // MARK: - Ana içerik bileşenleri
    
    // Ana içerik
    private var mainContent: some View {
        VStack {
            // Yenileme butonu
            refreshButtonIfNeeded
            
            // Ana içerik alanı
            contentArea
        }
        .fullScreenCover(isPresented: $showCoinDetail) {
            detailScreen
        }
    }
}

// MARK: - CoinListView+ Ana Bileşenler
extension CoinListView {
    // Yenileme butonu (gerekirse göster)
    private var refreshButtonIfNeeded: some View {
        Group {
            if !viewModel.coins.isEmpty {
                HStack {
                    Spacer()
                    
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColorsTheme.gold)
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
    
    // İçerik alanı (boş durum, hata veya liste)
    private var contentArea: some View {
        Group {
            if viewModel.coins.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                emptyInitialView
            } else if let message = viewModel.errorMessage {
                errorContentView(message: message)
            } else {
                coinsListContent
            }
        }
    }
    
    // Coin detay ekranı
    private var detailScreen: some View {
        Group {
            if let coinId = selectedCoinId {
                NavigationView {
                    CoinDetailView(coinId: coinId)
                        .navigationBarItems(leading: Button {
                            showCoinDetail = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                                .padding(8)
                        })
                }
            }
        }
    }
    
    // Yükleme göstergeleri
    private var loadingOverlays: some View {
        Group {
            if viewModel.isLoading && viewModel.coins.isEmpty {
                fullscreenLoadingView
            }
            
            if viewModel.isLoading && !viewModel.coins.isEmpty {
                overlayLoadingView
            }
        }
    }
}

// MARK: - CoinListView+ İçerik Bileşenleri
extension CoinListView {
    // İlk yükleme boş görünümü
    private var emptyInitialView: some View {
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
    }
    
    // Hata durumu görünümü
    private func errorContentView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
                .padding(.bottom, 10)
            
            Text("Hata Oluştu")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Tekrar Dene")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(AppColorsTheme.gold)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
            
            apiInfoView
        }
        .padding()
    }
    
    // API yardım metni
    private var apiInfoView: some View {
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
}

// MARK: - CoinListView+ Coin Liste Bileşenleri
extension CoinListView {
    // Coin listesi içeriği
    private var coinsListContent: some View {
        VStack {
            // Başlık
            listHeaderView
            
            // Liste
            coinsList
        }
    }
    
    // Liste başlığı
    private var listHeaderView: some View {
        HStack {
            Text("#").frame(width: 30, alignment: .center)
            Text("Coin").frame(width: 120, alignment: .leading)
            Spacer()
            Text("Fiyat").frame(width: 100, alignment: .trailing)
            Text("24s").frame(width: 70, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.gray)
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    // Coin listesi
    private var coinsList: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                // Coin satırları
                coinsRows
                
                // Sayfalama ve yükleme
                paginationArea
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // Coin satırları
    private var coinsRows: some View {
        ForEach(Array(viewModel.coins.enumerated()), id: \.element.id) { index, coin in
            NavigationLink(destination: CoinDetailView(coinId: coin.id)) {
                CoinCellView(coin: coin, displayRank: index + 1)
                    .padding(.horizontal)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // Sayfalama alanı
    private var paginationArea: some View {
        Group {
            if !viewModel.allPagesLoaded && !viewModel.isLoadingMore {
                loadMoreButtonView
            } else if viewModel.allPagesLoaded && !viewModel.isLoadingMore {
                allLoadedView
            }
            
            if viewModel.isLoadingMore {
                loadingIndicator
            }
        }
    }
    
    // Daha fazla yükle butonu
    private var loadMoreButtonView: some View {
        Button {
            Task { await viewModel.loadMoreCoins() }
        } label: {
            HStack(spacing: 8) {
                Text("Daha Fazla Yükle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("(\(viewModel.coins.count)/\(viewModel.maxCoins))")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.7))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AppColorsTheme.gold)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // Tüm coinler yüklendi görünümü
    private var allLoadedView: some View {
        VStack(spacing: 4) {
            Text("Tüm coinler yüklendi")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Text("Toplam \(viewModel.coins.count) coin")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.vertical, 10)
    }
    
    // Yükleme göstergesi
    private var loadingIndicator: some View {
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

// MARK: - CoinCellView Bileşeni
struct CoinCellView: View {
    let coin: Coin
    let displayRank: Int
    
    var body: some View {
        HStack(spacing: 5) {
            // Sıralama
            Text("\(displayRank)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .center)
            
            // Logo ve isim
            HStack(spacing: 8) {
                // Logo görünümü - Basitleştirilmiş placeholder
                CirclePlaceholder(symbol: coin.symbol, size: 30)
                
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
        .background(Color.black.opacity(0.001)) // Daha iyi tap alanı için
    }
}

// Basit logo placeholder (CoinLogoView yerine)
struct CirclePlaceholder: View {
    let symbol: String
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(generateColorForSymbol(symbol))
            .frame(width: size, height: size)
            .overlay(
                Text(symbol.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    // Coin sembolünden tutarlı bir renk üret
    private func generateColorForSymbol(_ symbol: String) -> Color {
        var hash = 0
        
        for char in symbol {
            let unicodeValue = Int(char.unicodeScalars.first?.value ?? 0)
            hash = ((hash << 5) &- hash) &+ unicodeValue
        }
        
        let red = CGFloat(abs(hash) % 255) / 255.0
        let green = CGFloat(abs(hash * 33) % 255) / 255.0
        let blue = CGFloat(abs(hash * 77) % 255) / 255.0
        
        return Color(
            red: max(0.4, red),
            green: max(0.4, green),
            blue: max(0.4, blue)
        )
    }
}

// MARK: - CoinListView+ Yükleme Göstergeleri
extension CoinListView {
    // Tam ekran yükleme görünümü
    private var fullscreenLoadingView: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                
                Text("Veriler yükleniyor...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
        }
    }
    
    // Ek yükleme göstergesi
    private var overlayLoadingView: some View {
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

// MARK: - Previews
struct CoinListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CoinListView()
        }
    }
}

// MARK: - ViewModel
final class CoinListViewModel: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String? = nil
    @Published var allPagesLoaded = false
    
    private var currentPage = 1
    private let coinsPerPage = 100 // 20'den 100'e çıkarıyoruz - daha çok coin görüntülenmesi için
    // Maksimum coin sayısı 200'den 1000'e çıkarıldı
    let maxCoins = 1000
    
    @MainActor
    func fetchCoins() async {
        isLoading = true
        do {
            // Coinleri API'den getir
            let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: coinsPerPage)
            let newCoins = fetchResult.coins
            
            if currentPage == 1 {
                coins = newCoins
            } else {
                coins.append(contentsOf: newCoins)
            }
            
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
        
        // Eğer toplam coin sayısı maksimum değeri geçtiyse daha fazla yükleme
        if coins.count >= maxCoins {
            allPagesLoaded = true
            print("📱 Maksimum coin sayısına ulaşıldı (\(maxCoins)+)")
            return
        }
        
        // Yüklemede değilse ve maksimum sayıya ulaşılmadıysa devam et
        isLoadingMore = true
        currentPage += 1
        
        print("📱 Sayfa \(currentPage) için yeni coinler yükleniyor...")
        
        do {
            // Her sayfada 100 coin yükleyelim - daha hızlı yükleme için sayıyı artırdık
            let perPage = 100
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
                    if coins.count >= maxCoins {
                        allPagesLoaded = true
                        print("📱 Maksimum coin sayısına ulaşıldı (\(maxCoins)+)")
                    } else {
                        // Eğer beklenenden az coin geldiyse, ama hala maksimum sayıdan az coinimiz varsa devam et
                        allPagesLoaded = uniqueNewCoins.count < perPage && coins.count >= maxCoins
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
