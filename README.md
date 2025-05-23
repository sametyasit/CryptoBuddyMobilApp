# CryptoBuddy - Kripto Para Haberleri

CryptoBuddy uygulamasının haber modülü, CryptoCompare API kullanarak kripto para haberleri sunan bir iOS uygulamasıdır. Bu modül, kullanıcılara gerçek zamanlı kripto para haberleri sağlar.

## Özellikler

- **Gerçek Zamanlı Haberler**: CryptoCompare API'den Türkçe kripto haberleri
- **5 Dakikada Bir Otomatik Yenileme**: En son haberleri görmek için manuel yenilemeye gerek yok
- **Aşağı Çekerek Yenileme**: İstediğiniz zaman haberleri manuel olarak yenileyebilirsiniz
- **Modern UI**: Koyu tema üzerinde altın renkli vurgular ile okunması kolay arayüz
- **Haber Zaman Göstergesi**: Her haberin ne kadar önce yayınlandığını gösterir (örn. "5 dakika önce")
- **Safari İçinde Haber Okuma**: "Haberi Oku" butonuna tıklayarak orijinal haber kaynağına gider
- **Hata Yönetimi**: İnternet bağlantısı sorunu veya API hataları için kullanıcı dostu mesajlar
- **Görsel Önbellek**: Daha hızlı yükleme için haber görselleri önbelleğe alınır

## Dosya Yapısı

- `Constants.swift`: API anahtarları ve uygulama sabitleri
- `NewsModel.swift`: Haber veri modeli
- `NetworkManager.swift`: API istekleri ve veri indirme işlemleri
- `NewsTableViewCell.swift`: Haber kartı tasarımı
- `NewsViewController.swift`: Ana haber akışı ekranı
- `AppDelegate.swift`: Uygulama başlatma ve konfigürasyon

## Kurulum

1. Projeyi klonlayın veya indirin
2. `Constants.swift` dosyasındaki `cryptoCompareAPIKey` değişkenine kendi API anahtarınızı ekleyin
   ```swift
   static let cryptoCompareAPIKey = "YOUR_API_KEY_HERE"
   ```
3. Projeyi Xcode'da açın ve çalıştırın

## API Anahtarı Alma

CryptoCompare API anahtarı almak için:

1. [CryptoCompare](https://min-api.cryptocompare.com/) websitesine gidin
2. Ücretsiz bir hesap oluşturun
3. API anahtarınızı alın
4. Bu anahtarı `Constants.swift` dosyasına ekleyin

## Teknolojiler ve Teknikler

- **UIKit**: Modern iOS UI bileşenleri
- **URLSession**: Asenkron ağ istekleri
- **Delegasyon Modeli**: Tablo görünümü veri yönetimi
- **NSCache**: Görsel önbelleğe alma
- **Auto Layout**: Responsif UI
- **Hafıza Yönetimi**: ARC ve weak/strong referanslar
- **Timer**: Otomatik yenileme için

## Özelleştirme

- **Yenileme Süresini Değiştirme**: `Constants.swift` dosyasında `refreshInterval` değerini değiştirin
- **UI Renklerini Değiştirme**: `Constants.swift` dosyasında renk değişkenlerini güncelleyin
- **Farklı Dilde Haberler**: API URL'inde `?lang=TR` parametresini değiştirin

## Geliştirme

Bu modülü şu yönlerde geliştirebilirsiniz:

1. Haber arama özelliği eklemek
2. Haber kategorilerini filtreleme
3. Sık kullanılan haberleri kaydetme
4. Birden fazla haber kaynağı entegrasyonu
5. Widget desteği eklemek

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Daha fazla bilgi için `LICENSE` dosyasına bakın. 