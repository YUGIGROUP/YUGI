import UIKit

/// Utility for compressing and resizing images before uploading
struct ImageCompressor {
    /// Maximum dimensions for profile images
    static let maxProfileImageSize: CGFloat = 800
    
    /// Compression quality for JPEG (0.0 = smallest, 1.0 = highest)
    static let compressionQuality: CGFloat = 0.6
    
    /// Resize and compress an image for profile use
    /// - Parameter image: The original image
    /// - Returns: Compressed base64 string, or nil if compression fails
    static func compressProfileImage(_ image: UIImage) -> String? {
        // Resize image to max dimensions while maintaining aspect ratio
        let resizedImage = resizeImage(image, maxDimension: maxProfileImageSize)
        
        // Compress to JPEG with quality setting
        guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            print("❌ ImageCompressor: Failed to convert image to JPEG data")
            return nil
        }
        
        // Convert to base64
        let base64String = imageData.base64EncodedString()
        
        let sizeInKB = Double(base64String.count) / 1024.0
        print("✅ ImageCompressor: Image compressed to \(String(format: "%.1f", sizeInKB)) KB (base64: \(base64String.count) chars)")
        
        return base64String
    }
    
    /// Resize image to maximum dimension while maintaining aspect ratio
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // If image is already smaller, return as-is
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Create graphics context and resize
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("⚠️ ImageCompressor: Failed to resize image, returning original")
            return image
        }
        
        return resizedImage
    }
}
