import Foundation
import SwiftUI

// MARK: - MockFirebaseError
enum MockFirebaseError: Error {
    case authError
    case networkError
    case serverError
    case unknownError
}

// MARK: - FirebaseManager Mock
public class FirebaseManager {
    public static let shared = FirebaseManager()
    
    private init() {}
    
    enum FirebaseError: Error, LocalizedError {
        case invalidCredentials
        case userAlreadyExists
        case userNotFound
        case serverError
        case networkError
        case commentNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "Invalid email or password"
            case .userAlreadyExists:
                return "User already exists"
            case .userNotFound:
                return "User not found"
            case .serverError:
                return "Server error occurred"
            case .networkError:
                return "Network error. Please check your connection"
            case .commentNotFound:
                return "Comment not found"
            }
        }
    }
    
    func configure() {
        // This would normally initialize Firebase
        print("Firebase configured (mock implementation)")
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if email.lowercased() == "demo@example.com" && password == "123456" {
                // Mock successful sign in
                let user = User(
                    id: "user123",
                    username: "DemoUser",
                    email: email,
                    gender: "Other",
                    country: "Global",
                    phoneNumber: "+1234567890",
                    favoriteCoins: ["bitcoin", "ethereum", "solana"]
                )
                
                completion(.success(user))
            } else {
                // Mock authentication failure
                completion(.failure(FirebaseError.invalidCredentials))
            }
        }
    }
    
    func signOut(completion: @escaping (Bool) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Always successful in mock
            completion(true)
        }
    }
    
    func createUser(email: String, password: String, userData: [String: Any], completion: @escaping (Result<User, Error>) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Mock successful user creation
            let user = User(
                id: UUID().uuidString,
                username: userData["username"] as? String ?? "User",
                email: email,
                gender: userData["gender"] as? String ?? "Other",
                country: userData["country"] as? String ?? "Global",
                phoneNumber: userData["phoneNumber"] as? String ?? "",
                favoriteCoins: []
            )
            
            completion(.success(user))
        }
    }
    
    func updateUserFavorites(userId: String, favorites: [String], completion: @escaping (Bool) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Always successful in mock
            completion(true)
        }
    }
    
    func fetchComments(for coinId: String, completion: @escaping (Result<[Comment], Error>) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Mock comments for the given coin
            let mockComments = [
                Comment(
                    id: "comment1",
                    userId: "user123",
                    coinId: coinId,
                    text: "Bu coin gelecekte çok değerlenecek!",
                    username: "DemoUser",
                    createdAt: Date().addingTimeInterval(-3600)
                ),
                Comment(
                    id: "comment2",
                    userId: "user456",
                    coinId: coinId,
                    text: "Yatırım yapılabilitesi yüksek",
                    username: "CryptoTrader",
                    createdAt: Date().addingTimeInterval(-7200)
                ),
                Comment(
                    id: "comment3",
                    userId: "user789",
                    coinId: coinId,
                    text: "Bu projenin teknolojisi çok sağlam",
                    username: "CryptoEnthusiast",
                    createdAt: Date().addingTimeInterval(-10800)
                )
            ]
            
            completion(.success(mockComments))
        }
    }
    
    func addComment(userId: String, username: String, coinId: String, text: String, completion: @escaping (Result<Comment, Error>) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Create a new comment
            let newComment = Comment(
                id: UUID().uuidString,
                userId: userId,
                coinId: coinId,
                text: text,
                username: username,
                createdAt: Date()
            )
            
            completion(.success(newComment))
        }
    }
    
    func deleteComment(commentId: String, coinId: String, completion: @escaping (Bool) -> Void) {
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Always successful in mock
            completion(true)
        }
    }
    
    // MARK: - Firestore Methods
    
    func getDocument(collection: String, document: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        // Simulate success with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let data: [String: Any] = [
                "id": document,
                "createdAt": Date()
            ]
            completion(data, nil)
        }
    }
    
    func addDocument(collection: String, data: [String: Any], completion: @escaping (String?, Error?) -> Void) {
        // Simulate success
        let docId = UUID().uuidString
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(docId, nil)
        }
    }
    
    func updateDocument(collection: String, document: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        // Simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(nil)
        }
    }
    
    func deleteDocument(collection: String, document: String, completion: @escaping (Error?) -> Void) {
        // Simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(nil)
        }
    }
    
    func getDocuments(collection: String, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        // Simulate success with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let documents: [[String: Any]] = [
                ["id": UUID().uuidString, "createdAt": Date()],
                ["id": UUID().uuidString, "createdAt": Date()]
            ]
            completion(documents, nil)
        }
    }
} 