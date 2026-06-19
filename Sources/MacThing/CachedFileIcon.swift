import AppKit
import SwiftUI

struct CachedFileIcon: View {
    let path: String
    var iconSize: CGFloat = 22
    var frameWidth: CGFloat = 30
    var frameHeight: CGFloat = 24
    var alignment: Alignment = .leading

    var body: some View {
        Image(nsImage: FileIconCache.icon(forFile: path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .frame(width: frameWidth, height: frameHeight, alignment: alignment)
    }
}

@MainActor
private enum FileIconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 4_096
        return cache
    }()

    static func icon(forFile path: String) -> NSImage {
        let key = path as NSString
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
