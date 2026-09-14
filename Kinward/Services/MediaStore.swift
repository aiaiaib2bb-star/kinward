import Foundation
import UIKit

/// Everything the user preserves lives in the app's own container, not the photo library.
/// Files are referenced by name so the model layer never carries bytes.
enum MediaStore {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kinward", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Keep it out of iCloud backups only for scratch; the archive itself should be backed up.
        return base
    }()

    static func url(for ref: String) -> URL { root.appendingPathComponent(ref) }

    @discardableResult
    static func saveImage(_ image: UIImage, quality: CGFloat = 0.86) -> String? {
        let sized = downscale(image, maxDimension: 2000)
        guard let data = sized.jpegData(compressionQuality: quality) else { return nil }
        let ref = "img_\(UUID().uuidString).jpg"
        do { try data.write(to: url(for: ref), options: .atomic); return ref }
        catch { return nil }
    }

    static func saveData(_ data: Data, ext: String) -> String? {
        let ref = "file_\(UUID().uuidString).\(ext)"
        do { try data.write(to: url(for: ref), options: .atomic); return ref }
        catch { return nil }
    }

    static func newAudioRef() -> String { "voice_\(UUID().uuidString).m4a" }

    static func image(_ ref: String?) -> UIImage? {
        guard let ref, !ref.isEmpty else { return nil }
        if let bundled = UIImage(named: ref) { return bundled }
        return UIImage(contentsOfFile: url(for: ref).path)
    }

    static func delete(_ ref: String?) {
        guard let ref, !ref.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: ref))
    }

    static func exists(_ ref: String?) -> Bool {
        guard let ref, !ref.isEmpty else { return false }
        if UIImage(named: ref) != nil { return true }
        return FileManager.default.fileExists(atPath: url(for: ref).path)
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let m = max(image.size.width, image.size.height)
        guard m > maxDimension else { return image }
        let scale = maxDimension / m
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
