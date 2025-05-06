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
                            .foregroundColor(AppColors.gold)
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
                            ForEach(viewModel.allCoins) { coin in
                                Button(action: {
                                    selectedCoinId = coin.id
                                    showCoinDetail = true
                                }) {
                                    CoinRow(coin: coin)
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if !viewModel.isLoadingMore && !viewModel.isRefreshing {
                                Button(action: {
                                    viewModel.loadMoreCoins()
                                }) {
                                    HStack {
                                        Text("Load More")
                                            .font(.system(size: 16, weight: .medium))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(AppColors.gold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.darkGray).opacity(0.3))
                                    .cornerRadius(12)
                                    .padding()
                                }
                            }
                            
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
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
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
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
                                .background(AppColors.gold)
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
                    TemporaryCoinDetailView(coinId: coinId)
                }
            }
        }
    }
}

struct CoinRow: View {
    let coin: Coin
    
    var body: some View {
        HStack {
            // Rank & Image
            HStack(spacing: 12) {
                Text("\(coin.rank)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 30, alignment: .center)
                
                CachedAsyncImage(url: URL(string: coin.image)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 30, height: 30)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "questionmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 30, height: 30)
                
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
    
    private let apiService = APIService.shared
    private var currentPage = 1
    private var hasMorePages = true
    private let coinsPerPage = 30
    
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
        
        Task {
            await fetchCoinData(isRefresh: true)
        }
    }
    
    // Load more coins (next page)
    func loadMoreCoins() {
        guard !isLoadingMore && !isRefreshing && hasMorePages else { return }
        
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
            let response = try await apiService.fetchCoins(page: currentPage, perPage: coinsPerPage)
            
            // Update active API source
            activeAPIs = [response.source]
            
            // Update coins
            if isRefresh {
                allCoins = response.coins
            } else {
                allCoins.append(contentsOf: response.coins)
            }
            
            // Set flags
            hasMorePages = response.coins.count >= coinsPerPage
            isLoaded = true
            error = nil
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isRefreshing = false
        isLoadingMore = false
    }
} 