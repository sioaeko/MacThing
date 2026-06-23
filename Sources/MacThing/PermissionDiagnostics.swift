import AppKit
import Foundation

struct PermissionIssue: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
}

enum PermissionDiagnostics {
    static func indexingIssues(rootPath: String, profileRootPaths: [String]) -> [PermissionIssue] {
        var issues = rootAccessIssues(rootPath: rootPath, profileRootPaths: profileRootPaths)
        issues.append(contentsOf: fullDiskAccessIssues())
        return unique(issues)
    }

    static func fullDiskAccessIssues() -> [PermissionIssue] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let protectedLocations = [
            ("Mail", home.appending(path: "Library/Mail").path),
            ("Messages", home.appending(path: "Library/Messages").path),
            ("Safari", home.appending(path: "Library/Safari").path)
        ]

        let unreadableNames = protectedLocations.compactMap { name, path in
            FileManager.default.fileExists(atPath: path) &&
                !FileManager.default.isReadableFile(atPath: path)
                ? name
                : nil
        }

        guard !unreadableNames.isEmpty else {
            return []
        }

        return [
            PermissionIssue(
                id: "full-disk-access",
                title: "Full Disk Access",
                detail: "Protected locations not readable: \(unreadableNames.joined(separator: ", ")). Grant Full Disk Access for complete indexing."
            )
        ]
    }

    static func openFullDiskAccessSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate), NSWorkspace.shared.open(url) else {
                continue
            }
            return
        }
    }

    private static func rootAccessIssues(rootPath: String, profileRootPaths: [String]) -> [PermissionIssue] {
        let roots = uniqueRootPaths([rootPath] + profileRootPaths)
        return roots.compactMap(rootAccessIssue)
    }

    private static func rootAccessIssue(for path: String) -> PermissionIssue? {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let name = displayName(for: path)

        guard exists else {
            return PermissionIssue(
                id: "root-missing-\(stableID(for: path))",
                title: "Index Root Missing",
                detail: "\(name) is not available. Reconnect the drive or choose another root."
            )
        }

        guard isDirectory.boolValue else {
            return PermissionIssue(
                id: "root-not-folder-\(stableID(for: path))",
                title: "Index Root Is Not a Folder",
                detail: "\(name) is not a folder. Choose a folder or volume root."
            )
        }

        guard FileManager.default.isReadableFile(atPath: path) else {
            return PermissionIssue(
                id: "root-unreadable-\(stableID(for: path))",
                title: "Index Root Not Readable",
                detail: "\(name) cannot be read. Check permissions or grant Full Disk Access."
            )
        }

        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: path)
        } catch {
            return PermissionIssue(
                id: "root-list-failed-\(stableID(for: path))",
                title: "Index Root Cannot Be Listed",
                detail: "\(name) exists, but macOS refused directory listing: \(error.localizedDescription)"
            )
        }

        return nil
    }

    private static func uniqueRootPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var uniquePaths: [String] = []

        for path in paths {
            let normalized = URL(fileURLWithPath: path)
                .standardizedFileURL
                .path
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            uniquePaths.append(normalized)
        }

        return uniquePaths
    }

    private static func unique(_ issues: [PermissionIssue]) -> [PermissionIssue] {
        var seen = Set<String>()
        var uniqueIssues: [PermissionIssue] = []

        for issue in issues where !seen.contains(issue.id) {
            seen.insert(issue.id)
            uniqueIssues.append(issue)
        }

        return uniqueIssues
    }

    private static func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let lastPathComponent = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return lastPathComponent.isEmpty ? path : lastPathComponent
    }

    private static func stableID(for path: String) -> String {
        path.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                ? String(scalar).lowercased()
                : "-"
        }.joined()
    }
}
