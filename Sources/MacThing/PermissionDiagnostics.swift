import AppKit
import Foundation

struct PermissionIssue: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
}

enum PermissionDiagnostics {
    static func fullDiskAccessIssues() -> [PermissionIssue] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let protectedPaths = [
            home.appending(path: "Library/Mail").path,
            home.appending(path: "Library/Messages").path,
            home.appending(path: "Library/Safari").path
        ]

        let unreadablePaths = protectedPaths.filter { path in
            FileManager.default.fileExists(atPath: path) &&
                !FileManager.default.isReadableFile(atPath: path)
        }

        guard !unreadablePaths.isEmpty else {
            return []
        }

        return [
            PermissionIssue(
                id: "full-disk-access",
                title: "Full Disk Access",
                detail: "Some protected locations are not readable. Grant Full Disk Access for complete indexing."
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
}
