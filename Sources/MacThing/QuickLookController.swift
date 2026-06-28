import AppKit
@preconcurrency import Quartz

@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private var previewPaths: [String] = []

    func preview(paths: [String]) {
        guard !paths.isEmpty else {
            return
        }
        previewPaths = paths

        if let panel = QLPreviewPanel.shared() {
            if panel.isVisible {
                panel.reloadData()
            } else {
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }

    func toggle(paths: [String]) {
        guard !paths.isEmpty else {
            return
        }
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        } else {
            preview(paths: paths)
        }
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            previewPaths.count
        }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated {
            guard index < previewPaths.count else {
                return nil
            }
            return URL(fileURLWithPath: previewPaths[index]) as NSURL
        }
    }

    // MARK: - QLPreviewPanelDelegate

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        false
    }
}
