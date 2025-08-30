import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Combine
import FirebaseAuth

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
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var dob: String
    var pictureURL: String?
    var attendance: Int
    var permit: Int
    var guest: Int
    var today: Int
    var syncd: Int
    var orderIndex: Int
}

struct OriginalMember: Identifiable {
    let id: String
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var dob: String
    var permit: Int
    var guest: Int
    var syncd: Int
}

struct UserFields {
    let phoneNumber: String
    var values: [Int]
}

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    private let db: Firestore
    @Published private(set) var management: KeyCode?
    private var managementListener: ListenerRegistration?
    private var memberRefCache: [Int: DocumentReference] = [:]
    private var memberPhoneRefCache: [String: DocumentReference] = [:]

    private var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    private func requireAuth() throws {
        guard isAuthenticated else {
            throw NSError(domain: "Unauthenticated", code: 401)
        }
    }

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
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
                guard self.isAuthenticated else { return }
                let fields: [String: Any] = [
                    "id": 1,
                    "keycode": "1234",
                    "address": "",
                    "welcome": "",
                    "youtube": "",
                    "kakao": "",
                    "notification": "",
                    "playwhen": [],
                    "fee": 0,
                    "venmo": ""
                ]
                self.db.collection("management").addDocument(data: fields)
                let defaultKeyCode = KeyCode(
                    id: 1,
                    code: "1234",
                    address: "",
                    welcome: "",
                    youtube: nil,
                    kakao: nil,
                    notification: "",
                    playwhen: [],
                    fee: 0,
                    venmo: ""
                )
                DispatchQueue.main.async {
                    self.management = defaultKeyCode
                }
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
    private func memberFromDoc(_ doc: DocumentSnapshot) -> Member? {
        guard let data = doc.data() else { return nil }
        let id = data["id"] as? Int ?? 0
        let firstName = data["firstname"] as? String ?? ""
        let lastName = data["lastname"] as? String ?? ""
        let phoneNumber = data["phonenumber"] as? String ?? ""
        let dob = data["dob"] as? String ?? ""
        let pictureURL = data["picture"] as? String
        let attendance = data["attendance"] as? Int ?? 0
        let permit = data["permit"] as? Int ?? 0
        let guest = data["guest"] as? Int ?? 0
        let today = data["today"] as? Int ?? 0
        let syncd = data["syncd"] as? Int ?? 0
        let orderIndex = data["orderIndex"] as? Int ?? 0
        memberRefCache[id] = doc.reference
        if !phoneNumber.isEmpty {
            memberPhoneRefCache[phoneNumber] = doc.reference
        }
        return Member(id: id, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dob, pictureURL: pictureURL, attendance: attendance, permit: permit, guest: guest, today: today, syncd: syncd, orderIndex: orderIndex)
    }

    private func originalMemberFromDoc(_ doc: DocumentSnapshot) -> OriginalMember? {
        guard let data = doc.data() else { return nil }
        let firstName = data["firstname"] as? String ?? ""
        let lastName = data["lastname"] as? String ?? ""
        let phoneNumber = data["phonenumber"] as? String ?? ""
        let dob = data["dob"] as? String ?? ""
        let permit = data["permit"] as? Int ?? 0
        let guest = data["guest"] as? Int ?? 0
        let syncd = data["syncd"] as? Int ?? 0
        return OriginalMember(id: doc.documentID, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dob, permit: permit, guest: guest, syncd: syncd)
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
        if let cached = memberRefCache[id] {
            return cached
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentReference?, Error>) in
            db.collection("member").whereField("id", isEqualTo: id).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let doc = snapshot?.documents.first
                    if let doc = doc {
                        self.memberRefCache[id] = doc.reference
                        if let phone = doc.data()["phonenumber"] as? String {
                            self.memberPhoneRefCache[phone] = doc.reference
                        }
                    }
                    continuation.resume(returning: snapshot?.documents.first?.reference)
                }
            }
        }
    }

    private func memberDocument(phoneNumber: String) async throws -> DocumentReference? {
        if let cached = memberPhoneRefCache[phoneNumber] {
            return cached
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentReference?, Error>) in
            db.collection("member").whereField("phonenumber", isEqualTo: phoneNumber).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let doc = snapshot?.documents.first
                    if let doc = doc, let id = doc.data()["id"] as? Int {
                        self.memberRefCache[id] = doc.reference
                        self.memberPhoneRefCache[phoneNumber] = doc.reference
                    }
                    continuation.resume(returning: doc?.reference)
                }
            }
        }
    }

    // MARK: - Authentication & Users
    func userExists(_ phoneNumber: String) async throws -> Bool {
        if memberPhoneRefCache[phoneNumber] != nil { return true }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            db.collection("member").whereField("phonenumber", isEqualTo: phoneNumber).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let exists = snapshot?.documents.isEmpty == false
                    if exists, let doc = snapshot?.documents.first, let id = doc.data()["id"] as? Int {
                        self.memberRefCache[id] = doc.reference
                        self.memberPhoneRefCache[phoneNumber] = doc.reference
                    }
                    continuation.resume(returning: exists)
                }
            }
        }
    }

    func insertUser(firstName: String, lastName: String, phoneNumber: String, dob: String, picture: Data?, permit: Int = 0, guest: Int = 0) async throws {
        try requireAuth()
        guard try await !userExists(phoneNumber) else { throw NSError(domain: "UserExists", code: 1) }

        let counterRef = db.collection("counters").document("member")
        // Ensure the counter document exists before running the transaction
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            counterRef.getDocument { doc, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if doc?.exists == false {
                    counterRef.setData(["nextId": 1]) { err in
                        if let err = err {
                            continuation.resume(throwing: err)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        // Obtain a new sequential ID using a transaction on the counter document
        let newId: Int = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
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
            "firstname": firstName,
            "lastname": lastName,
            "phonenumber": phoneNumber,
            "dob": dob,
            "attendance": 0,
            "permit": permit,
            "guest": guest,
            "today": 0,
            "syncd": 1,
            "orderIndex": newId
        ]
        if let picture = picture {
            let storageRef = Storage.storage().reference().child("profile_pictures/\(phoneNumber).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            let urlString: String = try await withCheckedThrowingContinuation { continuation in
                storageRef.putData(picture, metadata: metadata) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        storageRef.downloadURL { url, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: url?.absoluteString ?? "")
                            }
                        }
                    }
                }
            }
            data["picture"] = urlString
        }

        let ref = db.collection("member").document()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        memberRefCache[newId] = ref
        memberPhoneRefCache[phoneNumber] = ref
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

    func fetchUnsyncedOriginalMembers() async throws -> [OriginalMember] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[OriginalMember], Error>) in
            db.collection("original_member").whereField("syncd", isEqualTo: 0).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let items = snapshot?.documents.compactMap { self.originalMemberFromDoc($0) } ?? []
                    continuation.resume(returning: items)
                }
            }
        }
    }

    // MARK: - Updates
    private func updateMember(id: Int, fields: [String: Any]) async throws {
        try requireAuth()
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

    func updateSyncd(id: Int, syncd: Int) async throws {
        try await updateMember(id: id, fields: ["syncd": syncd])
    }

    func updateOriginalSyncd(id: String, syncd: Int) async throws {
        try requireAuth()
        let ref = db.collection("original_member").document(id)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateData(["syncd": syncd]) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateOrder(id: Int, order: Int) async throws {
        try await updateMember(id: id, fields: ["orderIndex": order])
    }

    func updateOrders(_ updates: [(Int, Int)]) async throws {
        try requireAuth()
        let batch = db.batch()
        for (id, order) in updates {
            if let ref = try await memberDocument(id: id) {
                batch.updateData(["orderIndex": order], forDocument: ref)
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func deleteUser(id: Int) async throws {
        try requireAuth()
        guard let ref = try await memberDocument(id: id) else { return }

        // Fetch the document to get the phone number for the profile picture path
        let doc = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            ref.getDocument { doc, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let doc = doc {
                    continuation.resume(returning: doc)
                } else {
                    continuation.resume(throwing: NSError(domain: "NotFound", code: 0))
                }
            }
        }

        if let phone = doc.data()? ["phonenumber"] as? String {
            let storageRef = Storage.storage().reference().child("profile_pictures/\(phone).jpg")
            // Attempt to delete the profile picture, but ignore errors if it does not exist
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    storageRef.delete { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            } catch {
                // ignore deletion errors; continue deleting user document
            }
        }

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

    func updateUser(currentPhoneNumber: String, firstName: String, lastName: String, newPhoneNumber: String, dob: String, picture: Data?) async throws {
        try requireAuth()
        var fields: [String: Any] = [
            "firstname": firstName,
            "lastname": lastName,
            "phonenumber": newPhoneNumber,
            "dob": dob
        ]
        if let picture = picture {
            let storageRef = Storage.storage().reference().child("profile_pictures/\(newPhoneNumber).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            let urlString: String = try await withCheckedThrowingContinuation { continuation in
                storageRef.putData(picture, metadata: metadata) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        storageRef.downloadURL { url, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: url?.absoluteString ?? "")
                            }
                        }
                    }
                }
            }
            fields["picture"] = urlString
        }
        guard let ref = try await memberDocument(phoneNumber: currentPhoneNumber) else { return }
        memberPhoneRefCache.removeValue(forKey: currentPhoneNumber)
        memberPhoneRefCache[newPhoneNumber] = ref
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

    func updateToday(phoneNumber: String, value: Int) async throws {
        try requireAuth()
        guard let ref = try await memberDocument(phoneNumber: phoneNumber) else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateData(["today": value]) { error in
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
                    if items.isEmpty {
                        guard self.isAuthenticated else {
                            continuation.resume(returning: [])
                            return
                        }
                        let fields: [String: Any] = [
                            "id": 1,
                            "keycode": "1234",
                            "address": "",
                            "welcome": "",
                            "youtube": "",
                            "kakao": "",
                            "notification": "",
                            "playwhen": [],
                            "fee": 0,
                            "venmo": ""
                        ]
                        self.db.collection("management").addDocument(data: fields)
                        let defaultKeyCode = KeyCode(
                            id: 1,
                            code: "1234",
                            address: "",
                            welcome: "",
                            youtube: nil,
                            kakao: nil,
                            notification: "",
                            playwhen: [],
                            fee: 0,
                            venmo: ""
                        )
                        DispatchQueue.main.async { self.management = defaultKeyCode }
                        continuation.resume(returning: [defaultKeyCode])
                    } else {
                        if let first = items.first {
                            DispatchQueue.main.async { self.management = first }
                        }
                        continuation.resume(returning: items)
                    }
                }
            }
        }
    }

    func fetchKeyCode() async throws -> String? {
        if let management = management {
            return management.code
        }
        let items = try await fetchManagementData()
        return items.first?.code ?? "1234"
    }

    func updateManagement(id: Int, code: String, address: String, welcome: String, youtube: URL?, kakao: URL?, notification: String, playwhen: [String], fee: Int, venmo: String) {
        guard isAuthenticated else { return }
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
    func saveUserFields(phoneNumber: String, fields: [Int]) async -> Bool {
        await withCheckedContinuation { continuation in
            guard self.isAuthenticated else {
                continuation.resume(returning: false)
                return
            }
            var data: [String: Any] = ["phoneNumber": phoneNumber]
            for (index, value) in fields.enumerated() {
                data["field\(index + 1)"] = value
            }
            db.collection("user_fields").document(phoneNumber).setData(data) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    func fetchUserFields(phoneNumber: String) async -> [Int]? {
        await withCheckedContinuation { continuation in
            db.collection("user_fields").document(phoneNumber).getDocument { doc, _ in
                guard let doc = doc, doc.exists else {
                    continuation.resume(returning: nil)
                    return
                }
                var arr: [Int] = []
                for i in 1...12 {
                    arr.append(doc.data()?["field\(i)"] as? Int ?? 0)
                }
                continuation.resume(returning: arr)
            }
        }
    }

    // MARK: - Setup Tables
    func createTablesIfNeeded(for phoneNumber: String) async {
        guard isAuthenticated else { return }

        // Ensure management data exists
        _ = try? await fetchManagementData()

        // Ensure member counter exists
        let counterRef = db.collection("counters").document("member")
        await withCheckedContinuation { continuation in
            counterRef.getDocument { doc, _ in
                if let doc = doc, doc.exists {
                    continuation.resume()
                } else {
                    counterRef.setData(["nextId": 1]) { _ in
                        continuation.resume()
                    }
                }
            }
        }

        // Ensure user_fields document exists for this user
        let userFieldsRef = db.collection("user_fields").document(phoneNumber)
        await withCheckedContinuation { continuation in
            userFieldsRef.getDocument { doc, _ in
                if let doc = doc, doc.exists {
                    continuation.resume()
                } else {
                    var data: [String: Any] = ["phoneNumber": phoneNumber]
                    for i in 1...12 {
                        data["field\(i)"] = 0
                    }
                    userFieldsRef.setData(data) { _ in
                        continuation.resume()
                    }
                }
            }
        }
    }
}
