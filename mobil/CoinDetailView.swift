import SwiftUI
import SafariServices
import Charts

struct CoinDetailView: View {
    let coinId: String
    @State private var coin: Coin?
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedNewsURL: URL? = URL(string: "https://example.com")
    @State private var showingSafari = false
    @State private var graphData: [GraphPoint] = []
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var isLoadingGraph = false
    
    enum TimeFrame: String, CaseIterable, Identifiable {
        case day = "24s"
        case week = "7g"
        case month = "30g"
        case year = "1y"
        
        var id: String { self.rawValue }
        
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
                        HStack(spacing: 15) {
                            // Logo
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
                                            .frame(width: 60, height: 60)
                                            .foregroundColor(AppColorsTheme.gold)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "bitcoinsign.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(AppColorsTheme.gold)
                            }
                            
                            // İsim ve fiyat
                            VStack(alignment: .leading, spacing: 5) {
                                Text(coin.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(coin.symbol.uppercased())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Fiyat ve değişim
                            VStack(alignment: .trailing, spacing: 5) {
                                Text(coin.formattedPrice)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(coin.formattedChange)
                                    .font(.subheadline)
                                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.darkGray).opacity(0.3))
                        .cornerRadius(15)
                        
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
                            GridRow(title: "ATH", value: coin.formattedAth)
                            GridRow(title: "24s Yüksek", value: coin.formattedHigh24h)
                            GridRow(title: "24s Düşük", value: coin.formattedLow24h)
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
        
        Task {
            do {
                // Detaylı coin bilgilerini al
                let detailedCoin = try await APIService.shared.fetchCoinDetails(coinId: coinId)
                
                await MainActor.run {
                    self.coin = detailedCoin
                    self.isLoading = false
                    
                    // Grafik verisini yükle
                    loadGraphData(for: coinId, timeFrame: selectedTimeFrame)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Veri yüklenemedi: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
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
                    graphData = apiGraphData.map { point in
                        // APIGraphPoint'in timestamp'i zaten Double, onu direkt GraphPoint'e aktar
                        GraphPoint(timestamp: point.timestamp, price: point.price)
                    }
                    
                    print("📊 Grafik verileri: \(graphData.count) veri noktası")
                    isLoadingGraph = false
                }
            } catch {
                print("❌ Grafik verisi yüklenirken hata: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingGraph = false
                }
            }
        }
    }
}

// Yardımcı görünümler
struct GridRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
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
    
    @State private var news: [APIService.APINewsItem] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("İlgili Haberler")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                }
            } else {
                List(news) { newsItem in
                    Button(action: {
                        onNewsSelect(newsItem.url)
                    }) {
                        Text(newsItem.title)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct CoinDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CoinDetailView(coinId: "bitcoin")
    }
} 