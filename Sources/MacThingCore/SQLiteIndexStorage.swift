import CSQLite
import Foundation

public enum SQLiteIndexStorage {
    public static func load(from url: URL) throws -> IndexSnapshot {
        let database = try SQLiteDatabase(url: url)
        try database.createSchema()

        let rootPath = try database.stringMetaValue(forKey: "rootPath") ?? NSHomeDirectory()
        let createdAt = try database.dateMetaValue(forKey: "updatedAt") ?? Date()
        let entries = try database.loadEntries()
        return IndexSnapshot(rootPath: rootPath, createdAt: createdAt, entries: entries)
    }

    public static func replace(_ snapshot: IndexSnapshot, to url: URL) throws {
        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        try database.replace(snapshot)
    }

    public static func upsert(entries: [FileEntry], rootPath: String, to url: URL) throws {
        guard !entries.isEmpty else {
            return
        }

        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        try database.upsert(entries: entries, rootPath: rootPath)
    }

    public static func delete(paths: [String], rootPath: String, from url: URL) throws {
        guard !paths.isEmpty else {
            return
        }

        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        try database.delete(paths: paths, rootPath: rootPath)
    }

    public static func candidateEntries(
        terms: [String],
        limit: Int,
        from url: URL
    ) throws -> [FileEntry] {
        let hint = SearchCandidateHint(terms: terms, canUseDatabaseCandidates: !terms.isEmpty)
        return try candidateEntries(hint: hint, limit: limit, from: url)
    }

    public static func candidateEntries(
        hint: SearchCandidateHint,
        limit: Int,
        from url: URL
    ) throws -> [FileEntry] {
        guard hint.canUseDatabaseCandidates, !hint.terms.isEmpty || hint.hasStructuredFilters else {
            return []
        }

        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        return try database.candidateEntries(hint: hint, limit: limit)
    }

    public static func windowEntries(
        limit: Int,
        offset: Int,
        from url: URL
    ) throws -> [FileEntry] {
        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        return try database.windowEntries(limit: limit, offset: offset)
    }

    public static func entryCount(from url: URL) throws -> Int {
        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        return try database.entryCount()
    }

    public static func deleteEntries(
        inSkippedDirectoryNames names: Set<String>,
        from url: URL
    ) throws -> Int {
        let database = try SQLiteDatabase(url: url)
        try database.createSchema()
        return try database.deleteEntries(inSkippedDirectoryNames: names)
    }
}

private final class SQLiteDatabase {
    private final class SchemaReadyCache: @unchecked Sendable {
        private let lock = NSLock()
        private var paths = Set<String>()

        func contains(_ path: String) -> Bool {
            lock.lock()
            let result = paths.contains(path)
            lock.unlock()
            return result
        }

        func insert(_ path: String) {
            lock.lock()
            paths.insert(path)
            lock.unlock()
        }
    }

    private static let schemaReadyCache = SchemaReadyCache()

    private var db: OpaquePointer?
    private let databasePath: String
    private let derivedColumnsBackfillKey = "derivedColumnsBackfilledV3"
    private let trigramBackfillKey = "trigramBackfilledV1"

