import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

final class SettingsManager: ObservableObject {
    @Published var commonMaterials: [SavedMaterial] = []

    private let db: Firestore
    private var listener: ListenerRegistration?
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var resetToken: UUID?
    private var currentUserID: String?

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
        listener?.remove()
        if let resetToken {
            session.unregisterResetHandler(resetToken)
        }
    }

    func addMaterial(name: String, price: Double) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let uid = currentUserID else { return }

        let material = SavedMaterial(ownerID: uid, isDefault: false, name: trimmedName, price: price)
        commonMaterials.append(material)
        persist(material)
    }

    func deleteMaterials(at offsets: IndexSet) {
        let materialsToDelete = offsets.compactMap { commonMaterials.indices.contains($0) ? commonMaterials[$0] : nil }
        commonMaterials.remove(atOffsets: offsets)

        materialsToDelete.forEach { material in
            guard let uid = currentUserID else { return }

            let path = "users/\(uid)/materialPrices/\(material.id.uuidString)"
            print("[Data] SettingsManager uid=\(uid) path=\(path) action=delete")

            db.collection("users")
                .document(uid)
                .collection("materialPrices")
                .document(material.id.uuidString)
                .delete()
        }
    }

    func updateMaterialName(at index: Int, name: String) {
        guard commonMaterials.indices.contains(index) else { return }

        var updatedMaterials = commonMaterials
        updatedMaterials[index].name = name
        commonMaterials = updatedMaterials
        persist(updatedMaterials[index])
    }

    func updateMaterialPrice(at index: Int, price: Double) {
        guard commonMaterials.indices.contains(index) else { return }

        var updatedMaterials = commonMaterials
        updatedMaterials[index].price = price
        commonMaterials = updatedMaterials
        persist(updatedMaterials[index])
    }

    func commonMaterialPrice(for name: String) -> Double? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return commonMaterials.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }?.price
    }

    private func setUser(_ uid: String?) {
        listener?.remove()
        currentUserID = uid
        commonMaterials = []

        guard let uid else { return }

        let path = "users/\(uid)/materialPrices"
        print("[Data] SettingsManager uid=\(uid) path=\(path) action=listen")

        listener = db.collection("users")
            .document(uid)
            .collection("materialPrices")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error { print("Failed to fetch material prices: \(error.localizedDescription)"); return }

                let decoded: [SavedMaterial] = snapshot?.documents.compactMap { document in
                    do {
                        return try document.data(as: SavedMaterial.self)
                    } catch {
                        print("Failed to decode material price \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                } ?? []

                DispatchQueue.main.async { self.commonMaterials = decoded }
            }

        session.track(listener)
    }

    private func persist(_ material: SavedMaterial) {
        guard let uid = currentUserID else { return }

        var materialToSave = material
        materialToSave.ownerID = uid
        materialToSave.isDefault = false

        do {
            let path = "users/\(uid)/materialPrices/\(materialToSave.id.uuidString)"
            print("[Data] SettingsManager uid=\(uid) path=\(path) action=write")
            try db.collection("users")
                .document(uid)
                .collection("materialPrices")
                .document(materialToSave.id.uuidString)
                .setData(from: materialToSave)
        } catch {
            print("Failed to save material price: \(error.localizedDescription)")
        }
    }

    func clear() {
        listener?.remove()
        listener = nil
        currentUserID = nil
        commonMaterials = []
    }
}
