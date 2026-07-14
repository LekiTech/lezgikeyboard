//
//  LearnedWords.swift
//  LezgiChalKeyboard
//
//  Stages 1-3 of docs/LOCAL_SUGGESTIONS_ROADMAP.md: on-device learned word
//  frequency with cleanup limits and bigram context. The store lives in the
//  keyboard extension's own sandbox container — it is not shared with the
//  containing app and nothing ever leaves the device. Only individual words
//  and word pairs are stored, never sentences.
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
    /// A pair must be seen this many times before it produces next-word
    /// suggestions, so a one-off combination never surfaces.
    private static let minPairUses = 2
    /// Words used within this window get a recency boost in ranking.
    private static let recencyWindow: TimeInterval = 14 * 24 * 3600
    /// Hard cap on stored words; the lowest-ranked rows are pruned past it,
    /// which also keeps learned.sqlite far under the size target.
    private static let maxWords = 5000
    /// Hard cap on stored word pairs, pruned the same way.
    private static let maxBigrams = 10000
    /// After this many learn events every counter is halved (integer
    /// division), so one-off words vanish and stale habits fade out.
    private static let decayAfterEvents = 2000
    /// How often (in learn events) the row cap is checked.
    private static let pruneCheckEvery = 200
    /// Bumped when the learnability filters tighten; old records that no
    /// longer pass are purged once per bump.
    private static let filtersVersion = 1

    /// Digraph tails taken from the layout's long-press alternates (ӏ, ь, ъ)
    /// plus the Latin palochka form the bundled dictionary uses (lowercased).
    /// A tail extends the previous letter instead of counting as its own, so
    /// "цӏ" or "къ" is one Lezgi letter even though it is two characters.
    private static let digraphTails: Set<Character> = {
        var tails = Set<Character>()
        for alternates in LezgiLayout.callouts.values {
            for alternate in alternates where alternate.count == 2 {
                if let tail = alternate.last { tails.insert(tail) }
            }
        }
        tails.insert("i")
        return tails
    }()

    /// Number of Lezgi letters in a lowercased token, counting digraphs as
    /// single letters.
    private static func lezgiLetterCount(_ word: String) -> Int {
        word.reduce(0) { digraphTails.contains($1) ? $0 : $0 + 1 }
    }

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
            CREATE TABLE IF NOT EXISTS user_bigram(
                prev TEXT NOT NULL,
                word TEXT NOT NULL,
                count INTEGER NOT NULL DEFAULT 0,
                last_used INTEGER NOT NULL,
                PRIMARY KEY(prev, word)
            );
            INSERT OR IGNORE INTO meta(key, value) VALUES('schema_version', \(Self.schemaVersion));
            INSERT OR IGNORE INTO meta(key, value) VALUES('total_events', 0);
            """)
        // Records learned before the current filters existed (single letters,
        // lone digraphs like "цӏ", digits...) are purged once per filter
        // version bump; the bundled dictionary is a separate read-only
        // database and is not affected.
        if intValue("SELECT value FROM meta WHERE key = 'filters_version'") < Self.filtersVersion {
            purgeUnlearnableWords()
            exec("INSERT OR REPLACE INTO meta(key, value) VALUES('filters_version', \(Self.filtersVersion))")
        }
    }

    deinit { sqlite3_close(db) }

    /// Words worth learning: no digits, no email/URL fragments, and at least
    /// two Lezgi letters — a lone digraph like "цӏ" is still one letter.
    /// Separators never reach here (the prefix tokenizer splits on them),
    /// but pasted text can still carry such tokens past a space.
    private func isLearnable(_ word: String) -> Bool {
        guard word.count <= Self.maxWordLength else { return false }
        guard Self.lezgiLetterCount(word) >= 2 else { return false }
        guard !word.contains(where: \.isNumber) else { return false }
        guard !word.contains("@"), !word.contains("/"), !word.contains(".") else { return false }
        return true
    }

    /// Records a completed word and, when the preceding word of the same
    /// sentence is known, the (previous, word) pair. `picked` marks a word
    /// chosen from the suggestion bar, which is a stronger signal than
    /// plain typing.
    func learn(_ word: String, previous: String?, picked: Bool) {
        let w = word.lowercased()
        guard isLearnable(w) else { return }
        let now = Int64(Date().timeIntervalSince1970)
        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO user_word(word, count, picked, last_used) VALUES(?1, ?2, ?3, ?4)
            ON CONFLICT(word) DO UPDATE SET
                count = count + ?2, picked = picked + ?3, last_used = ?4
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, w, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, picked ? 0 : 1)
        sqlite3_bind_int(stmt, 3, picked ? 1 : 0)
        sqlite3_bind_int64(stmt, 4, now)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)

        if let prev = previous?.lowercased(), isLearnable(prev) {
            var pairStmt: OpaquePointer?
            let pairSQL = """
                INSERT INTO user_bigram(prev, word, count, last_used) VALUES(?1, ?2, 1, ?3)
                ON CONFLICT(prev, word) DO UPDATE SET
                    count = count + 1, last_used = ?3
                """
            if sqlite3_prepare_v2(db, pairSQL, -1, &pairStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(pairStmt, 1, prev, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(pairStmt, 2, w, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(pairStmt, 3, now)
                sqlite3_step(pairStmt)
            }
            sqlite3_finalize(pairStmt)
        }
        maintain()
    }

    /// Most likely follow-ups to `previous` from the bigram table, best
    /// first (Stage 4 next-word suggestions). Recent pairs get the same
    /// boost as recent words.
    func nextWords(after previous: String, limit: Int = 3) -> [String] {
        let prev = previous.lowercased()
        guard !prev.isEmpty else { return [] }
        var stmt: OpaquePointer?
        let sql = """
            SELECT word FROM user_bigram
            WHERE prev = ?1 AND count >= ?2 AND LENGTH(word) >= 2
            ORDER BY count * (CASE WHEN last_used >= ?3 THEN 2 ELSE 1 END) DESC,
                     last_used DESC
            LIMIT ?4
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, prev, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(Self.minPairUses))
        sqlite3_bind_int64(stmt, 3, Int64(Date().timeIntervalSince1970 - Self.recencyWindow))
        sqlite3_bind_int(stmt, 4, Int32(limit))
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { results.append(String(cString: c)) }
        }
        return results
    }

    // MARK: - Cleanup (Stage 2)

    /// Counts learn events and runs the periodic cleanup: decay once per
    /// `decayAfterEvents`, a row-cap check once per `pruneCheckEvery`.
    private func maintain() {
        exec("UPDATE meta SET value = value + 1 WHERE key = 'total_events'")
        let events = intValue("SELECT value FROM meta WHERE key = 'total_events'")
        if events >= Self.decayAfterEvents {
            exec("UPDATE user_word SET count = count / 2, picked = picked / 2")
            exec("DELETE FROM user_word WHERE count + picked = 0")
            exec("UPDATE user_bigram SET count = count / 2")
            exec("DELETE FROM user_bigram WHERE count = 0")
            exec("UPDATE meta SET value = 0 WHERE key = 'total_events'")
            prune()
            exec("VACUUM")
        } else if events % Self.pruneCheckEvery == 0 {
            prune()
        }
    }

    /// Deletes every stored word that no longer passes `isLearnable` —
    /// SQL cannot count Lezgi letters, so the check runs in Swift.
    /// `delete` also drops the pairs referencing each purged word.
    private func purgeUnlearnableWords() {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT word FROM user_word", -1, &stmt, nil) == SQLITE_OK else { return }
        var stale: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) {
                let word = String(cString: c)
                if !isLearnable(word) { stale.append(word) }
            }
        }
        sqlite3_finalize(stmt)
        for word in stale { delete(word) }
    }

    /// Deletes the lowest-ranked rows once the hard caps are exceeded.
    private func prune() {
        let excess = intValue("SELECT COUNT(*) FROM user_word") - Self.maxWords
        if excess > 0 {
            exec("""
                DELETE FROM user_word WHERE word IN (
                    SELECT word FROM user_word
                    ORDER BY count + 3 * picked ASC, last_used ASC
                    LIMIT \(excess)
                )
                """)
        }
        let excessPairs = intValue("SELECT COUNT(*) FROM user_bigram") - Self.maxBigrams
        if excessPairs > 0 {
            exec("""
                DELETE FROM user_bigram WHERE rowid IN (
                    SELECT rowid FROM user_bigram
                    ORDER BY count ASC, last_used ASC
                    LIMIT \(excessPairs)
                )
                """)
        }
    }

    private func intValue(_ sql: String) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Learned words matching the prefix, best first. Picked words weigh more
    /// than merely typed ones, recently used words get a boost, and words
    /// that have followed `previous` before are boosted by the pair counter
    /// (Stage 3 — candidates stay the same, bigrams only affect ranking).
    func suggestions(for prefix: String, previous: String?, limit: Int = 3) -> [String] {
        let p = prefix.lowercased()
        guard !p.isEmpty else { return [] }
        var stmt: OpaquePointer?
        let sql = """
            SELECT w.word FROM user_word w
            LEFT JOIN user_bigram b ON b.prev = ?5 AND b.word = w.word
            WHERE w.word LIKE ?1 ESCAPE '\\' AND w.count + w.picked >= ?2
                  AND LENGTH(w.word) >= 2
            ORDER BY (w.count + 3 * w.picked)
                     * (CASE WHEN w.last_used >= ?3 THEN 2 ELSE 1 END)
                     * (1 + MIN(IFNULL(b.count, 0), 4)) DESC,
                     w.last_used DESC
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
        sqlite3_bind_text(stmt, 5, previous?.lowercased() ?? "", -1, SQLITE_TRANSIENT)
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { results.append(String(cString: c)) }
        }
        return results
    }

    /// Stage 5: wipes everything learned — words, pairs, and the event
    /// counter. The bundled dictionary is untouched.
    func reset() {
        exec("DELETE FROM user_word")
        exec("DELETE FROM user_bigram")
        exec("UPDATE meta SET value = 0 WHERE key = 'total_events'")
        exec("VACUUM")
    }

    /// Removes a single learned word and every pair that references it
    /// (the bundled dictionary is untouched).
    func delete(_ word: String) {
        let w = word.lowercased()
        for sql in ["DELETE FROM user_word WHERE word = ?1",
                    "DELETE FROM user_bigram WHERE word = ?1 OR prev = ?1"] {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
            sqlite3_bind_text(stmt, 1, w, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}
