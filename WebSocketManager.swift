import Foundation

enum WebSocketProvider {
    case cryptoCompare
    case binance
}

protocol WebSocketManagerDelegate: AnyObject {
    func didReceiveCoinUpdate(coin: Coin)
    func didReceivePriceUpdate(symbol: String, price: Double, changePercent: Double)
    func didDisconnect(error: Error?)
    func didConnect()
}

class WebSocketManager: NSObject {
    static let shared = WebSocketManager()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var binanceWebSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var isConnected = false
    private var isBinanceConnected = false
    private var reconnectTimer: Timer?
    private var subscriptions = Set<String>()
    private var currentProvider: WebSocketProvider = .binance // Default to Binance for speed
    
    weak var delegate: WebSocketManagerDelegate?
    
    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    // Connect to preferred WebSocket provider
    func connect(provider: WebSocketProvider = .binance) {
        currentProvider = provider
        
        switch provider {
        case .cryptoCompare:
            connectToCryptoCompare()
        case .binance:
            connectToBinance()
        }
    }
    
    // Connect to CryptoCompare websocket
    private func connectToCryptoCompare() {
        guard !isConnected else { return }
        
        let url = URL(string: Constants.API.cryptoCompareWSURL)!
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        receiveCryptoCompareMessage()
    }
    
    // Connect to Binance websocket (faster)
    private func connectToBinance() {
        guard !isBinanceConnected else { return }
        
        let url = URL(string: Constants.API.binanceWebSocketURL)!
        binanceWebSocketTask = session.webSocketTask(with: url)
        binanceWebSocketTask?.resume()
        
        isBinanceConnected = true
        receiveBinanceMessage()
    }
    
    // Subscribe to specific coins
    func subscribeToCoins(symbols: [String]) {
        subscriptions = Set(symbols.map { $0.uppercased() })
        
        switch currentProvider {
        case .cryptoCompare:
            subscribeToCryptoCompare(symbols: symbols)
        case .binance:
            subscribeToBinance(symbols: symbols)
        }
    }
    
    // Subscribe to CryptoCompare
    private func subscribeToCryptoCompare(symbols: [String]) {
        guard isConnected, let webSocketTask = webSocketTask else {
            // If not connected, connect first then try again
            connectToCryptoCompare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.subscribeToCryptoCompare(symbols: symbols)
            }
            return
        }
        
        // Format symbols to uppercase for the API
        let formattedSymbols = symbols.map { $0.uppercased() }
        
