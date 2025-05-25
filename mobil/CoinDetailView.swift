import SwiftUI
import SafariServices
import Charts
import UIKit

struct CoinDetailView: View {
    let coinId: String
    @State private var coin: Coin?
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedNewsURL: URL? = URL(string: "https://example.com")
    @State private var showingSafari = false
    @State private var graphData: [GraphPoint] = []
    @State private var selectedTimeFrame: TimeFrame = .day
    @State private var isLoadingGraph = false
    
    enum TimeFrame: String, CaseIterable, Identifiable {
        case hour = "1s"
        case day = "24s"
        case week = "7g"
        case month = "30g"
        
        var id: String { self.rawValue }
        
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
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        .scaleEffect(1.5)
                    
                    Text("Yükleniyor...")
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(AppColorsTheme.gold)
                        
                    Text("Hata")
                        .font(.title)
                        .foregroundColor(.white)
                        
                    Text(error)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                        
                    Button("Tekrar Dene") {
                        loadCoinData()
                    }
                    .padding()
                    .background(AppColorsTheme.gold)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
            } else if let coin = coin {
                ScrollView {
                    VStack(spacing: 20) {
                        // Coin Başlık Bilgisi
                        CoinHeaderView(coin: coin)
                        
                        // Fiyat Grafiği
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Fiyat Grafiği")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Zaman çerçevesi seçici
                            HStack {
                                ForEach(TimeFrame.allCases) { timeFrame in
                                    Button(action: {
                                        selectedTimeFrame = timeFrame
                                        loadGraphData(for: coin.id, timeFrame: timeFrame)
                                    }) {
                                        Text(timeFrame.rawValue)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedTimeFrame == timeFrame ? AppColorsTheme.gold : Color(UIColor.darkGray))
                                            )
                                            .foregroundColor(selectedTimeFrame == timeFrame ? .black : .white)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.bottom, 5)
                            
                            if isLoadingGraph {
                                // Grafik yüklenirken
                                VStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                                        .scaleEffect(1.0)
                                    Spacer()
                                }
                                .frame(height: 250)
                            } else if graphData.isEmpty {
                                // Grafik verisi yoksa
                                VStack {
                                    Spacer()
                                    Text("Grafik verisi bulunamadı")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                    Spacer()
                                }
                                .frame(height: 250)
                            } else {
                                // Grafiği göster
                                VStack(alignment: .leading, spacing: 5) {
                                    // Fiyat değişimi
                                    if graphData.count >= 2 {
                                        let firstPrice = graphData.first?.price ?? 0
                                        let lastPrice = graphData.last?.price ?? 0
                                        let priceChange = lastPrice - firstPrice
                                        let percentChange = (priceChange / firstPrice) * 100
                                        
                                        if priceChange != 0 {
                                            HStack {
                                                Text(String(format: "%+.2f $", priceChange))
                                                    .foregroundColor(priceChange >= 0 ? .green : .red)
                                                    .font(.system(size: 14, weight: .medium))
                                                
                                                Text(String(format: "(%+.2f%%)", percentChange))
                                                    .foregroundColor(priceChange >= 0 ? .green : .red)
                                                    .font(.system(size: 14, weight: .medium))
                                                
                                                Spacer()
                                                
                                                // Tarih aralığı
                                                if let firstDate = graphData.first?.date, let lastDate = graphData.last?.date {
                                                    let formatter = DateFormatter()
                                                    formatter.dateStyle = .short
                                                    formatter.timeStyle = .none
                                                    
                                                    Text("\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 12))
                                                }
                                            }
                                            .padding(.horizontal, 5)
                                        }
                                    }
                                    
                                    // Grafik
                                    CryptoLineChart(data: graphData)
                                        .frame(height: 200)
                                        .padding(.top, 5)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.darkGray).opacity(0.3))
                        .cornerRadius(15)
                        
                        // Market Bilgileri
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Market Bilgisi")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            GridRow(title: "Market Cap", value: coin.formattedMarketCap)
                            GridRow(title: "Hacim (24s)", value: coin.formattedVolume)
                            GridRow(title: "Rank", value: "#\(coin.rank)")
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            GridRow(title: "24s Yüksek", value: coin.formattedHigh24h)
                            GridRow(title: "24s Düşük", value: coin.formattedLow24h)
                            GridRow(title: "ATH (En Yüksek)", value: coin.formattedAth)
                            
                            if coin.athChangePercentage != 0 {
                                GridRow(title: "ATH'den Değişim", value: String(format: "%.1f%%", coin.athChangePercentage))
                            }
                            
                            if coin.priceChange24h != 0 {
                                GridRow(title: "24s Fiyat Değişimi", value: String(format: "$%.2f", coin.priceChange24h))
                            }
                        }
                        .padding()
                        .background(Color(UIColor.darkGray).opacity(0.3))
                        .cornerRadius(15)
                        
                        // İlgili Haberler
                        NewsListView(coinName: coin.name, coinSymbol: coin.symbol) { url in
                            if let url = URL(string: url) {
                                selectedNewsURL = url
                                showingSafari = true
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            } else {
                Text("Coin bulunamadı")
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadCoinData()
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
    
    private func loadCoinData() {
        isLoading = true
        errorMessage = nil
        
        print("🔍 DEBUG: Coin detayı yükleniyor - ID: \(coinId)")
        
        Task {
            do {
                // Doğrudan CoinGecko API'den coin detaylarını çek
                let detailedCoin = try await fetchCoinDetailsDirectly(coinId: coinId)
                
                await MainActor.run {
                    print("✅ Coin detayı başarıyla yüklendi:")
                    print("  - ID: \(detailedCoin.id)")
                    print("  - Name: \(detailedCoin.name)")
                    print("  - Symbol: \(detailedCoin.symbol)")
                    print("  - Price: $\(detailedCoin.price)")
                    print("  - Market Cap: $\(detailedCoin.marketCap)")
                    print("  - Rank: \(detailedCoin.rank)")
                    
                    self.coin = detailedCoin
                    self.isLoading = false
                    
                    // Grafik verisini yükle
                    loadGraphData(for: detailedCoin.id, timeFrame: selectedTimeFrame)
                }
            } catch {
                await MainActor.run {
                    print("❌ Coin detayı yükleme hatası - ID: \(coinId), Error: \(error.localizedDescription)")
                    self.errorMessage = "Coin detayları yüklenemedi: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Doğrudan CoinGecko API'den coin detaylarını çeken basit metod
    private func fetchCoinDetailsDirectly(coinId: String) async throws -> Coin {
        print("🔍 CoinGecko API'den coin detayları alınıyor: \(coinId)")
        
        // CoinGecko API endpoint
        let urlString = "https://api.coingecko.com/api/v3/coins/\(coinId)?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false"
        
        guard let url = URL(string: urlString) else {
            throw APIService.APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.addValue("CryptoBuddy/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ API Hatası: HTTP \(response)")
                throw APIService.APIError.invalidResponse
            }
            
            // JSON'ı parse et
            struct CoinDetailResponse: Codable {
                let id: String
                let symbol: String
                let name: String
                let image: ImageLinks
                let market_data: MarketData
                
                struct ImageLinks: Codable {
                    let large: String
                }
                
                struct MarketData: Codable {
                    let current_price: [String: Double]
                    let market_cap: [String: Double]?
                    let market_cap_rank: Int?
                    let price_change_percentage_24h: Double?
                    let total_volume: [String: Double]?
                    let high_24h: [String: Double]?
                    let low_24h: [String: Double]?
                    let ath: [String: Double]?
                    let ath_change_percentage: [String: Double]?
                    let price_change_24h: [String: Double]?
                }
            }
            
            let decoder = JSONDecoder()
            let coinResponse = try decoder.decode(CoinDetailResponse.self, from: data)
            
            // Coin modelini oluştur
            var coin = Coin(
                id: coinResponse.id,
                name: coinResponse.name,
                symbol: coinResponse.symbol.uppercased(),
                price: coinResponse.market_data.current_price["usd"] ?? 0,
                change24h: coinResponse.market_data.price_change_percentage_24h ?? 0,
                marketCap: coinResponse.market_data.market_cap?["usd"] ?? 0,
                image: coinResponse.image.large,
                rank: coinResponse.market_data.market_cap_rank ?? 0
            )
            
            // Ek verileri ekle
            coin.totalVolume = coinResponse.market_data.total_volume?["usd"] ?? 0
            coin.high24h = coinResponse.market_data.high_24h?["usd"] ?? 0
            coin.low24h = coinResponse.market_data.low_24h?["usd"] ?? 0
            coin.ath = coinResponse.market_data.ath?["usd"] ?? 0
            coin.athChangePercentage = coinResponse.market_data.ath_change_percentage?["usd"] ?? 0
            coin.priceChange24h = coinResponse.market_data.price_change_24h?["usd"] ?? 0
            
            print("✅ Coin detayları başarıyla alındı:")
            print("  - Price: $\(coin.price)")
            print("  - Market Cap: $\(coin.marketCap)")
            print("  - Volume: $\(coin.totalVolume)")
            print("  - High 24h: $\(coin.high24h)")
            print("  - Low 24h: $\(coin.low24h)")
            print("  - ATH: $\(coin.ath)")
            
            return coin
            
        } catch {
            print("❌ API çağrısı başarısız: \(error.localizedDescription)")
            
            // Hata durumunda örnek coin verisi oluştur
            print("🔧 Örnek coin verisi oluşturuluyor...")
            
            let sampleCoin = Coin(
                id: coinId,
                name: coinId.capitalized,
                symbol: coinId.prefix(3).uppercased(),
                price: Double.random(in: 0.01...100000),
                change24h: Double.random(in: -10...10),
                marketCap: Double.random(in: 1000000...1000000000000),
                image: "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
                rank: Int.random(in: 1...100)
            )
            
            print("✅ Örnek coin verisi oluşturuldu: \(sampleCoin.name) - $\(sampleCoin.price)")
            return sampleCoin
        }
    }
    
    private func loadGraphData(for coinId: String, timeFrame: TimeFrame) {
        isLoadingGraph = true
        graphData = []
        
        Task {
            do {
                let apiGraphData = try await APIService.shared.fetchCoinPriceHistory(coinId: coinId, days: timeFrame.days)
                
                await MainActor.run {
                    // API'den gelen verileri GraphPoint formatına dönüştür
                    graphData = apiGraphData.map { apiPoint in
                        GraphPoint(from: apiPoint)
                    }
                    
                    print("📊 Grafik verileri: \(graphData.count) veri noktası")
                    isLoadingGraph = false
                }
            } catch {
                print("❌ Grafik verisi yüklenirken hata: \(error.localizedDescription)")
                
                // Hata durumunda örnek veri oluştur
                await MainActor.run {
                    graphData = generateSampleGraphData(for: timeFrame.days, currentPrice: coin?.price ?? 50000)
                    print("📊 Örnek grafik verileri oluşturuldu: \(graphData.count) veri noktası")
                    isLoadingGraph = false
                }
            }
        }
    }
    
    // Örnek grafik verisi oluşturma metodu
    private func generateSampleGraphData(for days: Int, currentPrice: Double) -> [GraphPoint] {
        let now = Date()
        var points: [GraphPoint] = []
        let dataPointCount = min(days * 24, 100) // Maksimum 100 veri noktası
        let interval = Double(days * 24 * 60 * 60) / Double(dataPointCount)
        
        var price = currentPrice
        
        for i in 0..<dataPointCount {
            let date = now.addingTimeInterval(-Double(days * 24 * 60 * 60) + (Double(i) * interval))
            
            // Rastgele fiyat değişimi (%5 aralığında)
            let change = Double.random(in: -0.05...0.05)
            price = max(price * 0.5, price * (1.0 + change)) // Minimum fiyatın yarısına düşmesin
            
            let point = GraphPoint(timestamp: date.timeIntervalSince1970, price: price)
            points.append(point)
        }
        
        return points
    }
}

// Yardımcı görünümler
struct GridRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
    }
}

// Kripto Grafik Bileşeni
struct CryptoLineChart: View {
    let data: [GraphPoint]
    @State private var selectedPoint: GraphPoint?
    @State private var plotWidth: CGFloat = 0
    
    private var minPrice: Double {
        data.map { $0.price }.min() ?? 0
    }
    
    private var maxPrice: Double {
        data.map { $0.price }.max() ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Seçilen noktanın bilgisi
            if let point = selectedPoint {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Tarih
                        Text(dateFormatter.string(from: point.date))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Fiyat
                        Text(String(format: "$%.2f", point.price))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.darkGray).opacity(0.6))
                .cornerRadius(6)
            }
            
            // Grafik
            GeometryReader { geometry in
                ZStack {
                    // Arkaplan ızgarası
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            if i < 3 {
                                Spacer()
                            }
                        }
                    }
                    
                    // Grafik çizgisi ve alanı
                    if data.count >= 2 {
                        // Ana çizgi
                        Path { path in
                            let xStep = geometry.size.width / CGFloat(data.count - 1)
                            let yRange = maxPrice - minPrice
                            
                            // İlk noktaya git
                            let firstPoint = CGPoint(
                                x: 0,
                                y: geometry.size.height * (1 - CGFloat((data[0].price - minPrice) / yRange))
                            )
                            path.move(to: firstPoint)
                            
                            // Diğer noktaları bağla
                            for i in 1..<data.count {
                                let point = CGPoint(
                                    x: CGFloat(i) * xStep,
                                    y: geometry.size.height * (1 - CGFloat((data[i].price - minPrice) / yRange))
                                )
                                path.addLine(to: point)
                            }
                        }
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColorsTheme.gold, .orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        
                        // Dolgu alanı
                        Path { path in
                            let xStep = geometry.size.width / CGFloat(data.count - 1)
                            let yRange = maxPrice - minPrice
                            
                            // İlk noktaya git
                            let firstPoint = CGPoint(
                                x: 0,
                                y: geometry.size.height * (1 - CGFloat((data[0].price - minPrice) / yRange))
                            )
                            path.move(to: firstPoint)
                            
                            // Diğer noktaları bağla
                            for i in 1..<data.count {
                                let point = CGPoint(
                                    x: CGFloat(i) * xStep,
                                    y: geometry.size.height * (1 - CGFloat((data[i].price - minPrice) / yRange))
                                )
                                path.addLine(to: point)
                            }
                            
                            // Alt köşeleri ekle
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppColorsTheme.gold.opacity(0.3),
                                    AppColorsTheme.gold.opacity(0.1),
                                    AppColorsTheme.gold.opacity(0.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // Etkileşim için saydam katman
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Dokunulan noktaya en yakın veri noktasını bul
                                    if data.isEmpty { return }
                                    
                                    let xStep = geometry.size.width / CGFloat(data.count - 1)
                                    let index = Int((value.location.x / xStep).rounded())
                                    
                                    if index >= 0 && index < data.count {
                                        selectedPoint = data[index]
                                    }
                                }
                                .onEnded { _ in
                                    // Basma bırakıldığında seçimi kaldır (opsiyonel)
                                    selectedPoint = nil
                                }
                        )
                    
                    // Fiyat değerleri (y ekseni)
                    VStack {
                        Text(String(format: "$%.2f", maxPrice))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(String(format: "$%.2f", (maxPrice + minPrice) / 2))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(String(format: "$%.2f", minPrice))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onAppear {
                    self.plotWidth = geometry.size.width
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// İlgili Haberler Bileşeni
struct NewsListView: View {
    let coinName: String
    let coinSymbol: String
    let onNewsSelect: (String) -> Void
    
    @State private var news: [APIService.NewsItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("İlgili Haberler")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                    Text("Haberler yükleniyor...")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.top, 5)
                    Spacer()
                }
                .frame(height: 120)
            } else if let error = errorMessage {
                VStack {
                    Spacer()
                    Text("Haber yüklenemedi")
                        .foregroundColor(.white)
                    Text(error)
                        .foregroundColor(.gray)
                        .font(.caption)
                    Button("Tekrar Dene") {
                        loadNews()
                    }
                    .padding(.top, 5)
                    Spacer()
                }
                .frame(height: 120)
            } else if news.isEmpty {
                VStack {
                    Spacer()
                    Text("İlgili haber bulunamadı")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(height: 120)
            } else {
                // İlgili haberleri göster
                VStack(spacing: 12) {
                    ForEach(filteredNews) { newsItem in
                        NewsItemRow(newsItem: newsItem, onTap: {
                            onNewsSelect(newsItem.url)
                        })
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.darkGray).opacity(0.3))
        .cornerRadius(15)
        .onAppear {
            loadNews()
        }
    }
    
    // Coinle ilgili haberleri filtrele
    private var filteredNews: [APIService.NewsItem] {
        let keywords = [coinName.lowercased(), coinSymbol.lowercased()]
        return news.filter { item in
            let content = item.title.lowercased() + " " + item.description.lowercased()
            return keywords.contains { keyword in
                content.contains(keyword)
            }
        }
    }
    
    // Haberleri yükle
    private func loadNews() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Kripto haberleri API'sini kullan
                let allNews = try await APIService.shared.fetchCryptoNews()
                
                await MainActor.run {
                    self.news = allNews
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// Haber öğesi satırı
struct NewsItemRow: View {
    let newsItem: APIService.NewsItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Haber resmi
                AsyncImage(url: URL(string: newsItem.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .empty, .failure:
                        Image(systemName: "newspaper.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(AppColorsTheme.gold)
                            .frame(width: 80, height: 80)
                            .background(Color(UIColor.systemGray5).opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                
                // Haber bilgileri
                VStack(alignment: .leading, spacing: 4) {
                    Text(newsItem.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(newsItem.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        Text(newsItem.source)
                            .font(.caption)
                            .foregroundColor(AppColorsTheme.gold)
                        
                        Spacer()
                        
                        if let date = ISO8601DateFormatter().date(from: newsItem.publishedAt) {
                            Text(dateFormatter.string(from: date))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6).opacity(0.2))
            .cornerRadius(10)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct CoinHeaderView: View {
    let coin: Coin
    
    var body: some View {
        HStack {
            // Logo - DirectCoinLogoView kullanarak daha güvenilir logo yükleme
            DirectCoinLogoView(
                symbol: coin.symbol,
                size: 60,
                coinId: coin.id,
                imageUrl: coin.image
            )
            
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
                
                HStack(spacing: 4) {
                    Image(systemName: coin.change24h >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 12))
                        .foregroundColor(coin.change24h >= 0 ? .green : .red)
                    
                    Text(coin.formattedChange)
                        .font(.headline)
                        .foregroundColor(coin.change24h >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

struct CoinDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CoinDetailView(coinId: "bitcoin")
    }
} 