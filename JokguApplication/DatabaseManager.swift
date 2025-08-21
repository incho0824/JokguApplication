import Foundation
import SQLite3

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

    func insertKeyCode(_ keycode: String) {
        let insertSQL = "INSERT INTO management (keycode) VALUES (?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: keycode).utf8String, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
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

    func validateUser(username: String, password: String) -> Bool {
        let query = "SELECT 1 FROM member WHERE username = ? AND password = ? LIMIT 1;"
        var statement: OpaquePointer?
        var valid = false
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, NSString(string: username).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: password).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                valid = true
            }
        }
        sqlite3_finalize(statement)
        return valid
    }
}

