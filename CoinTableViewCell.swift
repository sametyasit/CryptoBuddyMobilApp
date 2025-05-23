import UIKit

class CoinTableViewCell: UITableViewCell {
    
    static let identifier = "CoinTableViewCell"
    
    // MARK: - UI Elemanları
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = Constants.UI.cellCornerRadius
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rankLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let coinImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.layer.cornerRadius = 15
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let symbolLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let changeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // Coin logo hata sayısı - yeniden deneme için
    private var logoErrorCount = 0
    private var currentCoin: Coin?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        
        containerView.addSubview(rankLabel)
        containerView.addSubview(coinImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(symbolLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(changeLabel)
        
        coinImageView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            
            // Rank label
            rankLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            rankLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 25),
            
            // Coin image view
            coinImageView.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 8),
            coinImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            coinImageView.widthAnchor.constraint(equalToConstant: 30),
            coinImageView.heightAnchor.constraint(equalToConstant: 30),
            
            // Name label
            nameLabel.leadingAnchor.constraint(equalTo: coinImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -10),
            
            // Symbol label
            symbolLabel.leadingAnchor.constraint(equalTo: coinImageView.trailingAnchor, constant: 12),
            symbolLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            symbolLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            // Price label
            priceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            priceLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            
            // Change label
            changeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            changeLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4),
            changeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: coinImageView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: coinImageView.centerYAnchor),
        ])
    }
    
    // MARK: - Configure
    
    func configure(with coin: Coin) {
        currentCoin = coin
        logoErrorCount = 0
        
        rankLabel.text = coin.marketCapRank != nil ? "\(coin.marketCapRank!)" : "N/A"
        nameLabel.text = coin.name
        symbolLabel.text = coin.symbol.uppercased()
        priceLabel.text = coin.formattedPrice()
        
        let priceChangeText = coin.formattedPriceChange()
        changeLabel.text = priceChangeText
        changeLabel.textColor = coin.isPriceChangePositive ? UIColor.green : UIColor.red
        
        activityIndicator.startAnimating()
        
        // Önce en iyi logo URL'sini kontrol et
        if let bestLogoURL = CryptoDataService.shared.getBestLogoURL(for: coin.symbol) {
            // En iyi URL varsa onu kullan
            loadCoinImageFromBestSource(coin, bestURL: bestLogoURL)
        } else {
            // Yoksa normal yükleme algoritmasını kullan
            loadCoinImage(coin)
        }
    }
    
    // En iyi logo URL'sinden görsel yükleme
    private func loadCoinImageFromBestSource(_ coin: Coin, bestURL: String) {
        ImageCacheManager.shared.loadCoinImage(from: bestURL, symbol: coin.symbol) { [weak self] image in
            guard let self = self, self.currentCoin?.id == coin.id else { return }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                
                if let image = image {
                    UIView.transition(with: self.coinImageView,
                                     duration: 0.2,
                                     options: .transitionCrossDissolve,
                                     animations: {
                        self.coinImageView.image = image
                    })
                } else {
                    // En iyi URL bile başarısız olduysa, normal yükleme sistemine dön
                    self.loadCoinImage(coin)
                }
            }
        }
    }
    
    // Kripto logosunu yükle - gelişmiş yükleme sistemiyle
    private func loadCoinImage(_ coin: Coin) {
        // İlk olarak yeni gelişmiş görsel önbellek yöneticisini kullan
        ImageCacheManager.shared.loadCoinImage(from: coin.image, symbol: coin.symbol) { [weak self] image in
            guard let self = self, self.currentCoin?.id == coin.id else { return }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                
                if let image = image {
                    UIView.transition(with: self.coinImageView,
                                     duration: 0.3,
                                     options: .transitionCrossDissolve,
                                     animations: {
                        self.coinImageView.image = image
                    })
                } else {
                    // Yedek kaynaklardan hiçbiri çalışmadıysa, CoinNetworkManager'ı son bir çare olarak dene
                    self.loadFallbackImage(coin)
                }
            }
        }
    }
    
    // Yedek logo yükleme sistemi - tüm gelişmiş kaynaklar başarısız olduğunda
    private func loadFallbackImage(_ coin: Coin) {
        CoinNetworkManager.shared.downloadImage(from: coin.image) { [weak self] image in
            guard let self = self, self.currentCoin?.id == coin.id else { return }
            
            DispatchQueue.main.async {
                if let image = image {
                    UIView.transition(with: self.coinImageView,
                                     duration: 0.3,
                                     options: .transitionCrossDissolve,
                                     animations: {
                        self.coinImageView.image = image
                    })
                } else {
                    // Dinamik bir sembol logo oluştur
                    let symbol = coin.symbol.uppercased()
                    self.createSymbolLogo(for: symbol)
                }
            }
        }
    }
    
    // Sembol temelli varsayılan logo oluştur
    private func createSymbolLogo(for symbol: String) {
        let frame = coinImageView.bounds
        let symbolLabel = UILabel(frame: frame)
        symbolLabel.text = String(symbol.prefix(1))
        symbolLabel.font = UIFont.boldSystemFont(ofSize: 16)
        symbolLabel.textColor = .white
        symbolLabel.textAlignment = .center
        
        // Sembol adına göre tutarlı bir arka plan rengi oluştur
        let backgroundColor = generateColorForSymbol(symbol)
        symbolLabel.backgroundColor = backgroundColor
        
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            symbolLabel.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let symbolImage = image {
                UIView.transition(with: self.coinImageView,
                                 duration: 0.3,
                                 options: .transitionCrossDissolve,
                                 animations: {
                    self.coinImageView.image = symbolImage
                })
            } else {
                self.coinImageView.image = UIImage(systemName: "bitcoinsign.circle.fill")
                self.coinImageView.tintColor = .lightGray
            }
        }
    }
    
    // Sembol adından tutarlı bir renk üret
    private func generateColorForSymbol(_ symbol: String) -> UIColor {
        var hash = 0
        
        for char in symbol {
            let unicodeValue = Int(char.unicodeScalars.first?.value ?? 0)
            hash = ((hash << 5) &- hash) &+ unicodeValue
        }
        
        let red = CGFloat(abs(hash) % 255) / 255.0
        let green = CGFloat(abs(hash * 33) % 255) / 255.0
        let blue = CGFloat(abs(hash * 77) % 255) / 255.0
        
        return UIColor(red: max(0.4, red),
                      green: max(0.4, green),
                      blue: max(0.4, blue),
                      alpha: 1.0)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        coinImageView.image = nil
        activityIndicator.stopAnimating()
        rankLabel.text = nil
        nameLabel.text = nil
        symbolLabel.text = nil
        priceLabel.text = nil
        changeLabel.text = nil
        currentCoin = nil
        logoErrorCount = 0
    }
} 