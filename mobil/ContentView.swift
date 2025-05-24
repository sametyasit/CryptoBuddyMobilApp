import SwiftUI

struct ContentView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitorViewModel
    
    var body: some View {
        MainTabView()
            .onAppear {
                // APIService'e networkMonitor'u ver
                APIService.shared.configure(with: networkMonitor)
                
                // LogoPreloader AppDelegate'de zaten başlatılıyor
                // Burada sadece log göster
                print("📱 ContentView: Uygulama başlatıldı")
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 