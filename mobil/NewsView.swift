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
        // Simüle edilmiş veri
        return [
            NewsItem(
                id: UUID().uuidString,
                title: "Sample News Title",
                description: "This is a sample news description",
                url: "https://example.com",
                imageUrl: "https://example.com/image.jpg",
                publishedAt: Date(),
                source: "Sample Source",
                category: category
            )
        ]
    }
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
    
    private let newsService = NewsService.shared
    private var currentPage = 1
    
    func fetchNews() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let news = try await newsService.fetchNews(category: selectedCategory, page: currentPage)
            await MainActor.run {
                self.allNews = news
                self.filteredNews = news
                updateActiveSources()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error as? NewsError ?? .invalidResponse
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
            let news = try await newsService.fetchNews(category: selectedCategory, page: currentPage)
            await MainActor.run {
                self.allNews.append(contentsOf: news)
                self.filteredNews = self.allNews
                updateActiveSources()
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                currentPage -= 1
                isLoadingMore = false
            }
        }
    }
    
    func filterNews(with searchText: String) {
        if searchText.isEmpty {
            filteredNews = allNews
        } else {
            filteredNews = allNews.filter { news in
                news.title.localizedCaseInsensitiveContains(searchText) ||
                news.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func filterNews(by category: NewsService.NewsCategory) {
        if category == .all {
            filteredNews = allNews
        } else {
            filteredNews = allNews.filter { $0.category == category }
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
    @State private var searchText = ""
    @State private var selectedCategory: NewsService.NewsCategory = .all
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Kategori seçici
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(NewsService.NewsCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                    Task {
                                        await viewModel.fetchNews()
                                    }
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
                        
                        TextField("Search news...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { _ in
                                viewModel.filterNews(with: searchText)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.filterNews(with: "")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // API kaynakları
                    if !viewModel.filteredNews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Text("Sources:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(Array(viewModel.activeSources), id: \.self) { source in
                                    Text(source)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Haber listesi
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredNews) { news in
                                NewsCard(newsItem: news)
                                    .onTapGesture {
                                        if let url = URL(string: news.url) {
                                            selectedNewsURL = url
                                            showingSafari = true
                                        }
                                    }
                            }
                            
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.fetchNews()
                    }
                }
                
                // Yükleniyor göstergesi
                if viewModel.isLoading && viewModel.filteredNews.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                // Hata mesajı
                if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.fetchNews()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                }
            }
            .navigationTitle("Crypto News")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSafari) {
            if let url = selectedNewsURL {
                SafariView(url: url)
            }
        }
        .onAppear {
            if viewModel.filteredNews.isEmpty {
                Task {
                    await viewModel.fetchNews()
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .cornerRadius(20)
        }
    }
}

struct NewsCard: View {
    let newsItem: NewsService.NewsItem
    
    var body: some View {
        Link(destination: URL(string: newsItem.url)!) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: newsItem.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(height: 200)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(newsItem.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(newsItem.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Text(newsItem.source)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(newsItem.publishedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 3)
        }
        .buttonStyle(PlainButtonStyle())
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