import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeDetailLevel: Int, CaseIterable {
    case simple
    case balanced
    case detailed
    case maximum

    var correctionLevel: String {
        switch self {
        case .simple:
            return "L"
        case .balanced:
            return "M"
        case .detailed:
            return "Q"
        case .maximum:
            return "H"
        }
    }

    var title: String {
        switch self {
        case .simple:
            return "Simpler"
        case .balanced:
            return "Balanced"
        case .detailed:
            return "Detailed"
        case .maximum:
            return "Maximum Detail"
        }
    }

    var description: String {
        switch self {
        case .simple:
            return "Fewer extra blocks, cleaner look."
        case .balanced:
            return "A good default for most links."
        case .detailed:
            return "Adds more redundancy and density."
        case .maximum:
            return "Most robust, with the densest pattern."
        }
    }
}

enum QRCodeRenderer {
    private static let context = CIContext()

    static func image(for value: String, detailLevel: QRCodeDetailLevel = .balanced, targetSize: CGFloat = 320) -> NSImage? {
        guard let cgImage = cgImage(for: value, detailLevel: detailLevel, targetSize: targetSize) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
    }

    static func pngData(for value: String, detailLevel: QRCodeDetailLevel = .balanced, targetSize: CGFloat = 1024) -> Data? {
        guard let cgImage = cgImage(for: value, detailLevel: detailLevel, targetSize: targetSize) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    private static func cgImage(for value: String, detailLevel: QRCodeDetailLevel, targetSize: CGFloat) -> CGImage? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, let data = trimmedValue.data(using: .utf8) else {
            return nil
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = detailLevel.correctionLevel

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scale = max(1, floor(targetSize / outputImage.extent.width))
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = scaledImage.extent.integral

        return context.createCGImage(scaledImage, from: extent)
    }
}
