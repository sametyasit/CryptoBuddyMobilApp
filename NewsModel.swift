import Foundation

// API'den gelen yanıtın yapısını tanımlama
struct NewsResponse: Codable {
    let Data: [News]
    let Type: Int
    let Message: String
}

// Haber modeli
struct News: Codable {
    let id: String
    let guid: String
    let published_on: Int
    let title: String
    let url: String
    let imageurl: String
    let source: String
    let body: String
    let tags: String
    let categories: String
    
    // Haberin yayınlanma tarihini Date formatında almak için
    var publishedDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(published_on))
    }
    
    // Tarih formatını "X dakika/saat/gün önce" formatına çevirme
    func timeAgoString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfMonth, .month, .year], from: publishedDate, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 yıl önce" : "\(year) yıl önce"
        }
        
        if let month = components.month, month > 0 {
            return month == 1 ? "1 ay önce" : "\(month) ay önce"
        }
        
        if let week = components.weekOfMonth, week > 0 {
            return week == 1 ? "1 hafta önce" : "\(week) hafta önce"
        }
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Dün" : "\(day) gün önce"
        }
        
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 saat önce" : "\(hour) saat önce"
        }
        
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 dakika önce" : "\(minute) dakika önce"
        }
        
        return "Az önce"
    }
} 