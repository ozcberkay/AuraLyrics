import AppKit

extension NSImage {
    /// Resizes the image to a small size to performance-efficiently extract colors.
    func resized(to targetSize: NSSize) -> NSImage? {
        // UIPX-04: CGContext replaces deprecated lockFocus/unlockFocus (deprecated macOS 10.14)
        // CGContext is thread-safe and Retina-correct; lockFocus requires main thread and AppKit context
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bitsPerComponent = 8
        let bytesPerRow = 4 * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let resizedCGImage = context.makeImage() else { return nil }
        return NSImage(cgImage: resizedCGImage, size: targetSize)
    }
    
    /// Returns the average color of the image.
    var averageColor: NSColor? {
        // Resinzing to 1x1 pixel is a hacky but very fast way to get average color
        guard let inputImage = self.resized(to: NSSize(width: 1, height: 1)) else { return nil }
        guard let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var rawData = [UInt8](repeating: 0, count: Int(bytesPerRow * height))
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let red = CGFloat(rawData[0]) / 255.0
        let green = CGFloat(rawData[1]) / 255.0
        let blue = CGFloat(rawData[2]) / 255.0
        let alpha = CGFloat(rawData[3]) / 255.0
        
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
