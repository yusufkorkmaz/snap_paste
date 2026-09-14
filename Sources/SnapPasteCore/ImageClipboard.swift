import AppKit

public enum ClipboardError: Error, Equatable {
    case notPNG(URL)
    case writeFailed
}

/// Puts a PNG screenshot on the pasteboard so ⌘V pastes it in any app.
/// The PNG bytes are handed over untouched (no decode / re-encode). TIFF, which some
/// older apps require, is only rendered if a paste actually asks for it.
public final class ImageClipboard {
    static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    public let pasteboard: NSPasteboard
    private var tiffProvider: TIFFProvider?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func writePNG(at url: URL) throws {
        // Memory-mapped: the lazily-needed bytes stay as clean, reclaimable pages.
        let png = try Data(contentsOf: url, options: .mappedIfSafe)
        guard png.starts(with: Self.pngSignature) else { throw ClipboardError.notPNG(url) }

        let provider = TIFFProvider(png: png)
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setDataProvider(provider, forTypes: [.tiff])

        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw ClipboardError.writeFailed }
        tiffProvider = provider
    }
}

private final class TIFFProvider: NSObject, NSPasteboardItemDataProvider {
    let png: Data

    init(png: Data) {
        self.png = png
    }

    func pasteboard(_: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard type == .tiff, let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation else { return }
        item.setData(tiff, forType: .tiff)
    }
}
