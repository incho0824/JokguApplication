import Foundation
import FirebaseFirestore
import CryptoKit
import Combine

struct KeyCode: Identifiable {
    let id: Int
    var code: String
    var address: String
    var welcome: String
    var youtube: URL?
    var kakao: URL?
    var notification: String
    var playwhen: [String]
    var fee: Int
    var venmo: String
}

struct Member: Identifiable {
    let id: Int
    var username: String
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var dob: String
    var picture: Data?
    var attendance: Int
    var permit: Int
    var guest: Int
    var today: Int
    var syncd: Int
    var orderIndex: Int
    var recovery: Int
}

struct UserFields {
    let username: String
    var values: [Int]
}

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    private let db: Firestore
    @Published private(set) var management: KeyCode?
    private var managementListener: ListenerRegistration?

    private init() {
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.cacheSettings = PersistentCacheSettings()
        firestore.settings = settings
        self.db = firestore
        listenToManagement()
    }

    private func listenToManagement() {
        managementListener?.remove()
        managementListener = db.collection("management").addSnapshotListener { snapshot, _ in
            guard let snapshot = snapshot else { return }

            if snapshot.documents.isEmpty {
                self.db.collection("management").document("default").setData([
                    "id": 1,
                    "keycode": "1234"
                ])
                return
            }

            guard let doc = snapshot.documents.first,
                  let item = self.keyCodeFromDoc(doc) else { return }
            DispatchQueue.main.async {
                self.management = item
            }
        }
    }

    // MARK: - Helpers
    private func hashPassword(_ password: String) -> String {
        let hash = SHA256.hash(data: password.data(using: .utf8) ?? Data())
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func pictureString(_ data: Data?) -> String? {
        guard let data = data else { return nil }
        return data.base64EncodedString()
    }

    private func pictureData(_ string: String?) -> Data? {
        guard let string = string else { return nil }
        return Data(base64Encoded: string)
    }

    private func memberFromDoc(_ doc: DocumentSnapshot) -> Member? {
        guard let data = doc.data() else { return nil }
        let id = data["id"] as? Int ?? 0
        let username = data["username"] as? String ?? ""
        let firstName = data["firstname"] as? String ?? ""
        let lastName = data["lastname"] as? String ?? ""
        let phoneNumber = data["phonenumber"] as? String ?? ""
        let dob = data["dob"] as? String ?? ""
        let picture = pictureData(data["picture"] as? String)
        let attendance = data["attendance"] as? Int ?? 0
        let permit = data["permit"] as? Int ?? 0
        let guest = data["guest"] as? Int ?? 0
        let today = data["today"] as? Int ?? 0
        let syncd = data["syncd"] as? Int ?? 0
        let orderIndex = data["orderIndex"] as? Int ?? 0
        let recovery = data["recovery"] as? Int ?? 0
        return Member(id: id, username: username, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dob, picture: picture, attendance: attendance, permit: permit, guest: guest, today: today, syncd: syncd, orderIndex: orderIndex, recovery: recovery)
    }

    private func keyCodeFromDoc(_ doc: DocumentSnapshot) -> KeyCode? {
        guard let data = doc.data() else { return nil }
        let id = data["id"] as? Int ?? 0
        let code = data["keycode"] as? String ?? ""
        let address = data["address"] as? String ?? ""
        let welcome = data["welcome"] as? String ?? ""
        let youtubeString = data["youtube"] as? String
        let kakaoString = data["kakao"] as? String
        let notification = data["notification"] as? String ?? ""
        let playwhen = data["playwhen"] as? [String] ?? []
        let fee = data["fee"] as? Int ?? 0
        let venmo = data["venmo"] as? String ?? ""
        return KeyCode(id: id, code: code, address: address, welcome: welcome, youtube: youtubeString != nil ? URL(string: youtubeString!) : nil, kakao: kakaoString != nil ? URL(string: kakaoString!) : nil, notification: notification, playwhen: playwhen, fee: fee, venmo: venmo)
    }

    private func memberDocument(id: Int) async throws -> DocumentReference? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentReference?, Error>) in
            db.collection("member").whereField("id", isEqualTo: id).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot?.documents.first?.reference)
                }
            }
        }
    }

    // MARK: - Authentication & Users
    func userExists(_ username: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            db.collection("member").whereField("username", isEqualTo: username.uppercased()).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot?.documents.isEmpty == false)
                }
            }
        }
    }

    func insertUser(username: String, password: String, firstName: String, lastName: String, phoneNumber: String, dob: String, picture: Data?) async throws {
        let upperUsername = username.uppercased()
        guard try await !userExists(upperUsername) else { throw NSError(domain: "UserExists", code: 1) }

        // Obtain a new sequential ID using a transaction on a counter document
        let newId: Int = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            let counterRef = db.collection("counters").document("member")
            db.runTransaction({ transaction, errorPointer -> Any? in
                let counterDoc: DocumentSnapshot
                do {
                    counterDoc = try transaction.getDocument(counterRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                let nextId = (counterDoc.data()?["nextId"] as? Int) ?? 1
                transaction.setData(["nextId": nextId + 1], forDocument: counterRef)
                return nextId
            }) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let id = result as? Int {
                    continuation.resume(returning: id)
                } else {
                    continuation.resume(throwing: NSError(domain: "TransactionError", code: 0))
                }
            }
        }

        var data: [String: Any] = [
            "id": newId,
            "username": upperUsername,
            "password": hashPassword(password),
            "firstname": firstName,
            "lastname": lastName,
            "phonenumber": phoneNumber,
            "dob": dob,
            "attendance": 0,
            "permit": 0,
            "guest": 0,
            "today": 0,
            "syncd": 1,
            "orderIndex": newId,
            "recovery": Int.random(in: 100000...999999)
        ]
        if let picture = picture { data["picture"] = pictureString(picture) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("member").addDocument(data: data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func validateUser(username: String, password: String) async throws -> Int? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int?, Error>) in
            db.collection("member")
                .whereField("username", isEqualTo: username.uppercased())
                .whereField("password", isEqualTo: hashPassword(password))
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let doc = snapshot?.documents.first {
                        continuation.resume(returning: doc.data()["permit"] as? Int)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
        }
    }

    func fetchMembers() async throws -> [Member] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Member], Error>) in
            db.collection("member").order(by: "orderIndex").getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let items = snapshot?.documents.compactMap { self.memberFromDoc($0) } ?? []
                    continuation.resume(returning: items)
                }
            }
        }
    }

    func listenMembers(completion: @escaping ([Member]) -> Void) -> ListenerRegistration {
        return db.collection("member").order(by: "orderIndex").addSnapshotListener { snapshot, _ in
            let members = snapshot?.documents.compactMap { self.memberFromDoc($0) } ?? []
            completion(members)
        }
    }

    func fetchTodayMembers() async throws -> [Member] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Member], Error>) in
            db.collection("member").whereField("today", isEqualTo: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let items = snapshot?.documents.compactMap { self.memberFromDoc($0) } ?? []
                    continuation.resume(returning: items)
                }
            }
        }
    }

    func fetchUser(username: String) async throws -> Member? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Member?, Error>) in
            db.collection("member").whereField("username", isEqualTo: username.uppercased()).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let doc = snapshot?.documents.first {
                    continuation.resume(returning: self.memberFromDoc(doc))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func fetchMemberByRecovery(code: Int) async throws -> Member? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Member?, Error>) in
            db.collection("member").whereField("recovery", isEqualTo: code).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let doc = snapshot?.documents.first {
                    continuation.resume(returning: self.memberFromDoc(doc))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func fetchMemberByPhoneNumber(phoneNumber: String) async throws -> Member? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Member?, Error>) in
            db.collection("member").whereField("phonenumber", isEqualTo: phoneNumber).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let doc = snapshot?.documents.first {
                    continuation.resume(returning: self.memberFromDoc(doc))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func fetchUnsyncedMembers() async throws -> [Member] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Member], Error>) in
            db.collection("member").whereField("syncd", isEqualTo: 0).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let items = snapshot?.documents.compactMap { self.memberFromDoc($0) } ?? []
                    continuation.resume(returning: items)
                }
            }
        }
    }

    // MARK: - Updates
    private func updateMember(id: Int, fields: [String: Any]) async throws {
        guard let ref = try await memberDocument(id: id) else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateData(fields) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateGuest(id: Int, guest: Int) async throws {
        try await updateMember(id: id, fields: ["guest": guest])
    }

    func updatePermit(id: Int, permit: Int) async throws {
        try await updateMember(id: id, fields: ["permit": permit])
    }

    func updateOrder(id: Int, order: Int) async throws {
        try await updateMember(id: id, fields: ["orderIndex": order])
    }

    func deleteUser(id: Int) async throws {
        guard let ref = try await memberDocument(id: id) else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateMemberCredentials(id: Int, username: String, password: String) async throws {
        try await updateMember(id: id, fields: ["username": username.uppercased(), "password": hashPassword(password)])
    }

    func updateUser(username: String, firstName: String, lastName: String, phoneNumber: String, dob: String, picture: Data?) async throws {
        var fields: [String: Any] = [
            "firstname": firstName,
            "lastname": lastName,
            "phonenumber": phoneNumber,
            "dob": dob
        ]
        if let picture = picture { fields["picture"] = pictureString(picture) }
        let doc: QueryDocumentSnapshot? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QueryDocumentSnapshot?, Error>) in
            db.collection("member").whereField("username", isEqualTo: username.uppercased()).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot?.documents.first)
                }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            doc?.reference.updateData(fields) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updatePassword(username: String, currentPassword: String, newPassword: String) async throws {
        let currentHashed = hashPassword(currentPassword)
        let doc: QueryDocumentSnapshot? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QueryDocumentSnapshot?, Error>) in
            db.collection("member")
                .whereField("username", isEqualTo: username.uppercased())
                .whereField("password", isEqualTo: currentHashed)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: snapshot?.documents.first)
                    }
                }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            doc?.reference.updateData(["password": hashPassword(newPassword)]) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateToday(username: String, value: Int) async throws {
        let doc: QueryDocumentSnapshot? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QueryDocumentSnapshot?, Error>) in
            db.collection("member").whereField("username", isEqualTo: username.uppercased()).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot?.documents.first)
                }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            doc?.reference.updateData(["today": value]) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // MARK: - Management
    func fetchManagementData() async throws -> [KeyCode] {
        if let management = management {
            return [management]
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[KeyCode], Error>) in
            db.collection("management").getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let items = snapshot?.documents.compactMap { self.keyCodeFromDoc($0) } ?? []
                    if let first = items.first {
                        DispatchQueue.main.async { self.management = first }
                    }
                    continuation.resume(returning: items)
                }
            }
        }
    }

    func fetchKeyCode() async throws -> String? {
        if let management = management {
            return management.code
        }
        let items = try await fetchManagementData()
        return items.first?.code
    }

    func updateManagement(id: Int, code: String, address: String, welcome: String, youtube: URL?, kakao: URL?, notification: String, playwhen: [String], fee: Int, venmo: String) {
        db.collection("management").whereField("id", isEqualTo: id).limit(to: 1).getDocuments { snapshot, _ in
            let fields: [String: Any] = [
                "keycode": code,
                "address": address,
                "welcome": welcome,
                "youtube": youtube?.absoluteString ?? "",
                "kakao": kakao?.absoluteString ?? "",
                "notification": notification,
                "playwhen": playwhen,
                "fee": fee,
                "venmo": venmo
            ]
            if let doc = snapshot?.documents.first {
                doc.reference.setData(fields, merge: true)
            } else {
                var newFields = fields
                newFields["id"] = id
                self.db.collection("management").addDocument(data: newFields)
            }
        }
    }

    // MARK: - User Fields
    func saveUserFields(username: String, fields: [Int]) async -> Bool {
        await withCheckedContinuation { continuation in
            var data: [String: Any] = ["username": username.uppercased()]
            for (index, value) in fields.enumerated() {
                data["field\(index + 1)"] = value
            }
            db.collection("user_fields").document(username.uppercased()).setData(data) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    func fetchUserFields(username: String) async -> [Int]? {
        await withCheckedContinuation { continuation in
            db.collection("user_fields").document(username.uppercased()).getDocument { doc, _ in
                guard let doc = doc, doc.exists else {
                    continuation.resume(returning: nil)
                    return
                }
                var arr: [Int] = []
                for i in 1...12 {
                    arr.append(doc.data()? ["field\(i)"] as? Int ?? 0)
                }
                continuation.resume(returning: arr)
            }
        }
    }
}
