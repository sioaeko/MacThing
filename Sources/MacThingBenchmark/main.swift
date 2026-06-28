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

func measure(_ label: String, iterations: Int = 1, _ block: () -> Void) {
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        block()
    }
    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
    let perIteration = elapsed / Double(iterations)
    print(String(format: "  %-45s %8.2f ms (×%d = %.2f ms total)", (label as NSString).utf8String!, perIteration, iterations, elapsed))
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

// --- FileIndex rebuild ---
print("\n--- FileIndex Build ---")
measure("FileIndex init (100k)", iterations: 3) {
    _ = FileIndex(entries: entries100k)
}

print("\n=== Benchmark Complete ===")
