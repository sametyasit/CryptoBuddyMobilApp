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
                            ForEach(viewModel.coins) { coin in
                                Button(action: {
                                    self.selectedCoinId = coin.id
                                    self.showCoinDetail = true
                                }) {
                                    CoinRowView(coin: coin)
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
        .fullScreenCover(isPresented: $showCoinDetail) {
            if let coinId = selectedCoinId {
                NavigationView {
                    CoinDetailView(coinId: coinId)
                        .navigationBarItems(leading: Button(action: {
                            self.showCoinDetail = false
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        })
                        .navigationBarTitleDisplayMode(.inline)
                }
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
    private let coinsPerPage = 20 // 30'dan 20'ye düşür - daha hızlı ilk yükleme
    
    @MainActor
    func fetchCoins() async {
        isLoading = true
        do {
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
            
            // Tüm sayfalar yüklendi mi kontrol et
            allPagesLoaded = newCoins.count < coinsPerPage
            
        } catch APIError.allAPIsFailed {
            errorMessage = "Hiçbir API kaynağından veri alınamadı. Lütfen internet bağlantınızı kontrol edin."
        } catch {
            errorMessage = "Veri yüklenirken bir hata oluştu: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    @MainActor
    func loadMoreCoins() async {
        guard !isLoadingMore, !allPagesLoaded else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: coinsPerPage)
            let newCoins = fetchResult.coins
            
            coins.append(contentsOf: newCoins)
            
            // Tüm sayfalar yüklendi mi kontrol et
            allPagesLoaded = newCoins.count < coinsPerPage
            
        } catch {
            // Hata durumunda sayfa sayısını geri al
            currentPage -= 1
            errorMessage = "Daha fazla coin yüklenirken hata oluştu."
        }
        
        isLoadingMore = false
    }
    
    @MainActor
    func refresh() async {
        currentPage = 1
        errorMessage = nil
        allPagesLoaded = false
        await fetchCoins()
    }
}

// Coin satırı görünümü
struct CoinRowView: View {
    let coin: Coin
    
    var body: some View {
        HStack(spacing: 5) {
            // Sıralama
            Text("\(coin.rank)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .center)
            
            // Logo ve isim
            HStack(spacing: 8) {
                if let url = URL(string: coin.image) {
                    CachedAsyncImage(url: url) { phase in
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