    init(url: URL) throws {
        self.databasePath = url.path
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open SQLite database"
            throw IndexStorageError.sqlite(message)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func createSchema() throws {
        try configureConnection()
        if Self.schemaReadyCache.contains(databasePath),
           try hasCoreSchemaTables() {
            return
        }

        try execute("PRAGMA journal_mode=WAL;")
        try execute("""
            CREATE TABLE IF NOT EXISTS meta (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );
            """)
        try execute("""
            CREATE TABLE IF NOT EXISTS entries (
                path TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                parent TEXT NOT NULL,
                extension_name TEXT NOT NULL DEFAULT '',
                name_length INTEGER NOT NULL DEFAULT 0,
                name_part_length INTEGER NOT NULL DEFAULT 0,
                name_character_count INTEGER NOT NULL DEFAULT 0,
                path_length INTEGER NOT NULL DEFAULT 0,
                path_part_length INTEGER NOT NULL DEFAULT 0,
                extension_length INTEGER NOT NULL DEFAULT 0,
                name_utf8_length INTEGER NOT NULL DEFAULT 0,
                path_utf8_length INTEGER NOT NULL DEFAULT 0,
                kind TEXT NOT NULL,
                byte_size INTEGER,
                created_at REAL,
                modified_at REAL,
                accessed_at REAL,
                indexed_at REAL NOT NULL,
                run_count INTEGER NOT NULL DEFAULT 0,
                last_run_at REAL,
                attributes INTEGER NOT NULL DEFAULT 0,
                file_id TEXT,
                volume_id TEXT,
                file_list_name TEXT,
                file_list_path TEXT,
                media_title TEXT,
                media_artist TEXT,
                media_album TEXT,
                media_comment TEXT,
                media_genre TEXT,
                media_track INTEGER,
                media_year INTEGER
            );
            """)
        try? execute("ALTER TABLE entries ADD COLUMN attributes INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN extension_name TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE entries ADD COLUMN name_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN name_part_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN name_character_count INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN path_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN path_part_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN extension_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN name_utf8_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN path_utf8_length INTEGER NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE entries ADD COLUMN file_id TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN volume_id TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN file_list_name TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN file_list_path TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN media_title TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN media_artist TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN media_album TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN media_comment TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN media_genre TEXT;")
        try? execute("ALTER TABLE entries ADD COLUMN media_track INTEGER;")
        try? execute("ALTER TABLE entries ADD COLUMN media_year INTEGER;")
        try execute("CREATE INDEX IF NOT EXISTS entries_name_idx ON entries(name);")
        try execute("CREATE INDEX IF NOT EXISTS entries_parent_idx ON entries(parent);")
        try execute("CREATE INDEX IF NOT EXISTS entries_extension_idx ON entries(extension_name);")
        try execute("CREATE INDEX IF NOT EXISTS entries_name_length_idx ON entries(name_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_name_part_length_idx ON entries(name_part_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_name_character_count_idx ON entries(name_character_count);")
        try execute("CREATE INDEX IF NOT EXISTS entries_path_length_idx ON entries(path_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_path_part_length_idx ON entries(path_part_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_extension_length_idx ON entries(extension_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_name_utf8_length_idx ON entries(name_utf8_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_path_utf8_length_idx ON entries(path_utf8_length);")
        try execute("CREATE INDEX IF NOT EXISTS entries_kind_idx ON entries(kind);")
        try execute("CREATE INDEX IF NOT EXISTS entries_modified_idx ON entries(modified_at);")
        try execute("CREATE INDEX IF NOT EXISTS entries_created_idx ON entries(created_at);")
        try execute("CREATE INDEX IF NOT EXISTS entries_accessed_idx ON entries(accessed_at);")
        try execute("CREATE INDEX IF NOT EXISTS entries_indexed_idx ON entries(indexed_at);")
        try execute("CREATE INDEX IF NOT EXISTS entries_last_run_idx ON entries(last_run_at);")
        try execute("CREATE INDEX IF NOT EXISTS entries_size_idx ON entries(byte_size);")
        try execute("CREATE INDEX IF NOT EXISTS entries_attributes_idx ON entries(attributes);")
        try execute("CREATE INDEX IF NOT EXISTS entries_identity_idx ON entries(volume_id, file_id);")
        try execute("CREATE INDEX IF NOT EXISTS entries_file_list_source_idx ON entries(file_list_name, file_list_path);")
        try execute("CREATE INDEX IF NOT EXISTS entries_media_track_idx ON entries(media_track);")
        try execute("CREATE INDEX IF NOT EXISTS entries_media_year_idx ON entries(media_year);")
        try execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
                path UNINDEXED,
                name,
                parent
            );
            """)
        try execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_trigram USING fts5(
                path,
                tokenize='trigram'
            );
            """)
        try backfillDerivedColumnsIfNeeded()
        try backfillTrigramIndexIfNeeded()
        Self.schemaReadyCache.insert(databasePath)
    }

    private func configureConnection() throws {
        try execute("PRAGMA synchronous=NORMAL;")
        try execute("PRAGMA temp_store=MEMORY;")
    }

    private func hasCoreSchemaTables() throws -> Bool {
        let tableCount = try query(
            """
            SELECT COUNT(*)
            FROM sqlite_master
            WHERE type = 'table'
              AND name IN ('meta', 'entries', 'entries_fts', 'entries_trigram');
            """
        ) { statement in
            statement.optionalInt(at: 0) ?? 0
        }.first ?? 0
        return tableCount == 4
    }

    private struct DerivedLengthValues {
        let extensionName: String
        let nameLength: Int
        let namePartLength: Int
        let nameCharacterCount: Int
        let pathLength: Int
        let pathPartLength: Int
        let extensionLength: Int
        let nameUTF8Length: Int
        let pathUTF8Length: Int
    }

    private func derivedLengthValues(path: String, name: String, parent: String) -> DerivedLengthValues {
        let extensionName = URL(fileURLWithPath: name).pathExtension.lowercased()
        let namePart: String
        if !extensionName.isEmpty, name.count > extensionName.count + 1 {
            namePart = String(name.dropLast(extensionName.count + 1))
        } else {
            namePart = name
        }

        return DerivedLengthValues(
            extensionName: extensionName,
            nameLength: name.utf16.count,
            namePartLength: namePart.utf16.count,
            nameCharacterCount: name.count,
            pathLength: path.utf16.count,
            pathPartLength: SearchEngine.normalizedFolderPath(parent).utf16.count,
            extensionLength: extensionName.utf16.count,
            nameUTF8Length: name.utf8.count,
            pathUTF8Length: path.utf8.count
        )
    }

    private func backfillDerivedColumnsIfNeeded() throws {
        if try stringMetaValue(forKey: derivedColumnsBackfillKey) == "1" {
            return
        }

        struct DerivedRow {
            let path: String
            let name: String
            let parent: String
            let kind: FileKind
            let attributes: FileAttributes
        }

        let rows = try query(
            """
            SELECT path, name, parent, kind, attributes
            FROM entries;
            """
        ) { statement in
            let path = statement.text(at: 0) ?? ""
            let name = statement.text(at: 1) ?? ""
            let parent = statement.text(at: 2) ?? ""
            let kind = FileKind(rawValue: statement.text(at: 3) ?? "") ?? .other
            let rawAttributes = statement.optionalInt(at: 4) ?? 0
            let attributes = rawAttributes == 0
                ? FileAttributes.inferred(kind: kind, name: name, path: path)
                : FileAttributes(rawValue: rawAttributes)
            return DerivedRow(path: path, name: name, parent: parent, kind: kind, attributes: attributes)
        }

        try transaction {
            try withStatement("""
                UPDATE entries
                SET extension_name = ?,
                    name_length = ?,
                    name_part_length = ?,
                    name_character_count = ?,
                    path_length = ?,
                    path_part_length = ?,
                    extension_length = ?,
                    name_utf8_length = ?,
                    path_utf8_length = ?,
                    attributes = ?
                WHERE path = ?;
                """) { statement in
                for row in rows {
                    let derived = derivedLengthValues(path: row.path, name: row.name, parent: row.parent)
                    try statement.reset()
                    try statement.bind([
                        .text(derived.extensionName),
                        .int(Int64(derived.nameLength)),
                        .int(Int64(derived.namePartLength)),
                        .int(Int64(derived.nameCharacterCount)),
                        .int(Int64(derived.pathLength)),
                        .int(Int64(derived.pathPartLength)),
                        .int(Int64(derived.extensionLength)),
                        .int(Int64(derived.nameUTF8Length)),
                        .int(Int64(derived.pathUTF8Length)),
                        .int(Int64(row.attributes.rawValue)),
                        .text(row.path)
                    ])
                    try statement.stepDone()
                }
            }
            try setMetaValue("1", forKey: derivedColumnsBackfillKey)
        }
    }

    private func backfillTrigramIndexIfNeeded() throws {
        if try stringMetaValue(forKey: trigramBackfillKey) == "1" {
            return
        }

        let paths = try query("SELECT path FROM entries;") { statement in
            statement.text(at: 0) ?? ""
        }

        try transaction {
            try execute("DELETE FROM entries_trigram;")
            try withStatement("INSERT INTO entries_trigram(path) VALUES (?);") { statement in
                for path in paths where !path.isEmpty {
                    try statement.reset()
                    try statement.bind([.text(path)])
                    try statement.stepDone()
                }
            }
            try setMetaValue("1", forKey: trigramBackfillKey)
        }
    }

    func replace(_ snapshot: IndexSnapshot) throws {
        try transaction {
            try setMetaValue(snapshot.rootPath, forKey: "rootPath")
            try setMetaValue(String(snapshot.createdAt.timeIntervalSince1970), forKey: "updatedAt")
            try execute("DELETE FROM entries;")
            try execute("DELETE FROM entries_fts;")
            try execute("DELETE FROM entries_trigram;")
            try insert(entries: snapshot.entries)
        }
    }

    func upsert(entries: [FileEntry], rootPath: String) throws {
        try transaction {
            try setMetaValue(rootPath, forKey: "rootPath")
            try setMetaValue(String(Date().timeIntervalSince1970), forKey: "updatedAt")
            try delete(paths: entries.map(\.path), updateMeta: false)
            try insert(entries: entries)
        }
    }

    func delete(paths: [String], rootPath: String) throws {
        try transaction {
            try setMetaValue(rootPath, forKey: "rootPath")
            try setMetaValue(String(Date().timeIntervalSince1970), forKey: "updatedAt")
            try delete(paths: paths, updateMeta: false)
        }
    }

    func loadEntries() throws -> [FileEntry] {
        try query(
            """
            SELECT path, name, parent, kind, byte_size, created_at, modified_at,
                   accessed_at, indexed_at, run_count, last_run_at, attributes,
                   file_id, volume_id, file_list_name, file_list_path,
                   media_title, media_artist, media_album,
                   media_comment, media_genre, media_track, media_year
            FROM entries
            ORDER BY path;
            """
        ) { statement in
            self.entry(from: statement)
        }
    }

    func candidateEntries(hint: SearchCandidateHint, limit: Int) throws -> [FileEntry] {
        let safeLimit = max(1, min(limit, 20_000))
        let needsSubstringFallback = needsSubstringFallback(for: hint.terms)
        var candidates: [FileEntry] = []

        if let ftsQuery = ftsMatchQuery(for: hint.terms) {
            candidates.append(contentsOf: try ftsCandidateEntries(
                matchQuery: ftsQuery,
                hint: hint,
                limit: safeLimit
            ))
            if !needsSubstringFallback && candidates.count >= min(safeLimit, 1_000) {
                return uniqueEntries(candidates)
            }
        }

        if let trigramQuery = trigramMatchQuery(for: hint.terms) {
            candidates.append(contentsOf: try trigramCandidateEntries(
                matchQuery: trigramQuery,
                hint: hint,
                limit: safeLimit
            ))
        } else {
            candidates.append(contentsOf: try likeCandidateEntries(hint: hint, limit: safeLimit))
        }
        return uniqueEntries(candidates)
    }

    func windowEntries(limit: Int, offset: Int) throws -> [FileEntry] {
        let safeLimit = max(1, min(limit, 5_000))
        let safeOffset = max(0, offset)
        let sql = """
            SELECT path, name, parent, kind, byte_size, created_at, modified_at,
                   accessed_at, indexed_at, run_count, last_run_at, attributes,
                   file_id, volume_id, file_list_name, file_list_path,
                   media_title, media_artist, media_album,
                   media_comment, media_genre, media_track, media_year
            FROM entries
            ORDER BY modified_at DESC, name ASC
            LIMIT \(safeLimit) OFFSET \(safeOffset);
            """

        return try query(sql) { statement in
            self.entry(from: statement)
        }
    }

    func entryCount() throws -> Int {
        try query("SELECT COUNT(*) FROM entries;") { statement in
            statement.optionalInt(at: 0) ?? 0
        }.first ?? 0
    }

    func deleteEntries(inSkippedDirectoryNames names: Set<String>) throws -> Int {
        let names = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        guard !names.isEmpty else {
            return 0
        }

        let namePlaceholders = placeholders(count: names.count)
        let descendantClauses = Array(repeating: "path LIKE ? ESCAPE '\\'", count: names.count)
            .joined(separator: " OR ")
        let condition = """
            ((kind IN (?, ?) AND name IN (\(namePlaceholders))) OR \(descendantClauses))
            """
        let bindings: [SQLiteValue] =
            [.text(FileKind.folder.rawValue), .text(FileKind.package.rawValue)] +
            names.map { .text($0) } +
            names.map { .text("%/\(escapeLike($0))/%") }

        var removedCount = 0
        try transaction {
            removedCount = try query(
                "SELECT COUNT(*) FROM entries WHERE \(condition);",
                bindings: bindings
            ) { statement in
                statement.optionalInt(at: 0) ?? 0
            }.first ?? 0

            guard removedCount > 0 else {
                return
            }

            try withStatement(
                "DELETE FROM entries_fts WHERE path IN (SELECT path FROM entries WHERE \(condition));"
            ) { statement in
                try statement.bind(bindings)
                try statement.stepDone()
            }
            try withStatement(
                "DELETE FROM entries_trigram WHERE path IN (SELECT path FROM entries WHERE \(condition));"
            ) { statement in
                try statement.bind(bindings)
                try statement.stepDone()
            }
            try withStatement("DELETE FROM entries WHERE \(condition);") { statement in
                try statement.bind(bindings)
                try statement.stepDone()
            }
        }
        return removedCount
    }

    private func ftsCandidateEntries(
        matchQuery: String,
        hint: SearchCandidateHint,
        limit: Int
    ) throws -> [FileEntry] {
        let filter = candidateFilter(for: hint, tablePrefix: "entries")
        let filterClause = filter.clause.map { " AND \($0)" } ?? ""
        let sql = """
            SELECT entries.path, entries.name, entries.parent, entries.kind, entries.byte_size,
                   entries.created_at, entries.modified_at, entries.accessed_at,
                   entries.indexed_at, entries.run_count, entries.last_run_at,
                   entries.attributes, entries.file_id, entries.volume_id,
                   entries.file_list_name, entries.file_list_path,
                   entries.media_title, entries.media_artist, entries.media_album,
                   entries.media_comment, entries.media_genre, entries.media_track,
                   entries.media_year
            FROM entries_fts
            JOIN entries ON entries.path = entries_fts.path
            WHERE entries_fts MATCH ?
            \(filterClause)
            LIMIT \(limit);
            """

        return try query(sql, bindings: [.text(matchQuery)] + filter.bindings) { statement in
            self.entry(from: statement)
        }
    }

    private func trigramCandidateEntries(
        matchQuery: String,
        hint: SearchCandidateHint,
        limit: Int
    ) throws -> [FileEntry] {
        let filter = candidateFilter(for: hint, tablePrefix: "entries")
        let filterClause = filter.clause.map { " AND \($0)" } ?? ""
        let sql = """
            SELECT entries.path, entries.name, entries.parent, entries.kind, entries.byte_size,
                   entries.created_at, entries.modified_at, entries.accessed_at,
                   entries.indexed_at, entries.run_count, entries.last_run_at,
                   entries.attributes, entries.file_id, entries.volume_id,
                   entries.file_list_name, entries.file_list_path,
                   entries.media_title, entries.media_artist, entries.media_album,
                   entries.media_comment, entries.media_genre, entries.media_track,
                   entries.media_year
            FROM entries_trigram
            JOIN entries ON entries.path = entries_trigram.path
            WHERE entries_trigram MATCH ?
            \(filterClause)
            ORDER BY entries.modified_at DESC, entries.name ASC
            LIMIT \(limit);
            """

        return try query(sql, bindings: [.text(matchQuery)] + filter.bindings) { statement in
            self.entry(from: statement)
        }
    }

    private func likeCandidateEntries(hint: SearchCandidateHint, limit: Int) throws -> [FileEntry] {
        guard !hint.terms.isEmpty else {
            return try likeCandidateEntries(hint: hint, columns: [], limit: limit)
        }

        var candidates = try likeCandidateEntries(hint: hint, columns: ["name"], limit: limit)
        if candidates.count >= min(limit, 1_000) {
            return uniqueEntries(candidates)
        }

        candidates.append(contentsOf: try likeCandidateEntries(hint: hint, columns: ["parent", "path"], limit: limit))
        return uniqueEntries(candidates)
    }

    private func likeCandidateEntries(
        hint: SearchCandidateHint,
        columns: [String],
        limit: Int
    ) throws -> [FileEntry] {
        var clauses = hint.terms.map { _ in
            let columnClauses = columns.map { "\($0) LIKE ? ESCAPE '\\'" }
            return "(\(columnClauses.joined(separator: " OR ")))"
        }
        let filter = candidateFilter(for: hint, tablePrefix: nil)
        if let filterClause = filter.clause {
            clauses.append(filterClause)
        }
        let sql = """
            SELECT path, name, parent, kind, byte_size, created_at, modified_at,
                   accessed_at, indexed_at, run_count, last_run_at, attributes,
                   file_id, volume_id, file_list_name, file_list_path,
                   media_title, media_artist, media_album,
                   media_comment, media_genre, media_track, media_year
            FROM entries
            WHERE \(clauses.joined(separator: " AND "))
            ORDER BY modified_at DESC, name ASC
            LIMIT \(limit);
            """
        let bindings = hint.terms.flatMap { term -> [SQLiteValue] in
            let like = "%\(escapeLike(term))%"
            return Array(repeating: .text(like), count: columns.count)
        } + filter.bindings

        return try query(sql, bindings: bindings) { statement in
            self.entry(from: statement)
        }
    }

    private func candidateFilter(for hint: SearchCandidateHint, tablePrefix: String?) -> SQLiteCandidateFilter {
        let prefix = tablePrefix.map { "\($0)." } ?? ""
        var clauses: [String] = []
        var bindings: [SQLiteValue] = []

        if !hint.extensions.isEmpty {
            let extensions = hint.extensions.sorted()
            clauses.append("\(prefix)extension_name IN (\(placeholders(count: extensions.count)))")
            bindings.append(contentsOf: extensions.map { .text($0) })
        }

        if !hint.kinds.isEmpty {
            let kinds = hint.kinds.map(\.rawValue).sorted()
            clauses.append("\(prefix)kind IN (\(placeholders(count: kinds.count)))")
            bindings.append(contentsOf: kinds.map { .text($0) })
        }

        if !hint.parentPaths.isEmpty {
            let parentPaths = hint.parentPaths.sorted()
            clauses.append("\(prefix)parent IN (\(placeholders(count: parentPaths.count)))")
            bindings.append(contentsOf: parentPaths.map { .text($0) })
        }

        if !hint.requiredAttributes.isEmpty {
            let rawValue = Int64(hint.requiredAttributes.rawValue)
            clauses.append("(\(prefix)attributes & ?) = ?")
            bindings.append(.int(rawValue))
            bindings.append(.int(rawValue))
        }

        if !hint.excludedAttributes.isEmpty {
            clauses.append("(\(prefix)attributes & ?) = 0")
            bindings.append(.int(Int64(hint.excludedAttributes.rawValue)))
        }

        for filter in hint.numericFilters {
            clauses.append("\(numericExpression(for: filter.field, prefix: prefix)) \(sqlOperator(for: filter.op)) ?")
            bindings.append(.int(filter.value))
        }

        if hint.requiresUnknownByteSize {
            clauses.append("\(prefix)byte_size IS NULL")
        }

        for filter in hint.dateFilters {
            clauses.append("\(prefix)\(column(for: filter.field)) \(sqlOperator(for: filter.op)) ?")
            bindings.append(.date(filter.value))
        }

        for field in hint.unknownDateFields.sorted(by: { $0.rawValue < $1.rawValue }) {
            clauses.append("\(prefix)\(column(for: field)) IS NULL")
        }

        for filter in hint.mediaTextFilters {
            let column = "\(prefix)\(column(for: filter.field))"
            if filter.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clauses.append("(\(column) IS NOT NULL AND \(column) != '')")
            } else {
                clauses.append("\(column) LIKE ? ESCAPE '\\'")
                bindings.append(.text("%\(escapeLike(filter.value))%"))
            }
        }

        if let filter = hint.fileReferenceFilter {
            if let fileID = filter.fileID, !fileID.isEmpty {
                clauses.append("LOWER(\(prefix)file_id) = ?")
                bindings.append(.text(fileID.lowercased()))
                if let volumeID = filter.volumeID, !volumeID.isEmpty {
                    clauses.append("LOWER(\(prefix)volume_id) = ?")
                    bindings.append(.text(volumeID.lowercased()))
                }
            } else {
                clauses.append("(\(prefix)file_id IS NOT NULL AND \(prefix)file_id != '')")
            }
        }

        if hint.requiresFileListSource {
            clauses.append("(\(prefix)file_list_name IS NOT NULL AND \(prefix)file_list_path IS NOT NULL)")
        }

        if hint.rootOnly {
            clauses.append("(\(prefix)parent = '' OR \(prefix)parent = '/' OR \(prefix)path = '/')")
        }

        return SQLiteCandidateFilter(clauses: clauses, bindings: bindings)
    }

    private func placeholders(count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }

    private func numericExpression(for field: SearchCandidateNumericField, prefix: String) -> String {
        switch field {
        case .byteSize:
            return "\(prefix)byte_size"
        case .runCount:
            return "\(prefix)run_count"
        case .mediaTrack:
            return "\(prefix)media_track"
        case .mediaYear:
            return "\(prefix)media_year"
        case .depth:
            return """
                (CASE
                    WHEN \(prefix)parent = '' OR \(prefix)parent = '/' THEN 0
                    WHEN substr(\(prefix)parent, 1, 1) = '/' THEN length(\(prefix)parent) - length(replace(\(prefix)parent, '/', ''))
                    ELSE length(\(prefix)parent) - length(replace(\(prefix)parent, '/', ''))
                        + CASE WHEN length(\(prefix)parent) > 0 THEN 1 ELSE 0 END
                END)
                """
        case .characterCount:
            return "\(prefix)name_character_count"
        case .nameLength:
            return "\(prefix)name_length"
        case .namePartLength:
            return "\(prefix)name_part_length"
        case .nameUTF8Length:
            return "\(prefix)name_utf8_length"
        case .pathLength:
            return "\(prefix)path_length"
        case .pathUTF8Length:
            return "\(prefix)path_utf8_length"
        case .pathPartLength:
            return "\(prefix)path_part_length"
        case .extensionLength:
            return "\(prefix)extension_length"
        }
    }

    private func column(for field: SearchCandidateMediaTextField) -> String {
        switch field {
        case .mediaTitle:
            return "media_title"
        case .mediaArtist:
            return "media_artist"
        case .mediaAlbum:
            return "media_album"
        case .mediaComment:
            return "media_comment"
        case .mediaGenre:
            return "media_genre"
        }
    }

    private func column(for field: SearchCandidateDateField) -> String {
        switch field {
        case .dateModified:
            return "modified_at"
        case .dateCreated:
            return "created_at"
        case .dateAccessed:
            return "accessed_at"
        case .dateIndexed:
            return "indexed_at"
        case .dateRun:
            return "last_run_at"
        }
    }

    private func sqlOperator(for op: SearchCandidateComparisonOperator) -> String {
        switch op {
        case .equal:
            return "="
        case .notEqual:
            return "!="
        case .lessThan:
            return "<"
        case .lessThanOrEqual:
            return "<="
        case .greaterThan:
            return ">"
        case .greaterThanOrEqual:
            return ">="
        }
    }

    func stringMetaValue(forKey key: String) throws -> String? {
        try query("SELECT value FROM meta WHERE key = ?;", bindings: [.text(key)]) { statement in
            statement.text(at: 0)
        }.first ?? nil
    }

    func dateMetaValue(forKey key: String) throws -> Date? {
        guard let value = try stringMetaValue(forKey: key), let seconds = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    private func insert(entries: [FileEntry]) throws {
        let entrySQL = """
            INSERT OR REPLACE INTO entries (
                path, name, parent, extension_name, name_length, name_part_length,
                name_character_count, path_length, path_part_length, extension_length,
                name_utf8_length, path_utf8_length, kind, byte_size, created_at, modified_at,
                accessed_at, indexed_at, run_count, last_run_at, attributes, file_id, volume_id,
                file_list_name, file_list_path, media_title, media_artist, media_album, media_comment,
                media_genre, media_track, media_year
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        let ftsSQL = "INSERT INTO entries_fts(path, name, parent) VALUES (?, ?, ?);"
        let trigramSQL = "INSERT INTO entries_trigram(path) VALUES (?);"

        try withStatement(entrySQL) { entryStatement in
            try withStatement(ftsSQL) { ftsStatement in
                try withStatement(trigramSQL) { trigramStatement in
                    for entry in entries {
                        let derived = derivedLengthValues(path: entry.path, name: entry.name, parent: entry.parent)
                        try entryStatement.reset()
                        try entryStatement.bind([
                            .text(entry.path),
                            .text(entry.name),
                            .text(entry.parent),
                            .text(derived.extensionName),
                            .int(Int64(derived.nameLength)),
                            .int(Int64(derived.namePartLength)),
                            .int(Int64(derived.nameCharacterCount)),
                            .int(Int64(derived.pathLength)),
                            .int(Int64(derived.pathPartLength)),
                            .int(Int64(derived.extensionLength)),
                            .int(Int64(derived.nameUTF8Length)),
                            .int(Int64(derived.pathUTF8Length)),
                            .text(entry.kind.rawValue),
                            .optionalInt64(entry.byteSize),
                            .optionalDate(entry.createdAt),
                            .optionalDate(entry.modifiedAt),
                            .optionalDate(entry.accessedAt),
                            .date(entry.indexedAt),
                            .int(Int64(entry.runCountValue)),
                            .optionalDate(entry.lastRunAt),
                            .int(Int64(entry.attributes.rawValue)),
                            .optionalText(entry.fileID),
                            .optionalText(entry.volumeID),
                            .optionalText(entry.fileListName),
                            .optionalText(entry.fileListPath),
                            .optionalText(entry.mediaTitle),
                            .optionalText(entry.mediaArtist),
                            .optionalText(entry.mediaAlbum),
                            .optionalText(entry.mediaComment),
                            .optionalText(entry.mediaGenre),
                            .optionalInt64(entry.mediaTrack.map(Int64.init)),
                            .optionalInt64(entry.mediaYear.map(Int64.init))
                        ])
                        try entryStatement.stepDone()

                        try ftsStatement.reset()
                        try ftsStatement.bind([
                            .text(entry.path),
                            .text(entry.name),
                            .text(entry.parent)
                        ])
                        try ftsStatement.stepDone()

                        try trigramStatement.reset()
                        try trigramStatement.bind([.text(entry.path)])
                        try trigramStatement.stepDone()
                    }
                }
            }
        }
    }

    private func delete(paths: [String], updateMeta: Bool) throws {
        if updateMeta {
            try setMetaValue(String(Date().timeIntervalSince1970), forKey: "updatedAt")
        }

        try withStatement("DELETE FROM entries WHERE path = ?;") { entryStatement in
            try withStatement("DELETE FROM entries_fts WHERE path = ?;") { ftsStatement in
                try withStatement("DELETE FROM entries_trigram WHERE path = ?;") { trigramStatement in
                    for path in paths {
                        try entryStatement.reset()
                        try entryStatement.bind([.text(path)])
                        try entryStatement.stepDone()

                        try ftsStatement.reset()
                        try ftsStatement.bind([.text(path)])
                        try ftsStatement.stepDone()

                        try trigramStatement.reset()
                        try trigramStatement.bind([.text(path)])
                        try trigramStatement.stepDone()
                    }
                }
            }
        }
    }

    private func setMetaValue(_ value: String, forKey key: String) throws {
        try withStatement("INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?);") { statement in
            try statement.bind([.text(key), .text(value)])
            try statement.stepDone()
        }
    }

    private func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private func ftsMatchQuery(for terms: [String]) -> String? {
        let tokens = terms.flatMap(ftsTokens)
        guard !tokens.isEmpty,
              tokens.allSatisfy({ $0.count >= 2 }) else {
            return nil
        }
        return tokens.map { "\($0)*" }.joined(separator: " AND ")
    }

    private func trigramMatchQuery(for terms: [String]) -> String? {
        let values = terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !values.isEmpty,
              values.allSatisfy({ $0.count >= 3 }) else {
            return nil
        }
        return values.map(ftsPhrase).joined(separator: " AND ")
    }

    private func needsSubstringFallback(for terms: [String]) -> Bool {
        terms.contains { term in
            term.unicodeScalars.contains { scalar in
                !CharacterSet.alphanumerics.contains(scalar)
            }
        }
    }

    private func ftsPhrase(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func ftsTokens(from value: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for scalar in value.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func uniqueEntries(_ entries: [FileEntry]) -> [FileEntry] {
        var seen = Set<String>()
        var unique: [FileEntry] = []
        unique.reserveCapacity(entries.count)

        for entry in entries where !seen.contains(entry.path) {
            seen.insert(entry.path)
            unique.append(entry)
        }

        return unique
    }

    private func entry(from statement: SQLiteStatement) -> FileEntry {
        let kind = FileKind(rawValue: statement.text(at: 3) ?? "") ?? .other
        let path = statement.text(at: 0) ?? ""
        let name = statement.text(at: 1) ?? ""
        let rawAttributes = statement.optionalInt(at: 11) ?? 0
        let attributes = rawAttributes == 0
            ? FileAttributes.inferred(kind: kind, name: name, path: path)
            : FileAttributes(rawValue: rawAttributes)
        return FileEntry(
            path: path,
            name: name,
            parent: statement.text(at: 2) ?? "",
            kind: kind,
            byteSize: statement.optionalInt64(at: 4),
            createdAt: statement.optionalDate(at: 5),
            modifiedAt: statement.optionalDate(at: 6),
            accessedAt: statement.optionalDate(at: 7),
            indexedAt: statement.optionalDate(at: 8) ?? Date(),
            runCount: statement.optionalInt(at: 9),
            lastRunAt: statement.optionalDate(at: 10),
            attributes: attributes,
            fileID: statement.text(at: 12),
            volumeID: statement.text(at: 13),
            fileListName: statement.text(at: 14),
            fileListPath: statement.text(at: 15),
            mediaTitle: statement.text(at: 16),
            mediaArtist: statement.text(at: 17),
            mediaAlbum: statement.text(at: 18),
            mediaComment: statement.text(at: 19),
            mediaGenre: statement.text(at: 20),
            mediaTrack: statement.optionalInt(at: 21),
            mediaYear: statement.optionalInt(at: 22)
        )
    }

    private func execute(_ sql: String) throws {
        guard let db else {
            throw IndexStorageError.sqlite("Database is closed")
        }

        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw IndexStorageError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func withStatement(_ sql: String, body: (SQLiteStatement) throws -> Void) throws {
        guard let db else {
            throw IndexStorageError.sqlite("Database is closed")
        }

        var rawStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &rawStatement, nil) != SQLITE_OK {
            throw IndexStorageError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer {
            sqlite3_finalize(rawStatement)
        }

        try body(SQLiteStatement(db: db, statement: rawStatement))
    }

    private func query<Value>(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        map: (SQLiteStatement) throws -> Value
    ) throws -> [Value] {
        var values: [Value] = []
        try withStatement(sql) { statement in
            try statement.bind(bindings)
            while true {
                let result = sqlite3_step(statement.statement)
                if result == SQLITE_ROW {
                    values.append(try map(statement))
                } else if result == SQLITE_DONE {
                    break
                } else {
                    throw IndexStorageError.sqlite(String(cString: sqlite3_errmsg(statement.db)))
                }
            }
        }
        return values
    }
}

private struct SQLiteCandidateFilter {
    let clauses: [String]
    let bindings: [SQLiteValue]

    var clause: String? {
        clauses.isEmpty ? nil : clauses.joined(separator: " AND ")
    }
}

private struct SQLiteStatement {
    let db: OpaquePointer
    let statement: OpaquePointer?

    func bind(_ values: [SQLiteValue]) throws {
        for (index, value) in values.enumerated() {
            try value.bind(to: statement, index: Int32(index + 1), db: db)
        }
    }

    func reset() throws {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }

    func stepDone() throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw IndexStorageError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    func text(at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: text)
    }

    func optionalInt64(at index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    func optionalInt(at index: Int32) -> Int? {
        optionalInt64(at: index).map(Int.init)
    }

    func optionalDate(at index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }
}

private enum SQLiteValue {
    case text(String)
    case optionalText(String?)
    case int(Int64)
    case date(Date)
    case optionalInt64(Int64?)
    case optionalDate(Date?)

    func bind(to statement: OpaquePointer?, index: Int32, db: OpaquePointer) throws {
        let result: Int32
        switch self {
        case let .text(value):
            result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        case let .optionalText(value):
            if let value {
                result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
            } else {
                result = sqlite3_bind_null(statement, index)
            }
        case let .int(value):
            result = sqlite3_bind_int64(statement, index, value)
        case let .date(value):
            result = sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
        case let .optionalInt64(value):
            if let value {
                result = sqlite3_bind_int64(statement, index, value)
            } else {
                result = sqlite3_bind_null(statement, index)
            }
        case let .optionalDate(value):
            if let value {
                result = sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
            } else {
                result = sqlite3_bind_null(statement, index)
            }
        }

        guard result == SQLITE_OK else {
            throw IndexStorageError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
