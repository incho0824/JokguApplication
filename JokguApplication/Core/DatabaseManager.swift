import Foundation
import SQLite3
import CryptoKit

struct KeyCode: Identifiable {
    let id: Int
    var code: String
    var location: String
}

struct Member: Identifiable {
    let id: Int
    var username: String
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var dob: String
    var attendance: Int
    var permit: Int
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
        let createManagementTable = "CREATE TABLE IF NOT EXISTS management(id INTEGER PRIMARY KEY AUTOINCREMENT, keycode TEXT, location TEXT);"
        let createMemberTable = "CREATE TABLE IF NOT EXISTS member(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT, firstname TEXT, lastname TEXT, phonenumber TEXT, dob TEXT, attendance INTEGER DEFAULT 0, permit INTEGER DEFAULT 0);"
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
                        let insertDefault = "INSERT INTO management (keycode, location) VALUES ('1234', '');"
                        sqlite3_exec(db, insertDefault, nil, nil, nil)
                    }
                }
            }
            sqlite3_finalize(countStmt)
        }
        if sqlite3_exec(db, createMemberTable, nil, nil, nil) != SQLITE_OK {
            print("Could not create member table")
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

    func insertUser(username: String, password: String, firstName: String, lastName: String, phoneNumber: String, dob: String) -> Bool {
        let upperUsername = username.uppercased()
        guard !userExists(upperUsername) else { return false }
        let insertSQL = "INSERT INTO member (username, password, firstname, lastname, phonenumber, dob) VALUES (?, ?, ?, ?, ?, ?);"
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
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
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
        let query = "SELECT id, username, firstname, lastname, phonenumber, dob, attendance, permit FROM member;"
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
                let attendance = Int(sqlite3_column_int(statement, 6))
                let permit = Int(sqlite3_column_int(statement, 7))
                items.append(Member(id: id, username: username, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dob, attendance: attendance, permit: permit))
            }
        }
        sqlite3_finalize(statement)
        return items
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
        let query = "SELECT id, keycode, location FROM management;"
        var statement: OpaquePointer?
        var items: [KeyCode] = []
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                var code = ""
                if let cString = sqlite3_column_text(statement, 1) {
                    code = String(cString: cString)
                }
                var location = ""
                if let lString = sqlite3_column_text(statement, 2) {
                    location = String(cString: lString)
                }
                items.append(KeyCode(id: id, code: code, location: location))
            }
        }
        sqlite3_finalize(statement)
        return items
    }

    func updateManagement(id: Int, code: String, location: String) {
        let query = "UPDATE management SET keycode = ?, location = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: code).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: location).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, Int32(id))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}

