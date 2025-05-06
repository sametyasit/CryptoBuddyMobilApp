import SwiftUI

struct CoinDetailView: View {
    let coinId: String
    @Environment(\.presentationMode) var presentationMode
    @State private var coin: Coin?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedChartPeriod: ChartPeriod = .week
    
    enum ChartPeriod: String, CaseIterable, Identifiable {
        case day = "24s"
        case week = "1h"
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
            
            VStack(spacing: 0) {
                // Coin başlık ve bilgiler
                if let coin = coin {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Coin bilgisi
                            CoinHeaderView(coin: coin)
                                .padding(.horizontal)
                            
                            // Fiyat grafiği
                            if !coin.graphData.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Fiyat Grafiği")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    PriceChart(data: coin.graphData)
                                        .frame(height: 200)
                                }
                                .padding()
                                .background(AppColorsTheme.darkGray.opacity(0.3))
                                .cornerRadius(15)
                                .padding(.horizontal)
                            }
                            
                            // Market bilgileri
                            CoinMarketInfoView(coin: coin)
                                .padding(.horizontal)
                            
                            // Coin açıklaması (eğer varsa)
                            if !coin.description.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Hakkında")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(coin.description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil))
                                        .font(.body)
                                        .foregroundColor(.gray)
                                        .lineLimit(4)
                                }
                                .padding()
                                .background(AppColorsTheme.darkGray.opacity(0.3))
                                .cornerRadius(15)
                                .padding(.horizontal)
                            }
                            
                            // Bağlantılar / Links
                            if !coin.website.isEmpty || !coin.twitter.isEmpty || !coin.reddit.isEmpty || !coin.github.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Bağlantılar")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    HStack(spacing: 20) {
                                        if !coin.website.isEmpty {
                                            LinkButton(icon: "globe", url: coin.website)
                                        }
                                        
                                        if !coin.twitter.isEmpty {
                                            LinkButton(icon: "bird", url: coin.twitter)
                                        }
                                        
                                        if !coin.reddit.isEmpty {
                                            LinkButton(icon: "message.fill", url: coin.reddit)
                                        }
                                        
                                        if !coin.github.isEmpty {
                                            LinkButton(icon: "chevron.left.forwardslash.chevron.right", url: coin.github)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding()
                                .background(AppColorsTheme.darkGray.opacity(0.3))
                                .cornerRadius(15)
                                .padding(.horizontal)
                            }
                            
                            // Alt boşluk
                            Spacer(minLength: 40)
                        }
                        .padding(.top)
                    }
                } else if isLoading {
                    // Yükleme göstergesi
                    ProgressView("Yükleniyor...")
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        .foregroundColor(.white)
                        .padding()
                } else if let error = errorMessage {
                    // Hata mesajı
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(AppColorsTheme.gold)
                        
                        Text("Hata")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            loadCoinDetails()
                        }) {
                            Text("Tekrar Dene")
                                .foregroundColor(.black)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(AppColorsTheme.gold)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadCoinDetails()
        }
    }
    
    private func loadCoinDetails() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let coinDetail = try await APIService.shared.fetchCoinDetails(coinId: coinId)
                await MainActor.run {
                    self.coin = coinDetail
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Veri yüklenirken bir hata oluştu: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Coin üst bölüm
struct CoinHeaderView: View {
    let coin: Coin
    
    var body: some View {
        HStack {
            // Logo
            if let url = URL(string: coin.image) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .empty, .failure:
                        Image(systemName: "bitcoinsign.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(AppColorsTheme.gold)
                            .frame(width: 50, height: 50)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "bitcoinsign.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(AppColorsTheme.gold)
                    .frame(width: 50, height: 50)
            }
            
            // İsim ve sembol
            VStack(alignment: .leading) {
                Text(coin.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(coin.symbol)
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Fiyat ve değişim
            VStack(alignment: .trailing) {
                Text(coin.formattedPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(coin.formattedChange)
                    .font(.headline)
                    .foregroundColor(coin.changeColor)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

// Link butonu
struct LinkButton: View {
    let icon: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(AppColorsTheme.darkGray)
                .clipShape(Circle())
        }
    }
}

// Coin Market Bilgileri Görünümü
struct CoinMarketInfoView: View {
    let coin: Coin
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Market Bilgisi")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                DetailInfoView(title: "Market Cap", value: coin.formattedMarketCap)
                DetailInfoView(title: "Sıralama", value: "#\(coin.rank)")
                DetailInfoView(title: "İşlem Hacmi", value: coin.formattedVolume)
                DetailInfoView(title: "ATH", value: coin.formattedAth)
                DetailInfoView(title: "24s Yüksek", value: coin.formattedHigh24h)
                DetailInfoView(title: "24s Düşük", value: coin.formattedLow24h)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.3))
        .cornerRadius(15)
    }
}

// Detay bilgi hücresi
struct DetailInfoView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColorsTheme.darkGray.opacity(0.5))
        .cornerRadius(8)
    }
}

