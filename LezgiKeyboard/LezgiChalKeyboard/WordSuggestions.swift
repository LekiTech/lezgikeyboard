import Foundation
import SQLite3

final class WordSuggestions {
    private var db: OpaquePointer?
    private var stmt: OpaquePointer?

    init?() {
        guard let url = Bundle(for: WordSuggestions.self)
            .url(forResource: "lezgi_words", withExtension: "sqlite") else { return nil }
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        let sql = "SELECT word FROM words WHERE word LIKE ? ORDER BY LENGTH(word) LIMIT 3"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    }

    func suggestions(for prefix: String) -> [String] {
        guard !prefix.isEmpty, let stmt else { return [] }
        let pattern = prefix.lowercased().replacingOccurrences(of: "ӏ", with: "I") + "%"
        sqlite3_reset(stmt)
        sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { results.append(String(cString: c)) }
        }
        return results
    }

    deinit { sqlite3_finalize(stmt); sqlite3_close(db) }
}
