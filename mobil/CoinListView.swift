import SwiftUI

struct CoinListView: View {
    @State private var coins: [Coin] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var currentAPI = "CoinGecko"
    
    var body: some View {
        ZStack {
            VStack {
                if !coins.isEmpty {
                    HStack {
                        Text("Data from: \(currentAPI)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        Spacer()
                    }
                }
                
                List {
                    ForEach(coins) { coin in
                        CoinRow(coin: coin)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    
                    if !coins.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: loadMoreCoins) {
                                Text("Load More")
                                    .foregroundColor(AppColors.gold)
                                    .padding()
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .background(AppColors.black)
                .listStyle(PlainListStyle())
                .refreshable {
                    currentPage = 1
                    await fetchCoins()
                }
            }
            
            if isLoading && coins.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry", role: .none) {
                Task {
                    currentPage = 1
                    await fetchCoins()
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            if coins.isEmpty {
                loadCoins()
            }
        }
    }
    
    private func loadCoins() {
        Task {
            await fetchCoins()
        }
    }
    
    private func loadMoreCoins() {
        currentPage += 1
        Task {
            await fetchCoins()
        }
    }
    
    private func fetchCoins() async {
        isLoading = true
        do {
            let newCoins = try await APIService.shared.fetchCoins(page: currentPage)
            if currentPage == 1 {
                coins = newCoins
            } else {
                coins.append(contentsOf: newCoins)
            }
            
            // Update the current API source based on the image URL pattern
            if let firstCoin = newCoins.first {
                if firstCoin.image.contains("assets.coincap.io") {
                    currentAPI = "CoinCap"
                } else if firstCoin.image.contains("bin.bnbstatic.com") {
                    currentAPI = "Binance"
                } else {
                    currentAPI = "CoinGecko"
                }
            }
        } catch APIError.allAPIsFailed {
            errorMessage = "Unable to fetch data from any API source. Please check your internet connection and try again."
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

struct CoinRow: View {
    let coin: Coin
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("#\(coin.rank)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .leading)
            
            // Coin logo
            AsyncImage(url: URL(string: coin.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 32, height: 32)
            
            // Coin name and symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(coin.symbol)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(coin.name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Price and change
            VStack(alignment: .trailing, spacing: 2) {
                Text(coin.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(coin.formattedChange)
                    .font(.subheadline)
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColors.darkGray)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        CoinListView()
    }
} 