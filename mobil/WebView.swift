import SwiftUI
import WebKit

struct WebViewContainer: View {
    let url: URL
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    UIApplication.shared.open(url)
                }) {
                    Image(systemName: "safari")
                        .padding()
                }
            }
            WebView(url: url)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Güncelleme gerekmiyor
    }
}
