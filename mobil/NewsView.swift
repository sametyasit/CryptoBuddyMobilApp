import SwiftUI
import SafariServices

// MARK: - Error Types
enum NewsError: Error {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case allAPIsFailed
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Error parsing data"
        case .allAPIsFailed:
            return "Unable to fetch news from any source"
        case .invalidData:
            return "Invalid data received from server"
        }
    }
}

// MARK: - News Service
final class NewsService {
    static let shared = NewsService()
    private init() {}
    
    private let apiKey = "c1086e4db7b5078baef89a7a374128c506a68d2aea26e434640986920610af78" // Replace with your CryptoCompare API key
    private let baseURL = "https://min-api.cryptocompare.com/data/v2/news/"
    
    enum NewsCategory: String, CaseIterable {
        case all = "All"
        case trading = "Trading"
        case technology = "Technology"
        case regulation = "Regulation"
        case mining = "Mining"
        case defi = "DeFi"
        case nft = "NFT"
        case metaverse = "Metaverse"
    }
    
    struct NewsItem: Identifiable, Hashable {
        let id: String
        let title: String
        let description: String
        let url: String
        let imageUrl: String
        let publishedAt: Date
        let source: String
        let category: NewsCategory
        
        static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    func fetchNews(category: NewsCategory = .all, page: Int = 1) async throws -> [NewsItem] {
        var urlComponents = URLComponents(string: "\(baseURL)")!
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "lang", value: "EN")
        ]
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NewsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NewsError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            let newsResponse = try decoder.decode(CryptoCompareResponse.self, from: data)
            
            // API'den gelen verileri NewsItem'a dönüştür
            return newsResponse.Data.map { news in
                NewsItem(
                    id: news.id,
                    title: news.title,
                    description: news.body,
                    url: news.url,
                    imageUrl: news.imageurl,
                    publishedAt: Date(timeIntervalSince1970: TimeInterval(news.published_on)),
                    source: news.source,
                    category: determineCategory(from: news.categories)
                )
            }
        } catch {
            print("Decoding error: \(error)")
            throw NewsError.decodingError
        }
    }
    
    private func determineCategory(from categories: String) -> NewsCategory {
        let lowercasedCategories = categories.lowercased()
        
        if lowercasedCategories.contains("trading") {
            return .trading
        } else if lowercasedCategories.contains("technology") {
            return .technology
        } else if lowercasedCategories.contains("regulation") {
            return .regulation
        } else if lowercasedCategories.contains("mining") {
            return .mining
        } else if lowercasedCategories.contains("defi") {
            return .defi
        } else if lowercasedCategories.contains("nft") {
            return .nft
        } else if lowercasedCategories.contains("metaverse") {
            return .metaverse
        }
        
        return .all
    }
}

// CryptoCompare API Response Models
private struct CryptoCompareResponse: Codable {
    let Data: [CryptoCompareNews]
}

private struct CryptoCompareNews: Codable {
    let id: String
    let title: String
    let body: String
    let url: String
    let imageurl: String
    let published_on: Int
    let source: String
    let categories: String
}

// MARK: - View Model
final class NewsViewModel: ObservableObject {
    @Published var allNews: [NewsService.NewsItem] = []
    @Published var filteredNews: [NewsService.NewsItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: NewsError?
    @Published var selectedCategory: NewsService.NewsCategory = .all
    @Published var activeSources: Set<String> = []
    @Published var searchText: String = ""
    
    private let newsService = NewsService.shared
    private var currentPage = 1
    private var timer: Timer?
    
    func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.fetchNews(force: true) }
        }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchNews(force: Bool = false) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        do {
            let news = try await newsService.fetchNews(category: .all, page: 1)
            await MainActor.run {
                self.allNews = news
                self.applyFilters()
                updateActiveSources()
                isLoading = false
                currentPage = 1
            }
        } catch let error as NewsError {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = .networkError
                self.isLoading = false
            }
        }
    }
    
    func loadMoreNews() async {
        guard !isLoadingMore else { return }
        await MainActor.run {
            isLoadingMore = true
            currentPage += 1
        }
        do {
            let news = try await newsService.fetchNews(category: .all, page: currentPage)
            await MainActor.run {
                self.allNews.append(contentsOf: news)
                self.applyFilters()
                updateActiveSources()
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                currentPage -= 1
                isLoadingMore = false
                self.error = error as? NewsError ?? .networkError
            }
        }
    }
    
    func selectCategory(_ category: NewsService.NewsCategory) {
        selectedCategory = category
        applyFilters()
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        applyFilters()
    }
    
    private func applyFilters() {
        if !searchText.isEmpty {
            filteredNews = allNews.filter { news in
                news.title.localizedCaseInsensitiveContains(searchText) ||
                news.description.localizedCaseInsensitiveContains(searchText)
            }
        } else if selectedCategory != .all {
            filteredNews = allNews.filter { $0.category == selectedCategory }
        } else {
            filteredNews = allNews
        }
    }
    
    private func updateActiveSources() {
        activeSources = Set(filteredNews.map { $0.source.components(separatedBy: ":").first ?? "" })
    }
}

