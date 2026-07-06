import Foundation
import MacThingCore

// Generate synthetic entries for benchmarking
func generateEntries(count: Int) -> [FileEntry] {
    let extensions = ["swift", "txt", "pdf", "png", "jpg", "mp3", "html", "css", "js", "json"]
    let folders = [
        "/Users/test/Documents",
        "/Users/test/Desktop",
        "/Users/test/Downloads",
        "/Users/test/Projects/app/Sources",
        "/Users/test/Projects/app/Tests",
        "/Users/test/Library/Caches",
        "/Applications/Xcode.app/Contents/Resources",
        "/usr/local/lib",
        "/System/Library/Frameworks",
        "/var/folders/temp"
    ]

    return (0..<count).map { i in
        let folder = folders[i % folders.count]
        let ext = extensions[i % extensions.count]
        let name = "file_\(i)_benchmark.\(ext)"
        let path = "\(folder)/\(name)"
        return FileEntry(
            path: path,
            name: name,
            parent: folder,
            kind: .file,
            byteSize: Int64(i * 1024),
            createdAt: Date().addingTimeInterval(-Double(i * 60)),
            modifiedAt: Date().addingTimeInterval(-Double(i * 30)),
            accessedAt: Date(),
            indexedAt: Date()
        )
    }
}

// Realistic directory tree: many distinct nested folders with moderate fanout,
// so path/ancestor-sensitive measurements are not skewed by the handful of
// folders in `generateEntries` (where parent-keyed caching would trivially hit).
func generateRealisticEntries(count: Int) -> [FileEntry] {
    let extensions = ["swift", "txt", "pdf", "png", "jpg", "mp3", "html", "css", "js", "json"]
    let topLevels = ["Users/alice/Projects", "Users/alice/Documents", "Library/Caches",
                     "System/Library/Frameworks", "opt/homebrew/lib"]
    var result: [FileEntry] = []
    result.reserveCapacity(count)
    var i = 0
    var bucket = 0
    // Build folders of ~12 files each across a 3-4 level deep tree.
    while i < count {
        let top = topLevels[bucket % topLevels.count]
        let mid = "module_\(bucket % 200)"
        let leaf = "sub_\((bucket / 200) % 40)"
        let parent = "/\(top)/\(mid)/\(leaf)"
        let filesInFolder = 12
        for f in 0..<filesInFolder where i < count {
            let ext = extensions[i % extensions.count]
            let name = "file_\(i)_benchmark.\(ext)"
            result.append(FileEntry(
                path: "\(parent)/\(name)",
                name: name,
                parent: parent,
                kind: .file,
                byteSize: Int64(i * 1024),
                createdAt: Date().addingTimeInterval(-Double(i * 60)),
                modifiedAt: Date().addingTimeInterval(-Double(i * 30)),
                accessedAt: Date(),
                indexedAt: Date()
            ))
            i += 1
            _ = f
        }
        bucket += 1
    }
    return result
}

func measure(_ label: String, iterations: Int = 1, _ block: () -> Void) {
    // Report the best (minimum) per-iteration time: the fastest run has the
    // least interference from system load, so it's the most stable signal for
    // detecting real regressions across runs. Also report the mean for context.
    var best = Double.greatestFiniteMagnitude
    var total = 0.0
    for _ in 0..<iterations {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        best = min(best, elapsed)
        total += elapsed
    }
    let mean = total / Double(iterations)
    print(String(format: "  %-45s %8.2f ms best (mean %.2f, ×%d)", (label as NSString).utf8String!, best, mean, iterations))
}

print("=== FocusThings Performance Benchmark ===\n")

// --- FileEntry property benchmarks ---
print("--- FileEntry Properties (100k entries) ---")
let entries100k = generateEntries(count: 100_000)

measure("extensionName (100k)", iterations: 3) {
    for entry in entries100k {
        _ = entry.extensionName
    }
}

measure("namePart (100k)", iterations: 3) {
    for entry in entries100k {
        _ = entry.namePart
    }
}

measure("depth (100k)", iterations: 3) {
    for entry in entries100k {
        _ = entry.depth
    }
}

// --- Search Engine benchmarks ---
print("\n--- Search Engine (varying sizes) ---")

for size in [10_000, 50_000, 100_000] {
    let entries = size == 100_000 ? entries100k : generateEntries(count: size)
    let sizeLabel = "\(size / 1000)k"

    measure("Simple text search (\(sizeLabel))", iterations: 3) {
        let request = SearchRequest(query: "benchmark", sortField: .name, sortDirection: .ascending, options: SearchOptions())
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }

    measure("Fuzzy search (\(sizeLabel))", iterations: 3) {
        var options = SearchOptions()
        options.fuzzyMatching = true
        let request = SearchRequest(query: "bnchm", sortField: .name, sortDirection: .ascending, options: options)
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }

    measure("Path match search (\(sizeLabel))", iterations: 3) {
        var options = SearchOptions()
        options.matchPath = true
        let request = SearchRequest(query: "Projects", sortField: .name, sortDirection: .ascending, options: options)
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }

    measure("Extension filter search (\(sizeLabel))", iterations: 3) {
        let request = SearchRequest(query: "ext:swift", sortField: .name, sortDirection: .ascending, options: SearchOptions())
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }

    measure("MIME filter search (\(sizeLabel))", iterations: 3) {
        let request = SearchRequest(query: "mime:image/*", sortField: .name, sortDirection: .ascending, options: SearchOptions())
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }

    measure("Regex search (\(sizeLabel))", iterations: 3) {
        var options = SearchOptions()
        options.regexMatching = true
        let request = SearchRequest(query: "file_[0-9]+_bench", sortField: .name, sortDirection: .ascending, options: options)
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }

    measure("Multi-term search (\(sizeLabel))", iterations: 3) {
        let request = SearchRequest(query: "file swift", sortField: .name, sortDirection: .ascending, options: SearchOptions())
        _ = SearchEngine.search(request: request, in: entries, shouldCancel: { false })
    }
}

