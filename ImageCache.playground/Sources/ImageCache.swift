import Foundation
import UIKit.UIImage
import Combine

// Declares in-memory image cache
public protocol ImageCacheType: class {
    // Returns the image associated with a given url
    func image(for url: URL) -> UIImage?
    // Inserts the image of the specified url in the cache
    func insertImage(_ image: UIImage?, for url: URL)
    // Removes the image of the specified url in the cache
    func removeImage(for url: URL)
    // Removes all images from the cache
    func removeAllImages()
    // Accesses the value associated with the given key for reading and writing
    subscript(_ url: URL) -> UIImage? { get set }
}

public final class ImageCache: ImageCacheType {

    // 1st level cache
    private lazy var imageCache: NSCache<AnyObject, AnyObject> = {
        let cache = NSCache<AnyObject, AnyObject>()
        cache.countLimit = countLimit
        return cache
    }()
    // 2nd level cache with decompressed images
    private lazy var decompressedImageCache: NSCache<AnyObject, AnyObject> = {
        let cache = NSCache<AnyObject, AnyObject>()
        cache.totalCostLimit = memoryLimit
        return cache
    }()
    private let lock = NSLock()
    private let countLimit: Int
    private let memoryLimit: Int

    public enum Constants {
        public static let defaultCountLimit = 100
        public static let defaultMemoryLimit = 1024 * 1024 * 100 // 100 MB
    }

    public init(countLimit: Int = Constants.defaultCountLimit,
                memoryLimit: Int = Constants.defaultMemoryLimit) {
        self.countLimit = countLimit
        self.memoryLimit = memoryLimit
    }

    public func image(for url: URL) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        // the best case scenario -> there is a decompressed image in memory
        if let decompressedImage = decompressedImageCache.object(forKey: url as AnyObject) as? UIImage {
            return decompressedImage
        }
        // search for raw image data
        if let image = imageCache.object(forKey: url as AnyObject) as? UIImage {
            let decompressedImage = image.decodedImage()
            decompressedImageCache.setObject(image as AnyObject, forKey: url as AnyObject, cost: decompressedImage.diskSize)
            return decompressedImage
        }
        return nil
    }

    public func insertImage(_ image: UIImage?, for url: URL) {
        lock.lock(); defer { lock.unlock() }
        guard let image = image else { return removeImage(for: url) }

        let decompressedImage = image.decodedImage()
        imageCache.setObject(decompressedImage, forKey: url as AnyObject, cost: 1)
        decompressedImageCache.setObject(image as AnyObject, forKey: url as AnyObject, cost: decompressedImage.diskSize)
    }

    public func removeImage(for url: URL) {
        lock.lock(); defer { lock.unlock() }
        imageCache.removeObject(forKey: url as AnyObject)
        decompressedImageCache.removeObject(forKey: url as AnyObject)
    }

    public func removeAllImages() {
        lock.lock(); defer { lock.unlock() }
        imageCache.removeAllObjects()
        decompressedImageCache.removeAllObjects()
    }

    public subscript(_ key: URL) -> UIImage? {
        get {
            return image(for: key)
        }
        set {
            return insertImage(newValue, for: key)
        }
    }
}

fileprivate extension UIImage {

    func decodedImage() -> UIImage {
        guard let cgImage = cgImage else { return self }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: cgImage.bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        guard let decodedImage = context?.makeImage() else { return self }
        return UIImage(cgImage: decodedImage)
    }

    // Rough estimation of how much memory image uses in bytes
    var diskSize: Int {
        guard let cgImage = cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
