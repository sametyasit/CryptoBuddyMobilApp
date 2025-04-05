import SwiftUI

struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    @State private var showingLoginView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Text("Unable to load news")
                            .foregroundColor(.red)
                            .font(.headline)
                        
                        Text(error.localizedDescription)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.refreshNews()
                            }
                        }
                        .foregroundColor(AppColors.gold)
                        .padding()
                        .background(Color(UIColor.darkGray))
                        .cornerRadius(10)
                    }
                } else if viewModel.news.isEmpty {
                    Text("No news available")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.news) { newsItem in
                                NewsItemCard(newsItem: newsItem)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshNews()
                    }
                }
            }
            .navigationTitle("Crypto News")
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await viewModel.refreshNews()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColors.gold)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startNewsUpdates()
        }
        .onDisappear {
            viewModel.stopNewsUpdates()
        }
        .sheet(isPresented: $showingLoginView) {
            LoginView(isPresented: $showingLoginView)
        }
    }
}

struct NewsItemCard: View {
    let newsItem: NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with source and date
            HStack {
                Text(newsItem.source)
                    .font(.caption)
                    .foregroundColor(AppColors.gold)
                
                Spacer()
                
                Text(formatDate(newsItem.publishedAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // News Image
            if let url = URL(string: newsItem.imageUrl), !newsItem.imageUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.largeTitle)
                            )
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.gold))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Title and Description
            VStack(alignment: .leading, spacing: 8) {
                Text(newsItem.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if !newsItem.description.isEmpty {
                    Text(newsItem.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
            }
            
            // Read More Button
            if let url = URL(string: newsItem.url) {
                Link(destination: url) {
                    HStack {
                        Text("Read More")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.gold)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.darkGray))
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(UIColor.darkGray).opacity(0.5))
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

class NewsViewModel: ObservableObject {
    @Published var news: [NewsItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func startNewsUpdates() {
        Task {
            await refreshNews()
        }
        
        APIService.shared.startNewsUpdates { [weak self] news in
            DispatchQueue.main.async {
                self?.news = news
                self?.isLoading = false
                self?.error = nil
            }
        }
    }
    
    func stopNewsUpdates() {
        APIService.shared.stopNewsUpdates()
    }
    
    @MainActor
    func refreshNews() async {
        isLoading = true
        error = nil
        
        do {
            news = try await APIService.shared.fetchNews()
        } catch {
            self.error = error
            print("Error refreshing news: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    NewsView()
} 