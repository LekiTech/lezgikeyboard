//
//  LearnedWords.swift
//  LezgiChalKeyboard
//
//  Stage 1 of docs/LOCAL_SUGGESTIONS_ROADMAP.md: on-device learned word
//  frequency. The store lives in the keyboard extension's own sandbox
//  container — it is not shared with the containing app and nothing ever
//  leaves the device. Only individual words are stored, never sentences.
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LearnedWords {
    private var db: OpaquePointer?

    private static let schemaVersion = 1
    /// Sanity bound so a pathological token cannot bloat a row.
    private static let maxWordLength = 64
    /// A word must be confirmed this many times (typed or picked) before it
    /// starts being suggested, so a typo made once or twice never surfaces.
    private static let minUses = 3
    /// Words used within this window get a recency boost in ranking.
    private static let recencyWindow: TimeInterval = 14 * 24 * 3600

    init?() {
        guard let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("learned.sqlite").path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        exec("PRAGMA journal_mode=WAL")
        exec("""
            CREATE TABLE IF NOT EXISTS meta(
                key TEXT PRIMARY KEY,
                value INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS user_word(
                word TEXT PRIMARY KEY,
                count INTEGER NOT NULL DEFAULT 0,
                picked INTEGER NOT NULL DEFAULT 0,
                last_used INTEGER NOT NULL
            );
            INSERT OR IGNORE INTO meta(key, value) VALUES('schema_version', \(Self.schemaVersion));
            """)
    }

    deinit { sqlite3_close(db) }

    /// Records a completed word. `picked` marks a word chosen from the
    /// suggestion bar, which is a stronger signal than plain typing.
    func learn(_ word: String, picked: Bool) {
        let w = word.lowercased()
        guard !w.isEmpty, w.count <= Self.maxWordLength else { return }
        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO user_word(word, count, picked, last_used) VALUES(?1, ?2, ?3, ?4)
            ON CONFLICT(word) DO UPDATE SET
                count = count + ?2, picked = picked + ?3, last_used = ?4
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, w, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, picked ? 0 : 1)
        sqlite3_bind_int(stmt, 3, picked ? 1 : 0)
        sqlite3_bind_int64(stmt, 4, Int64(Date().timeIntervalSince1970))
        sqlite3_step(stmt)
    }

    /// Learned words matching the prefix, best first. Picked words weigh more
    /// than merely typed ones, and recently used words get a boost.
    func suggestions(for prefix: String, limit: Int = 3) -> [String] {
        let p = prefix.lowercased()
        guard !p.isEmpty else { return [] }
        var stmt: OpaquePointer?
        let sql = """
            SELECT word FROM user_word
            WHERE word LIKE ?1 ESCAPE '\\' AND count + picked >= ?2
            ORDER BY (count + 3 * picked) * (CASE WHEN last_used >= ?3 THEN 2 ELSE 1 END) DESC,
                     last_used DESC
            LIMIT ?4
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let pattern = p
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_") + "%"
        sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(Self.minUses))
        sqlite3_bind_int64(stmt, 3, Int64((Date().timeIntervalSince1970 - Self.recencyWindow)))
        sqlite3_bind_int(stmt, 4, Int32(limit))
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { results.append(String(cString: c)) }
        }
        return results
    }

    /// Removes a single learned word (the bundled dictionary is untouched).
    func delete(_ word: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM user_word WHERE word = ?1", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, word.lowercased(), -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}