// --- Context building benchmark ---
print("\n--- SearchContext Build (100k) ---")
measure("Context build (100k)", iterations: 3) {
    let request = SearchRequest(query: "test", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

// Queries below actually trigger the full SearchContext (all index dictionaries).
measure("Full-context: dupe (100k)", iterations: 3) {
    let request = SearchRequest(query: "dupe:", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("Full-context: childcount (100k)", iterations: 3) {
    let request = SearchRequest(query: "childcount:>0", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("Full-context: empty folders (100k)", iterations: 3) {
    let request = SearchRequest(query: "empty:", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("parent-name match (100k)", iterations: 3) {
    let request = SearchRequest(query: "parent-name:Sources", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("ancestor match (100k)", iterations: 3) {
    let request = SearchRequest(query: "ancestor:Projects", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("descendant match (100k)", iterations: 3) {
    let request = SearchRequest(query: "descendant:benchmark", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("formula contains (100k)", iterations: 3) {
    // Exercises FormulaExpression.matches: normalizes both operands per entry.
    let request = SearchRequest(query: "contains($name:,benchmark)", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("formula comparison (100k)", iterations: 3) {
    let request = SearchRequest(query: "$name:>=$stem:", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

measure("descendantcount match (100k)", iterations: 3) {
    let request = SearchRequest(query: "descendantcount:>5", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: entries100k, shouldCancel: { false })
}

// --- Realistic directory tree (thousands of distinct folders) ---
// path/ancestor-sensitive measurements on a tree that does NOT collapse to a
// handful of parents, so parent-keyed caching can't trivially over-hit.
print("\n--- Realistic Tree (100k, deep folders) ---")
let realistic100k = generateRealisticEntries(count: 100_000)

measure("Path match (realistic 100k)", iterations: 3) {
    var options = SearchOptions()
    options.matchPath = true
    let request = SearchRequest(query: "module_42", sortField: .name, sortDirection: .ascending, options: options)
    _ = SearchEngine.search(request: request, in: realistic100k, shouldCancel: { false })
}

measure("ancestor match (realistic 100k)", iterations: 3) {
    let request = SearchRequest(query: "ancestor:Projects", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: realistic100k, shouldCancel: { false })
}

measure("parent-name match (realistic 100k)", iterations: 3) {
    let request = SearchRequest(query: "parent-name:sub_3", sortField: .name, sortDirection: .ascending, options: SearchOptions())
    _ = SearchEngine.search(request: request, in: realistic100k, shouldCancel: { false })
}

// --- FileIndex rebuild ---
print("\n--- FileIndex Build ---")
measure("FileIndex init (100k)", iterations: 3) {
    _ = FileIndex(entries: entries100k)
}

// --- SQLite index read path (exercises the real persisted index) ---
print("\n--- SQLite Index (100k persisted) ---")
do {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macthing-bench-\(ProcessInfo.processInfo.globallyUniqueString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let dbURL = tempDir.appendingPathComponent("index.sqlite")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    measure("Persist 100k entries (upsert)", iterations: 1) {
        try? IndexStorage.upsert(entries: entries100k, rootPath: "/Users/test", to: dbURL)
    }

    // Full-rebuild path (initial scan): save → replace → bulk INSERT...SELECT
    // FTS/trigram build. Fresh DB so the FTS tables start empty.
    let replaceURL = tempDir.appendingPathComponent("replace.sqlite")
    measure("Persist 100k entries (save/replace)", iterations: 1) {
        try? IndexStorage.save(IndexSnapshot(rootPath: "/Users/test", entries: entries100k), to: replaceURL)
    }

    measure("Candidate query: term (100k)", iterations: 5) {
        let hint = SearchEngine.candidateHint(for: SearchRequest(query: "benchmark"))
        _ = try? IndexStorage.candidateEntries(hint: hint, limit: 500, from: dbURL)
    }

    measure("Candidate query: term+ext (100k)", iterations: 5) {
        let hint = SearchEngine.candidateHint(for: SearchRequest(query: "file ext:swift"))
        _ = try? IndexStorage.candidateEntries(hint: hint, limit: 500, from: dbURL)
    }

    measure("Window query: browse (100k)", iterations: 5) {
        _ = try? IndexStorage.windowEntries(limit: 500, offset: 0, from: dbURL)
    }
} catch {
    print("  (skipped: \(error))")
}

print("\n=== Benchmark Complete ===")
