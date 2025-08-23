import Foundation
import SQLite3
import CryptoKit

struct KeyCode: Identifiable {
    let id: Int
    var code: String
    var address: String
    var welcome: String
    var youtube: URL?
    var notification: String
    var fee: Int
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
}

struct UserFields {
    let username: String
    var values: [Int]
}

class DatabaseManager {
    static let shared = DatabaseManager()
    let db: OpaquePointer?

    private init() {
        var dbPointer: OpaquePointer? = nil
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("users.sqlite")
        if sqlite3_open(fileURL.path, &dbPointer) != SQLITE_OK {
            print("Unable to open database")
        }
        db = dbPointer
        createTables()
    }

    private func createTables() {
        let createManagementTable = "CREATE TABLE IF NOT EXISTS management(id INTEGER PRIMARY KEY AUTOINCREMENT, keycode TEXT, address TEXT, welcome TEXT, youtube TEXT, notification TEXT, fee INTEGER DEFAULT 0);"
        let createMemberTable = "CREATE TABLE IF NOT EXISTS member(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT, firstname TEXT, lastname TEXT, phonenumber TEXT, dob TEXT, picture BLOB, attendance INTEGER DEFAULT 0, permit INTEGER DEFAULT 0);"
        if sqlite3_exec(db, createManagementTable, nil, nil, nil) != SQLITE_OK {
            print("Could not create management table")
        } else {
            // ensure there is always exactly one management row
            let countQuery = "SELECT COUNT(*) FROM management;"
            var countStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
                if sqlite3_step(countStmt) == SQLITE_ROW {
                    let count = sqlite3_column_int(countStmt, 0)
                    if count == 0 {
                        let insertDefault = "INSERT INTO management (keycode, address, welcome, youtube, notification, fee) VALUES ('1234', '', '', '', '', 0);"
                        sqlite3_exec(db, insertDefault, nil, nil, nil)
                    }
                }
            }
            sqlite3_finalize(countStmt)
        }
        if sqlite3_exec(db, createMemberTable, nil, nil, nil) != SQLITE_OK {
            print("Could not create member table")
        }
        // attempt to add picture column for existing databases
        sqlite3_exec(db, "ALTER TABLE member ADD COLUMN picture BLOB;", nil, nil, nil)
        // attempt to add new management columns for existing databases
        sqlite3_exec(db, "ALTER TABLE management ADD COLUMN welcome TEXT;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE management ADD COLUMN youtube TEXT;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE management ADD COLUMN notification TEXT;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE management ADD COLUMN address TEXT;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE management ADD COLUMN fee INTEGER DEFAULT 0;", nil, nil, nil)
        let createUserFieldsTable = "CREATE TABLE IF NOT EXISTS user_fields(username TEXT PRIMARY KEY, field1 INTEGER, field2 INTEGER, field3 INTEGER, field4 INTEGER, field5 INTEGER, field6 INTEGER, field7 INTEGER, field8 INTEGER, field9 INTEGER, field10 INTEGER, field11 INTEGER, field12 INTEGER);"
        if sqlite3_exec(db, createUserFieldsTable, nil, nil, nil) != SQLITE_OK {
            print("Could not create user_fields table")
        }
    }

    func userExists(_ username: String) -> Bool {
        let query = "SELECT 1 FROM member WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                exists = true
            }
        }
        sqlite3_finalize(statement)
        return exists
    }

    func insertUser(username: String, password: String, firstName: String, lastName: String, phoneNumber: String, dob: String, picture: Data?) -> Bool {
        let upperUsername = username.uppercased()
        guard !userExists(upperUsername) else { return false }
        let insertSQL = "INSERT INTO member (username, password, firstname, lastname, phonenumber, dob, picture) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            let hashedPassword = hashPassword(password)
            sqlite3_bind_text(statement, 2, NSString(string: hashedPassword).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, NSString(string: firstName).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, NSString(string: lastName).utf8String, -1, nil)
            sqlite3_bind_text(statement, 5, NSString(string: phoneNumber).utf8String, -1, nil)
            sqlite3_bind_text(statement, 6, NSString(string: dob).utf8String, -1, nil)
            if let picture = picture {
                _ = picture.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, 7, bytes.baseAddress, Int32(picture.count), nil)
                }
            } else {
                sqlite3_bind_null(statement, 7)
            }
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
        if success {
            _ = saveUserFields(username: upperUsername, fields: Array(repeating: 0, count: 12))
        }
        return success
    }

    func validateUser(username: String, password: String) -> Int? {
        let query = "SELECT permit FROM member WHERE username = ? AND password = ? LIMIT 1;"
        var statement: OpaquePointer?
        var permit: Int? = nil
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            let hashedPassword = hashPassword(password)
            sqlite3_bind_text(statement, 2, NSString(string: hashedPassword).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                permit = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return permit
    }

    func fetchMembers() -> [Member] {
        let query = "SELECT id, username, firstname, lastname, phonenumber, dob, picture, attendance, permit FROM member;"
        var statement: OpaquePointer?
        var items: [Member] = []
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                var username = ""
                if let uString = sqlite3_column_text(statement, 1) {
                    username = String(cString: uString)
                }
                var firstName = ""
                if let fString = sqlite3_column_text(statement, 2) {
                    firstName = String(cString: fString)
                }
                var lastName = ""
                if let lString = sqlite3_column_text(statement, 3) {
                    lastName = String(cString: lString)
                }
                var phoneNumber = ""
                if let phString = sqlite3_column_text(statement, 4) {
                    phoneNumber = String(cString: phString)
                }
                var dob = ""
                if let dString = sqlite3_column_text(statement, 5) {
                    dob = String(cString: dString)
                }
                var pictureData: Data? = nil
                if let blob = sqlite3_column_blob(statement, 6) {
                    let length = Int(sqlite3_column_bytes(statement, 6))
                    pictureData = Data(bytes: blob, count: length)
                }
                let attendance = Int(sqlite3_column_int(statement, 7))
                let permit = Int(sqlite3_column_int(statement, 8))
                items.append(Member(id: id, username: username, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dob, picture: pictureData, attendance: attendance, permit: permit))
            }
        }
        sqlite3_finalize(statement)
        return items
    }

    func fetchUser(username: String) -> Member? {
        let query = "SELECT id, username, firstname, lastname, phonenumber, dob, picture, attendance, permit FROM member WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer?
        var member: Member? = nil
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                var uname = ""
                if let uString = sqlite3_column_text(statement, 1) {
                    uname = String(cString: uString)
                }
                var firstName = ""
                if let fString = sqlite3_column_text(statement, 2) {
                    firstName = String(cString: fString)
                }
                var lastName = ""
                if let lString = sqlite3_column_text(statement, 3) {
                    lastName = String(cString: lString)
                }
                var phoneNumber = ""
                if let phString = sqlite3_column_text(statement, 4) {
                    phoneNumber = String(cString: phString)
                }
                var dob = ""
                if let dString = sqlite3_column_text(statement, 5) {
                    dob = String(cString: dString)
                }
                var pictureData: Data? = nil
                if let blob = sqlite3_column_blob(statement, 6) {
                    let length = Int(sqlite3_column_bytes(statement, 6))
                    pictureData = Data(bytes: blob, count: length)
                }
                let attendance = Int(sqlite3_column_int(statement, 7))
                let permit = Int(sqlite3_column_int(statement, 8))
                member = Member(id: id, username: uname, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dob, picture: pictureData, attendance: attendance, permit: permit)
            }
        }
        sqlite3_finalize(statement)
        return member
    }

    func updateUser(username: String, firstName: String, lastName: String, phoneNumber: String, dob: String, picture: Data?) -> Bool {
        let query = "UPDATE member SET firstname = ?, lastname = ?, phonenumber = ?, dob = ?, picture = ? WHERE username = ?;"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: firstName).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: lastName).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, NSString(string: phoneNumber).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, NSString(string: dob).utf8String, -1, nil)
            if let picture = picture {
                _ = picture.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, 5, bytes.baseAddress, Int32(picture.count), nil)
                }
            } else {
                sqlite3_bind_null(statement, 5)
            }
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 6, NSString(string: upperUsername).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
        return success
    }

    func updatePassword(username: String, currentPassword: String, newPassword: String) -> Bool {
        let query = "SELECT password FROM member WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                var stored = ""
                if let cString = sqlite3_column_text(statement, 0) {
                    stored = String(cString: cString)
                }
                let currentHashed = hashPassword(currentPassword)
                if stored == currentHashed {
                    sqlite3_finalize(statement)
                    let update = "UPDATE member SET password = ? WHERE username = ?;"
                    if sqlite3_prepare_v2(db, update, -1, &statement, nil) == SQLITE_OK {
                        let newHashed = hashPassword(newPassword)
                        sqlite3_bind_text(statement, 1, NSString(string: newHashed).utf8String, -1, nil)
                        sqlite3_bind_text(statement, 2, NSString(string: upperUsername).utf8String, -1, nil)
                        if sqlite3_step(statement) == SQLITE_DONE {
                            success = true
                        }
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        return success
    }

    func deleteUser(id: Int) -> Bool {
        let query = "DELETE FROM member WHERE id = ?;"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
        return success
    }

    func updatePermit(id: Int, permit: Int) -> Bool {
        let query = "UPDATE member SET permit = ? WHERE id = ?;"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(permit))
            sqlite3_bind_int(statement, 2, Int32(id))
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
        return success
    }

    func saveUserFields(username: String, fields: [Int]) -> Bool {
        guard !fields.isEmpty && fields.count <= 12 else { return false }
        for value in fields {
            guard (0...100).contains(value) else { return false }
        }
        let query = "INSERT OR REPLACE INTO user_fields (username, field1, field2, field3, field4, field5, field6, field7, field8, field9, field10, field11, field12) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            for i in 0..<12 {
                if i < fields.count {
                    sqlite3_bind_int(statement, Int32(i + 2), Int32(fields[i]))
                } else {
                    sqlite3_bind_null(statement, Int32(i + 2))
                }
            }
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
        return success
    }

    func fetchUserFields(username: String) -> [Int]? {
        let query = "SELECT field1, field2, field3, field4, field5, field6, field7, field8, field9, field10, field11, field12 FROM user_fields WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer?
        var result: [Int]? = nil
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let upperUsername = username.uppercased()
            sqlite3_bind_text(statement, 1, NSString(string: upperUsername).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                var values: [Int] = []
                for i in 0..<12 {
                    if sqlite3_column_type(statement, Int32(i)) != SQLITE_NULL {
                        values.append(Int(sqlite3_column_int(statement, Int32(i))))
                    } else {
                        break
                    }
                }
                result = values.isEmpty ? nil : values
            }
        }
        sqlite3_finalize(statement)
        return result
    }

    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    func fetchKeyCode() -> String? {
        let query = "SELECT keycode FROM management LIMIT 1;"
        var statement: OpaquePointer?
        var code: String? = nil
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    code = String(cString: cString)
                }
            }
        }
        sqlite3_finalize(statement)
        return code
    }

    func fetchManagementData() -> [KeyCode] {
        let query = "SELECT id, keycode, address, welcome, youtube, notification, fee FROM management;"
        var statement: OpaquePointer?
        var items: [KeyCode] = []
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                var code = ""
                if let cString = sqlite3_column_text(statement, 1) {
                    code = String(cString: cString)
                }
                var address = ""
                if let lString = sqlite3_column_text(statement, 2) {
                    address = String(cString: lString)
                }
                var welcome = ""
                if let wString = sqlite3_column_text(statement, 3) {
                    welcome = String(cString: wString)
                }
                var youtube: URL? = nil
                if let yString = sqlite3_column_text(statement, 4) {
                    let lowered = String(cString: yString).lowercased()
                    youtube = URL(string: lowered)
                }
                var notification = ""
                if let nString = sqlite3_column_text(statement, 5) {
                    notification = String(cString: nString)
                }
                let fee = Int(sqlite3_column_int(statement, 6))
                items.append(KeyCode(id: id, code: code, address: address, welcome: welcome, youtube: youtube, notification: notification, fee: fee))
            }
        }
        sqlite3_finalize(statement)
        return items
    }

    func updateManagement(id: Int, code: String, address: String, welcome: String, youtube: URL?, notification: String, fee: Int) {
        let query = "UPDATE management SET keycode = ?, address = ?, welcome = ?, youtube = ?, notification = ?, fee = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: code).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: address).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, NSString(string: welcome).utf8String, -1, nil)
            let lowered = (youtube?.absoluteString.lowercased() ?? "")
            sqlite3_bind_text(statement, 4, NSString(string: lowered).utf8String, -1, nil)
            sqlite3_bind_text(statement, 5, NSString(string: notification).utf8String, -1, nil)
            sqlite3_bind_int(statement, 6, Int32(fee))
            sqlite3_bind_int(statement, 7, Int32(id))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}