// Fiyat grafiği
struct PriceChart: View {
    let data: [GraphPoint]
    @State private var selectedPoint: GraphPoint? = nil
    
    var minValue: Double {
        data.map { $0.price }.min() ?? 0
    }
    
    var maxValue: Double {
        data.map { $0.price }.max() ?? 0
    }
    
    var latestPrice: Double {
        data.last?.price ?? 0
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack {
            // Seçili nokta bilgisi
            if let point = selectedPoint {
                HStack {
                    VStack(alignment: .leading) {
                        Text(dateFormatter.string(from: point.date))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(String(format: "$%.2f", point.price))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    let changePercent = ((point.price / latestPrice) - 1) * 100
                    Text(String(format: "%.2f%%", changePercent))
                        .foregroundColor(changePercent >= 0 ? .green : .red)
                        .font(.subheadline)
                }
                .padding(.bottom, 8)
            } else {
                HStack {
                    Text(String(format: "$%.2f", latestPrice))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            
            GeometryReader { geometry in
                ZStack {
                    // Çizgi grafiği
                    if data.count > 1 {
                        Path { path in
                            let step = geometry.size.width / CGFloat(data.count - 1)
                            let range = maxValue - minValue
                            
                            path.move(to: CGPoint(
                                x: 0,
                                y: geometry.size.height - CGFloat((data[0].price - minValue) / range) * geometry.size.height
                            ))
                            
                            for i in 1..<data.count {
                                let x = step * CGFloat(i)
                                let y = geometry.size.height - CGFloat((data[i].price - minValue) / range) * geometry.size.height
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(lineGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // Altlık alan
                        Path { path in
                            let step = geometry.size.width / CGFloat(data.count - 1)
                            let range = maxValue - minValue
                            
                            path.move(to: CGPoint(
                                x: 0,
                                y: geometry.size.height - CGFloat((data[0].price - minValue) / range) * geometry.size.height
                            ))
                            
                            for i in 1..<data.count {
                                let x = step * CGFloat(i)
                                let y = geometry.size.height - CGFloat((data[i].price - minValue) / range) * geometry.size.height
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                            path.closeSubpath()
                        }
                        .fill(areaGradient)
                        
                        // Etkileşimli dokunmatik alan
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let step = geometry.size.width / CGFloat(data.count - 1)
                                        let index = Int(value.location.x / step)
                                        if index >= 0 && index < data.count {
                                            selectedPoint = data[index]
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPoint = nil
                                    }
                            )
                    } else {
                        Text("Yeterli veri yok")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
    
    // Gradients
    var lineGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [AppColorsTheme.gold, .orange]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var areaGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                AppColorsTheme.gold.opacity(0.3),
                AppColorsTheme.gold.opacity(0.1),
                AppColorsTheme.gold.opacity(0.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// Ön izleme
struct CoinDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CoinDetailView(coinId: "bitcoin")
    }
} 