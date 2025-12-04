import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

final class SettingsManager: ObservableObject {
    @Published var commonMaterials: [SavedMaterial] = []

    private let db: Firestore
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserID: String?

    init(database: Firestore = Firestore.firestore()) {
        self.db = database
        configureAuthListener()
    }

    deinit {
        listener?.remove()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
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
            db.collection("materialPrices")
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

    private func configureAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.attachListener(for: user)
        }

        attachListener(for: Auth.auth().currentUser)
    }

    private func attachListener(for user: User?) {
        listener?.remove()
        currentUserID = user?.uid
        commonMaterials = []

        guard let uid = user?.uid else { return }

        listener = db.collection("materialPrices")
            .whereField("ownerID", in: [uid, "global"])
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

                DispatchQueue.main.async {
                    self.commonMaterials = decoded.filter { $0.ownerID != "global" }
                }
            }
    }

    private func persist(_ material: SavedMaterial) {
        guard let uid = currentUserID else { return }

        var materialToSave = material
        materialToSave.ownerID = uid
        materialToSave.isDefault = false

        do {
            try db.collection("materialPrices")
                .document(materialToSave.id.uuidString)
                .setData(from: materialToSave)
        } catch {
            print("Failed to save material price: \(error.localizedDescription)")
        }
    }
}
