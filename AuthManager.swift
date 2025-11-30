import Foundation
import FirebaseAuth

final class AuthManager {
    static let shared = AuthManager()
    private init() {}

    enum AuthError: LocalizedError {
        case noUser
        var errorDescription: String? { "No user found." }
    }

    func signUp(email: String,
                password: String,
                displayName: String,
                completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(AuthError.noUser))
                return
            }

            let change = user.createProfileChangeRequest()
            change.displayName = displayName
            change.commitChanges { _ in
                completion(.success(user))
            }
        }
    }

    func signIn(email: String,
                password: String,
                completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(AuthError.noUser))
                return
            }
            completion(.success(user))
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
