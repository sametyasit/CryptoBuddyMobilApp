import Foundation
import SwiftUI

// Define the service classes directly in the module namespace
// instead of in a nested namespace

// MARK: - User Model
public struct User: Identifiable, Codable {
    public let id: String
    public let username: String
    public let email: String
    public let gender: String
    public let country: String
    public let phoneNumber: String
    public var favoriteCoins: [String]
    
    public init(id: String, username: String, email: String, gender: String, country: String, phoneNumber: String, favoriteCoins: [String] = []) {
        self.id = id
        self.username = username
        self.email = email
        self.gender = gender
        self.country = country
        self.phoneNumber = phoneNumber
        self.favoriteCoins = favoriteCoins
    }
}

// MARK: - Comment Model
public struct Comment: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let coinId: String
    public let text: String
    public let username: String
    public let createdAt: Date
    
    public init(id: String, userId: String, coinId: String, text: String, username: String, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.coinId = coinId
        self.text = text
        self.username = username
        self.createdAt = createdAt
    }
}

// MARK: - Auth Service

/// Authentication service for the application
public class AuthService: ObservableObject {
    @Published public var currentUser: User?
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let firebaseManager = FirebaseManager.shared
    
    public init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        // Check if user is already logged in from UserDefaults
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            // Create a demo user
            let user = User(
                id: "user123",
                username: "DemoUser",
                email: "demo@example.com",
                gender: "Other",
                country: "Global",
                phoneNumber: "+1234567890",
                favoriteCoins: ["bitcoin", "ethereum", "solana"]
            )
            
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signUp(username: String, email: String, password: String, gender: String, country: String, phoneNumber: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        let userData: [String: Any] = [
            "username": username,
            "gender": gender,
            "country": country,
            "phoneNumber": phoneNumber
        ]
        
        firebaseManager.createUser(email: email, password: password, userData: userData) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let user):
                    self.currentUser = user
                    self.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    completion(true)
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        firebaseManager.signIn(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let user):
                    self.currentUser = user
                    self.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    UserDefaults.standard.set(user.username, forKey: "username")
                    completion(true)
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    func signOut(completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        firebaseManager.signOut { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                }
                self.isLoading = false
                completion(success)
            }
        }
    }
    
    func isCoinFavorite(coinId: String) -> Bool {
        guard let user = currentUser else {
            return false
        }
        return user.favoriteCoins.contains(coinId)
    }
    
    func toggleFavoriteCoin(coinId: String, completion: @escaping (Bool) -> Void) {
        guard isAuthenticated, var user = currentUser else {
            completion(false)
            return
        }
        
        // Check if coin is already in favorites
        if let index = user.favoriteCoins.firstIndex(of: coinId) {
            // Remove from favorites
            user.favoriteCoins.remove(at: index)
        } else {
            // Add to favorites
            user.favoriteCoins.append(coinId)
        }
        
        // Update user data
        self.currentUser = user
        
        // Update in backend (Firebase)
        firebaseManager.updateUserFavorites(userId: user.id, favorites: user.favoriteCoins) { success in
            completion(success)
        }
    }
}

// MARK: - Comment Service

/// Comment service for the application
public class CommentService: ObservableObject {
    @Published public var comments: [Comment] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let firebaseManager = FirebaseManager.shared
    
    public init() {}
    
    func fetchComments(for coinId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        firebaseManager.fetchComments(for: coinId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let fetchedComments):
                    self.comments = fetchedComments
                    completion(true)
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load comments: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    func addComment(userId: String, username: String, coinId: String, text: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        firebaseManager.addComment(userId: userId, username: username, coinId: coinId, text: text) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let newComment):
                    self.comments.insert(newComment, at: 0)
                    completion(true)
                    
                case .failure(let error):
                    self.errorMessage = "Failed to add comment: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    func deleteComment(commentId: String, coinId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        firebaseManager.deleteComment(commentId: commentId, coinId: coinId) { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.comments.removeAll { $0.id == commentId }
                    completion(true)
                } else {
                    self.errorMessage = "Failed to delete comment"
                    completion(false)
                }
            }
        }
    }
}
