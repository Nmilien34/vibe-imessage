import UIKit

extension UIImage {
    /// Downscales the image so the longest side is at most `maxDimension` points.
    /// Returns `self` unchanged if already small enough.
    func preparingForUpload(maxDimension: CGFloat = 1920) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
