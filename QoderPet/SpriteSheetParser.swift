import AppKit
import CoreGraphics

class SpriteSheetParser {
    let image: NSImage
    let columns: Int
    let rows: Int
    let frameSize: CGSize

    init?(imageName: String, columns: Int, rows: Int) {
        guard let img = NSImage(named: imageName) else {
            print("[SpriteSheet] 找不到图片: \(imageName)")
            return nil
        }
        self.image = img
        self.columns = columns
        self.rows = rows

        let imgSize = img.size
        self.frameSize = CGSize(
            width: imgSize.width / CGFloat(columns),
            height: imgSize.height / CGFloat(rows)
        )
    }

    /// 提取某行的所有帧
    func frames(row: Int, count: Int) -> [NSImage] {
        var result: [NSImage] = []
        for col in 0..<count {
            if let frame = extractFrame(row: row, column: col) {
                result.append(frame)
            }
        }
        return result
    }

    private func extractFrame(row: Int, column: Int) -> NSImage? {
        guard row >= 0, row < rows, column >= 0, column < columns else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height

        // CGImage 坐标原点在左上角，row 0 就是 y=0，不需要翻转
        let cropRect = CGRect(
            x: CGFloat(column) * frameSize.width * scaleX,
            y: CGFloat(row) * frameSize.height * scaleY,
            width: frameSize.width * scaleX,
            height: frameSize.height * scaleY
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        // Draw each crop into a fresh transparent bitmap. This prevents stale pixels
        // from a previous transparent frame surviving in the window backing store.
        let frameImg = NSImage(size: frameSize, flipped: false) { destination in
            NSColor.clear.setFill()
            destination.fill(using: .copy)
            NSGraphicsContext.current?.imageInterpolation = .high
            NSImage(cgImage: cropped, size: self.frameSize).draw(
                in: destination,
                from: .zero,
                operation: .copy,
                fraction: 1
            )
            return true
        }
        return frameImg
    }
}