        // Create subscription message
        let subRequest: [String: Any] = [
            "action": "SubAdd",
            "subs": formattedSymbols.map { "5~CCCAGG~\($0)~USD" }
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: subRequest),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to create subscription message")
            return
        }
        
        // Send subscription request
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask.send(message) { error in
            if let error = error {
                print("Error sending CryptoCompare subscription: \(error)")
            } else {
                print("Successfully subscribed to CryptoCompare: \(formattedSymbols.joined(separator: ", "))")
            }
        }
    }
    
    // Subscribe to Binance (faster updates)
    private func subscribeToBinance(symbols: [String]) {
        guard isBinanceConnected, let binanceWebSocketTask = binanceWebSocketTask else {
            // If not connected, connect first then try again
            connectToBinance()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.subscribeToBinance(symbols: symbols)
            }
            return
        }
        
        // Close existing connection to create a new one with all subscriptions
        binanceWebSocketTask.cancel(with: .normalClosure, reason: nil)
        
        // Format streams for Binance
        let streams = symbols.map { "\(String($0).lowercased())usdt@ticker" }
        let streamURL = URL(string: "\(Constants.API.binanceWebSocketURL)/stream?streams=\(streams.joined(separator: "/"))")!
        
        // Create new connection with all streams
        binanceWebSocketTask = session.webSocketTask(with: streamURL)
        binanceWebSocketTask?.resume()
        
        isBinanceConnected = true
        receiveBinanceMessage()
        
        print("Successfully subscribed to Binance: \(streams.joined(separator: ", "))")
    }
    
    // Handle incoming messages from CryptoCompare
    private func receiveCryptoCompareMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleCryptoCompareMessage(text)
                case .data(let data):
                    if let string = String(data: data, encoding: .utf8) {
                        self.handleCryptoCompareMessage(string)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveCryptoCompareMessage()
                
            case .failure(let error):
                print("Error receiving CryptoCompare message: \(error)")
                self.isConnected = false
                self.delegate?.didDisconnect(error: error)
                self.scheduleReconnect(provider: .cryptoCompare)
            }
        }
    }
    
    // Handle incoming messages from Binance
    private func receiveBinanceMessage() {
        binanceWebSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleBinanceMessage(text)
                case .data(let data):
                    if let string = String(data: data, encoding: .utf8) {
                        self.handleBinanceMessage(string)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveBinanceMessage()
                
            case .failure(let error):
                print("Error receiving Binance message: \(error)")
                self.isBinanceConnected = false
                self.delegate?.didDisconnect(error: error)
                self.scheduleReconnect(provider: .binance)
            }
        }
    }
    
    // Process CryptoCompare WebSocket messages
    private func handleCryptoCompareMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Handle different message types
                if let type = json["TYPE"] as? Int {
                    switch type {
                    case 5: // Price update
                        handleCryptoComparePriceUpdate(json)
                    case 3: // Subscription success
                        print("CryptoCompare subscription successful")
                    case 999: // Welcome message
                        delegate?.didConnect()
                    default:
                        break
                    }
                }
            }
        } catch {
            print("Error parsing CryptoCompare message: \(error)")
        }
    }
    
    // Process Binance WebSocket messages
    private func handleBinanceMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for Binance stream data
                if let streamData = json["data"] as? [String: Any] {
                    handleBinancePriceUpdate(streamData)
                }
            }
        } catch {
            print("Error parsing Binance message: \(error)")
        }
    }
    
    // Process CryptoCompare price updates
    private func handleCryptoComparePriceUpdate(_ json: [String: Any]) {
        guard let fromSymbol = json["FROMSYMBOL"] as? String,
              let price = json["PRICE"] as? Double else {
            return
        }
        
        // Extract change percentage if available
        let changePercent = json["CHANGEPCT24HOUR"] as? Double ?? 0.0
        
        // Notify delegate of the price update
        DispatchQueue.main.async {
            self.delegate?.didReceivePriceUpdate(symbol: fromSymbol, price: price, changePercent: changePercent)
        }
    }
    
    // Process Binance price updates
    private func handleBinancePriceUpdate(_ json: [String: Any]) {
        guard let symbol = json["s"] as? String,
              let lastPriceString = json["c"] as? String,
              let priceChangePercentString = json["P"] as? String,
              let lastPrice = Double(lastPriceString),
              let priceChangePercent = Double(priceChangePercentString) else {
            return
        }
        
        // Extract base symbol (remove USDT)
        let baseSymbol: String
        if symbol.hasSuffix("USDT") {
            baseSymbol = String(symbol.dropLast(4))
        } else {
            baseSymbol = symbol
        }
        
        // Notify delegate of the price update
        DispatchQueue.main.async {
            self.delegate?.didReceivePriceUpdate(symbol: baseSymbol, price: lastPrice, changePercent: priceChangePercent)
        }
    }
    
    // Disconnect from WebSocket
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        binanceWebSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
        isBinanceConnected = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // Schedule reconnection after disconnect
    private func scheduleReconnect(provider: WebSocketProvider) {
        guard reconnectTimer == nil else { return }
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: Constants.Time.webSocketReconnectDelay, repeats: false) { [weak self] _ in
            self?.reconnectTimer = nil
            self?.connect(provider: provider)
            
            // Re-subscribe to previous subscriptions if any
            if !(self?.subscriptions.isEmpty ?? true) {
                self?.subscribeToCoins(symbols: Array(self?.subscriptions ?? []))
            }
        }
    }
    
    // Check if the WebSocket is connected
    var isConnected: Bool {
        switch currentProvider {
        case .cryptoCompare:
            return isConnected
        case .binance:
            return isBinanceConnected
        }
    }
}

// URLSession delegate for WebSocket
extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        if webSocketTask == self.webSocketTask {
            isConnected = true
        } else if webSocketTask == self.binanceWebSocketTask {
            isBinanceConnected = true
        }
        
        delegate?.didConnect()
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "No reason"
        
        if webSocketTask == self.webSocketTask {
            isConnected = false
            print("CryptoCompare WebSocket closed with code: \(closeCode), reason: \(reasonString)")
            scheduleReconnect(provider: .cryptoCompare)
        } else if webSocketTask == self.binanceWebSocketTask {
            isBinanceConnected = false
            print("Binance WebSocket closed with code: \(closeCode), reason: \(reasonString)")
            scheduleReconnect(provider: .binance)
        }
        
        delegate?.didDisconnect(error: nil)
    }
} 