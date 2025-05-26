import SwiftUI
import Foundation

struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if isLoggedIn {
                    // Oturumlu kullanıcı
                    PortfolioContent()
                } else {
                    // Oturum açılmamış
                    VStack(spacing: 25) {
                        Image(systemName: "lock.shield")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(goldColor)
                        
                        Text("Portföyünüzü görüntülemek için giriş yapın")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Portföyünüzü takip etmek, coinleri kaydetmek ve daha fazlası için hesabınıza giriş yapın.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Text("Giriş Yap")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(goldColor)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 50)
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Portföy", displayMode: .inline)
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

struct PortfolioContent: View {
    @State private var favoriteCoins: [Coin] = []
    @State private var isLoading = true
    @State private var totalPortfolioValue: Double = 0
    @State private var portfolioChangePercentage: Double = 0
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Portföy özeti kartı
                VStack(spacing: 15) {
                    Text("Portföy Değeri")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        Text("$\(String(format: "%.2f", totalPortfolioValue))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack {
                            Image(systemName: portfolioChangePercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundColor(portfolioChangePercentage >= 0 ? .green : .red)
                            
                            Text("\(portfolioChangePercentage >= 0 ? "+" : "")\(String(format: "%.2f", portfolioChangePercentage))%")
                                .foregroundColor(portfolioChangePercentage >= 0 ? .green : .red)
                                .font(.headline)
                            
                            Text("son 24 saat")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray6).opacity(0.2))
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Gösterge paneli
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    PortfolioStatCard(
                        title: "Toplam Varlık",
                        value: "\(favoriteCoins.count)",
                        icon: "bitcoinsign.circle.fill"
                    )
                    
                    PortfolioStatCard(
                        title: "En İyi Performans",
                        value: isLoading ? "Yükleniyor..." : (favoriteCoins.isEmpty ? "N/A" : "\(String(format: "+%.2f", favoriteCoins.map { $0.change24h }.max() ?? 0))%"),
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .padding(.horizontal)
                
                // Favori coinler
                VStack(alignment: .leading) {
                    Text("Favori Coinler")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if favoriteCoins.isEmpty {
                        VStack(spacing: 15) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 40))
                                .foregroundColor(goldColor)
                                .padding(.top)
                            
                            Text("Henüz favori coin eklemediniz")
                                .foregroundColor(.gray)
                            
                            Text("Market sayfasından coinleri favorilere ekleyebilirsiniz")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.systemGray6).opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    } else {
                        ForEach(favoriteCoins) { coin in
                            NavigationLink(destination: CoinDetailView(coinId: coin.id)) {
                                FavoriteCoinRow(coin: coin)
                            }
                        }
                    }
                }
                .padding(.top)
            }
            .padding(.top)
        }
        .onAppear {
            loadFavoriteCoins()
        }
    }
    
    private func loadFavoriteCoins() {
        isLoading = true
        
        // Demo veriler göster
            // Demo veriler
            Task {
                do {
                    let response = try await APIService.shared.fetchCoins(page: 1, perPage: 3)
                    DispatchQueue.main.async {
                        self.favoriteCoins = response.coins
                        self.calculatePortfolioValue()
                        self.isLoading = false
                    }
                } catch {
                    print("Error loading demo coins: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
    }
    
    private func calculatePortfolioValue() {
        // Basit bir hesaplama için tüm favorilerin toplam değeri
        // Gerçek uygulamada burada kullanıcının sahip olduğu miktar da hesaba katılacak
        totalPortfolioValue = favoriteCoins.reduce(0) { $0 + $1.price }
        
        // Değişim yüzdesi (ağırlıklı ortalama)
        let totalValue = favoriteCoins.reduce(0.0) { $0 + $1.price }
        portfolioChangePercentage = favoriteCoins.reduce(0.0) { 
            $0 + ($1.change24h * ($1.price / totalValue))
        }
    }
}

struct PortfolioStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(goldColor)
                
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(15)
    }
}

struct FavoriteCoinRow: View {
    let coin: Coin
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        HStack(spacing: 15) {
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
                            .foregroundColor(goldColor)
                            .frame(width: 40, height: 40)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(goldColor)
                    .frame(width: 40, height: 40)
            }
            
            // Coin bilgileri
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .foregroundColor(.white)
                    .font(.headline)
                
                Text(coin.symbol.uppercased())
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            
            Spacer()
            
            // Fiyat ve değişim bilgileri
            VStack(alignment: .trailing, spacing: 4) {
                Text(coin.formattedPrice)
                    .foregroundColor(.white)
                    .font(.headline)
                
                Text("\(coin.change24h >= 0 ? "+" : "")\(coin.formattedChange)")
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
                    .font(.footnote)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct PortfolioView_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioView(showingLoginView: .constant(false))
            .preferredColorScheme(.dark)
    }
} 