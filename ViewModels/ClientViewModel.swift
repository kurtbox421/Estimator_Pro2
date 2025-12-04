import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

final class ClientViewModel: ObservableObject {
    @Published var clients: [Client] = []

    private let db: Firestore
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    init(database: Firestore = Firestore.firestore()) {
        self.db = database
        configureAuthListener()
    }

    deinit {
        listener?.remove()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    func addClient(
        name: String,
        company: String = "",
        address: String = "",
        phone: String = "",
        email: String = "",
        notes: String = ""
    ) -> Client {
        guard let uid = Auth.auth().currentUser?.uid else { return Client() }

        let newClient = Client(
            ownerID: uid,
            name: name,
            company: company,
            address: address,
            phone: phone,
            email: email,
            notes: notes
        )
        persist(newClient)
        return newClient
    }

    func add(_ client: Client = Client()) {
        persist(client)
    }

    func delete(_ client: Client) {
        guard Auth.auth().currentUser != nil else { return }

        db.collection("clients")
            .document(client.id.uuidString)
            .delete()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        clients.move(fromOffsets: offsets, toOffset: destination)
    }

    func update(_ client: Client) {
        persist(client)
    }

    // MARK: - Firestore

    private func configureAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.attachListener(for: user)
        }

        attachListener(for: Auth.auth().currentUser)
    }

    private func attachListener(for user: User?) {
        listener?.remove()
        clients = []

        guard let uid = user?.uid else { return }

        listener = db.collection("clients")
            .whereField("ownerID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("Failed to fetch clients: \(error.localizedDescription)")
                    return
                }

                let decoded: [Client] = snapshot?.documents.compactMap { document in
                    do {
                        return try document.data(as: Client.self)
                    } catch {
                        print("Failed to decode client \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                } ?? []

                DispatchQueue.main.async {
                    self.clients = decoded
                }
            }
    }

    private func persist(_ client: Client) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        var clientToSave = client
        clientToSave.ownerID = uid

        if let existingIndex = clients.firstIndex(where: { $0.id == clientToSave.id }) {
            clients[existingIndex] = clientToSave
        } else {
            clients.append(clientToSave)
        }

        do {
            try db.collection("clients")
                .document(clientToSave.id.uuidString)
                .setData(from: clientToSave)
        } catch {
            print("Failed to save client: \(error.localizedDescription)")
        }
    }
}