// MARK: - Views
struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    @State private var showingSafari = false
    @State private var selectedNewsURL: URL?
    @State private var showError = false
    @State private var showingNewsDetail = false
    @State private var selectedNews: NewsService.NewsItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Kategori seçici
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(NewsService.NewsCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    title: category.rawValue,
                                    isSelected: viewModel.selectedCategory == category
                                ) {
                                    viewModel.selectCategory(category)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Arama çubuğu
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search news...", text: Binding(
                            get: { viewModel.searchText },
                            set: { viewModel.updateSearchText($0) }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.updateSearchText("")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.darkGray).opacity(0.3))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // Haber listesi
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredNews) { news in
                                NewsCard(news: news)
                                    .onTapGesture {
                                        selectedNews = news
                                        showingNewsDetail = true
                                    }
                                    .onAppear {
                                        if news == viewModel.filteredNews.last {
                                            Task {
                                                await viewModel.loadMoreNews()
                                            }
                                        }
                                    }
                            }
                            
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewsDetail) {
                if let news = selectedNews {
                    NewsDetailView(news: news)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchNews()
                }
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
}

struct NewsCard: View {
    let news: NewsService.NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Haber görseli
            AsyncImage(url: URL(string: news.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(UIColor.darkGray).opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color(UIColor.darkGray).opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.gold)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(16)
            
            // Haber başlığı
            Text(news.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            // Haber açıklaması
            Text(news.description)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(3)
            
            HStack {
                // Kaynak ve tarih
                VStack(alignment: .leading, spacing: 4) {
                    Text(news.source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.gold)
                    
                    Text(news.publishedAt, style: .relative)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Kategori etiketi
                Text(news.category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.gold.opacity(0.2))
                    .foregroundColor(AppColors.gold)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.darkGray).opacity(0.3))
        )
    }
}

struct NewsDetailView: View {
    let news: NewsService.NewsItem
    @Environment(\.presentationMode) var presentationMode
    @State private var showingSafari = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Haber görseli
                    AsyncImage(url: URL(string: news.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(UIColor.darkGray).opacity(0.3))
                                .frame(height: 250)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color(UIColor.darkGray).opacity(0.3))
                                .frame(height: 250)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 50))
                                        .foregroundColor(AppColors.gold)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(16)
                    
                    // Haber başlığı
                    Text(news.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Kaynak ve tarih
                    HStack {
                        Text(news.source)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.gold)
                        
                        Spacer()
                        
                        Text(news.publishedAt, style: .relative)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    // Kategori etiketi
                    Text(news.category.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.gold.opacity(0.2))
                        .foregroundColor(AppColors.gold)
                        .cornerRadius(8)
                    
                    // Haber açıklaması
                    Text(news.description)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                    
                    // Haber linki
                    Button(action: {
                        showingSafari = true
                    }) {
                        HStack {
                            Text("Read Full Article")
                                .font(.system(size: 16, weight: .medium))
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundColor(AppColors.gold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.gold.opacity(0.1))
                        )
                    }
                }
                .padding()
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            )
            .sheet(isPresented: $showingSafari) {
                if let url = URL(string: news.url) {
                    SafariView(url: url)
                }
            }
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AppColors.gold : Color(UIColor.darkGray).opacity(0.3))
                )
                .foregroundColor(isSelected ? .black : .white)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NewsView()
} 






