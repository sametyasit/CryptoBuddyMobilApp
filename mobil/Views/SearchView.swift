import SwiftUI

struct SearchView: View {
    @Binding var showingLoginView: Bool
    @State private var searchText: String = ""
    @State private var coins: [Coin] = []
    @State private var isLoading = false
    @State private var selectedCoin: Coin? = nil
    @State private var showDetail = false
    @State private var showLogin: Bool = false
    // Simülasyon için, gerçek uygulamada UserDefaults veya AuthManager ile kontrol edilir
    @State private var isLoggedIn: Bool = false
    
    var filteredCoins: [Coin] {
        if searchText.isEmpty {
            return coins
        } else {
            return coins.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.symbol.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    // Arama kutusu
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.gray)
                            .padding(.leading, 10)
                        TextField("Search coins...", text: $searchText)
                            .foregroundColor(.white)
                            .padding(10)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.gray)
                                    .padding(.trailing, 10)
                            }
                        }
                    }
                    .background(Color(UIColor.darkGray).opacity(0.3))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        List(filteredCoins) { coin in
                            Button {
                                selectedCoin = coin
                                showDetail = true
                            } label: {
                                HStack(spacing: 12) {
                                    if let url = URL(string: coin.image), !coin.image.isEmpty {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fit)
                                        } placeholder: {
                                            Image(systemName: "bitcoinsign.circle")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .foregroundColor(.gray.opacity(0.3))
                                        }
                                        .frame(width: 32, height: 32)
                                    } else {
                                        Image(systemName: "bitcoinsign.circle")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundColor(.gray.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(coin.symbol)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(coin.name)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(coin.formattedPrice)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                    }
                }
                .sheet(isPresented: $showDetail) {
                    if let coin = selectedCoin {
                        CoinDetailView(coin: coin)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLoginView = true
                    }) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppColors.gold)
                            .imageScale(.large)
                    }
                }
            }
        }
        .onAppear {
            // Kullanıcı giriş yapmamışsa login göster
            if !isLoggedIn {
                showLogin = true
            } else if coins.isEmpty {
                loadCoins()
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView(isPresented: $showLogin)
        }
    }
    
    private func loadCoins() {
        isLoading = true
        Task {
            let result = await fetchCoins()
            await MainActor.run {
                self.coins = result
                self.isLoading = false
            }
        }
    }
    
    private func fetchCoins() async -> [Coin] {
        do {
            return try await APIService.shared.fetchCoins(page: 1, perPage: 100)
        } catch {
            return []
        }
    }
}

struct CoinDetailView: View {
    let coin: Coin
    var body: some View {
        VStack(spacing: 20) {
            if let url = URL(string: coin.image), !coin.image.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "bitcoinsign.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 80, height: 80)
            }
            Text(coin.name)
                .font(.title)
                .foregroundColor(.white)
            Text(coin.symbol)
                .font(.headline)
                .foregroundColor(.gray)
            Text("Price: \(coin.formattedPrice)")
                .font(.title2)
                .foregroundColor(.white)
            Text("Market Cap: \(coin.formattedMarketCap)")
                .font(.headline)
                .foregroundColor(.yellow)
            Text("24h Change: \(coin.formattedChange)")
                .font(.headline)
                .foregroundColor(coin.change24h >= 0 ? .green : .red)
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
} 