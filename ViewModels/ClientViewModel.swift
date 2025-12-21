import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class ClientViewModel: ObservableObject {
    @Published var clients: [Client] = []

    private let db: Firestore
    private var listener: ListenerRegistration?
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var currentUserID: String?
    private var resetToken: UUID?

    init(database: Firestore = Firestore.firestore(), session: SessionManager) {
        self.db = database
        self.session = session
        resetToken = session.registerResetHandler { [weak self] in
            self?.clear()
        }
        session.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                self?.setUser(uid)
            }
            .store(in: &cancellables)
        setUser(session.uid)
    }

    deinit {
        Task { @MainActor in
            listener?.remove()
            cancellables.removeAll()
            if let resetToken {
                session.unregisterResetHandler(resetToken)
            }
        }
    }

    func addClient(
        name: String,
        company: String = "",
        address: String = "",
        phone: String = "",
        email: String = "",
        notes: String = ""
    ) -> Client {
        guard let uid = currentUserID else { return Client() }

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
        guard let uid = currentUserID else { return }

        let path = "users/\(uid)/clients/\(client.id.uuidString)"
        print("[Data] ClientViewModel uid=\(uid) path=\(path) action=delete")

        db.collection("users")
            .document(uid)
            .collection("clients")
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

    private func setUser(_ uid: String?) {
        listener?.remove()
        currentUserID = uid
        clients = []

        guard let uid else { return }

        let path = "users/\(uid)/clients"
        print("[Data] ClientViewModel uid=\(uid) path=\(path) action=listen")

        listener = db.collection("users")
            .document(uid)
            .collection("clients")
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

                Task { @MainActor in
                    self.clients = decoded
                }
            }

        session.track(listener)
    }

    private func persist(_ client: Client) {
        guard let uid = currentUserID else { return }

        var clientToSave = client
        clientToSave.ownerID = uid

        if let existingIndex = clients.firstIndex(where: { $0.id == clientToSave.id }) {
            clients[existingIndex] = clientToSave
        } else {
            clients.append(clientToSave)
        }

        do {
            let path = "users/\(uid)/clients/\(clientToSave.id.uuidString)"
            print("[Data] ClientViewModel uid=\(uid) path=\(path) action=write")
            try db.collection("users")
                .document(uid)
                .collection("clients")
                .document(clientToSave.id.uuidString)
                .setData(from: clientToSave)
        } catch {
            print("Failed to save client: \(error.localizedDescription)")
        }
    }

    func clear() {
        listener?.remove()
        listener = nil
        currentUserID = nil
        clients = []
    }
}
