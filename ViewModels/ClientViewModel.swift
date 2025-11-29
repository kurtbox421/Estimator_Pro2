import Foundation

private enum ClientStorage {
    static let userDefaultsKey = "EstimatorPro_Clients"
    static let fileName = "clients.json"
}

final class ClientViewModel: ObservableObject {
    @Published var clients: [Client] = [] {
        didSet {
            saveClients()
        }
    }

    private let persistence: PersistenceService

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        loadClients()
    }

    func addClient(
        name: String,
        company: String = "",
        address: String = "",
        phone: String = "",
        email: String = "",
        notes: String = ""
    ) -> Client {
        let newClient = Client(
            name: name,
            company: company,
            address: address,
            phone: phone,
            email: email,
            notes: notes
        )
        clients.append(newClient)
        return newClient
    }

    func add(_ client: Client = Client()) {
        clients.append(client)
    }

    func delete(_ client: Client) {
        clients.removeAll { $0.id == client.id }
    }

    func move(from offsets: IndexSet, to destination: Int) {
        clients.move(fromOffsets: offsets, toOffset: destination)
    }

    func update(_ client: Client) {
        guard let index = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[index] = client
    }

    private func saveClients() {
        persistence.save(clients, to: ClientStorage.fileName)
    }

    private func loadClients() {
        if let stored: [Client] = persistence.load([Client].self, from: ClientStorage.fileName) {
            clients = stored
            return
        }

        if let migrated: [Client] = persistence.migrateFromUserDefaults(key: ClientStorage.userDefaultsKey, fileName: ClientStorage.fileName, as: [Client].self) {
            clients = migrated
            return
        }

        clients = Client.sampleData
    }
}
