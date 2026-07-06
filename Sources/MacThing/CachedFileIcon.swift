import AppKit
import SwiftUI

struct CachedFileIcon: View {
    let path: String
    var iconSize: CGFloat = 22
    var frameWidth: CGFloat = 30
    var frameHeight: CGFloat = 24
    var alignment: Alignment = .leading

    // Seed synchronously from the cache so already-resolved icons render on the
    // first frame with no flicker. Only cache misses fall back to async loading.
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
            } else {
                // Lightweight placeholder while the real icon resolves off-thread.
                // Sized to match so the row layout never shifts when it arrives.
                Color.clear
                    .frame(width: iconSize, height: iconSize)
            }
        }
        .frame(width: frameWidth, height: frameHeight, alignment: alignment)
        .task(id: path) {
            // Cache hit: resolve immediately on the main actor, no background hop.
            if let cached = FileIconCache.cachedIcon(forFile: path) {
                image = cached
                return
            }
            image = nil
            let resolved = await FileIconCache.icon(forFile: path)
            // `.task(id:)` is cancelled and restarted when `path` changes, so the
            // result is guaranteed to match the current path.
            if !Task.isCancelled {
                image = resolved
            }
        }
    }
}

/// Wraps a non-Sendable `NSImage` so it can cross the background→main-actor
/// boundary. The image is produced and consumed once and never mutated, so the
/// transfer is safe.
private struct IconBox: @unchecked Sendable {
    let image: NSImage
}

@MainActor
private enum FileIconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 4_096
        return cache
    }()

    /// Synchronous cache lookup for the fast path (already-resolved icons).
    static func cachedIcon(forFile path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    /// Resolves the icon, loading off the main thread on a cache miss so the
    /// `NSWorkspace` file I/O never blocks scrolling.
    static func icon(forFile path: String) async -> NSImage {
        let key = path as NSString
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let box = await withCheckedContinuation { (continuation: CheckedContinuation<IconBox, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: path)
                continuation.resume(returning: IconBox(image: icon))
            }
        }

        cache.setObject(box.image, forKey: key)
        return box.image
    }
}
