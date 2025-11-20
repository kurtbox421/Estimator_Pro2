import Foundation

private let clientsStorageKey = "EstimatorPro_Clients"

final class ClientViewModel: ObservableObject {
    @Published var clients: [Client] = [] {
        didSet {
            saveClients()
        }
    }

    init() {
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
        do {
            let data = try JSONEncoder().encode(clients)
            UserDefaults.standard.set(data, forKey: clientsStorageKey)
        } catch {
            print("Failed to save clients: \(error)")
        }
    }

    private func loadClients() {
        guard let data = UserDefaults.standard.data(forKey: clientsStorageKey) else {
            clients = Client.sampleData
            return
        }

        do {
            clients = try JSONDecoder().decode([Client].self, from: data)
        } catch {
            print("Failed to load clients: \(error)")
            clients = Client.sampleData
        }
    }
}
