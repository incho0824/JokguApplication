import Foundation
import SQLite3

struct KeyCode: Identifiable {
    let id: Int
    var code: String
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
        let createManagementTable = "CREATE TABLE IF NOT EXISTS management(id INTEGER PRIMARY KEY AUTOINCREMENT, keycode TEXT);"
        let createMemberTable = "CREATE TABLE IF NOT EXISTS member(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT, permit INTEGER DEFAULT 0);"
        if sqlite3_exec(db, createManagementTable, nil, nil, nil) != SQLITE_OK {
            print("Could not create management table")
        }
        if sqlite3_exec(db, createMemberTable, nil, nil, nil) != SQLITE_OK {
            print("Could not create member table")
        }
    }

    func insertKeyCode(_ keycode: String) -> Bool {
        let insertSQL = "INSERT INTO management (keycode) VALUES (?);"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: keycode).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_DONE {
                success = true
            }
        }
        sqlite3_finalize(statement)
        return success
    }

    func userExists(_ username: String) -> Bool {
        let query = "SELECT 1 FROM member WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: username).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                exists = true
            }
        }
        sqlite3_finalize(statement)
        return exists
    }

    func insertUser(username: String, password: String) -> Bool {
        guard !userExists(username) else { return false }
        let insertSQL = "INSERT INTO member (username, password, permit) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: username).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: password).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, 0)
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
            sqlite3_bind_text(statement, 1, NSString(string: username).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: password).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                permit = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return permit
    }

    func fetchKeyCodes() -> [KeyCode] {
        let query = "SELECT id, keycode FROM management;"
        var statement: OpaquePointer?
        var items: [KeyCode] = []
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                if let cString = sqlite3_column_text(statement, 1) {
                    let code = String(cString: cString)
                    items.append(KeyCode(id: id, code: code))
                }
            }
        }
        sqlite3_finalize(statement)
        return items
    }

    func updateKeyCode(id: Int, code: String) {
        let query = "UPDATE management SET keycode = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: code).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(id))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func deleteKeyCode(id: Int) {
        let query = "DELETE FROM management WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}

