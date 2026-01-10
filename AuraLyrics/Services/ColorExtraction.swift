import AppKit

extension NSImage {
    /// Resizes the image to a small size to performance-efficiently extract colors.
    func resized(to size: NSSize) -> NSImage? {
        let img = NSImage(size: size)
        img.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        img.unlockFocus()
        return img
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
