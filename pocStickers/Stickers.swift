import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import Vision

enum StickerError: Error {
    case unreadableImage
    case renderFailed
}

struct SubjectMask {
    let image: CIImage
    let foundSubject: Bool
}

struct EraseStroke {
    var points: [CGPoint]
    var radius: CGFloat
}

struct Sticker {
    let source: CIImage
    let mask: CIImage
    let foundSubject: Bool
}

actor StickerMaker {
    static let maxDimension = 1024
    static let borderWidth: CGFloat = 14

    private let context = CIContext()

    func makeSticker(from data: Data) async throws -> Sticker {
        let image = try downscaledImage(from: data)
        let subject = try await subjectMask(for: image)
        return Sticker(
            source: CIImage(cgImage: image),
            mask: subject.image,
            foundSubject: subject.foundSubject
        )
    }

    func preview(of sticker: Sticker, erasing strokes: [EraseStroke] = []) throws -> CGImage {
        let image = composite(sticker, erasing: strokes)
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw StickerError.renderFailed
        }
        return cgImage
    }

    func trimmedImage(of sticker: Sticker, erasing strokes: [EraseStroke] = []) throws -> CGImage {
        croppedToContent(try preview(of: sticker, erasing: strokes))
    }

    func pngData(of sticker: Sticker, erasing strokes: [EraseStroke] = []) throws -> Data {
        let image = try trimmedImage(of: sticker, erasing: strokes)
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw StickerError.renderFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw StickerError.renderFailed
        }
        return output as Data
    }

    func subjectMask(for image: CGImage) async throws -> SubjectMask {
        let handler = ImageRequestHandler(image)
        let observation = try await handler.perform(GenerateForegroundInstanceMaskRequest())

        if let observation {
            let buffer = try observation.generateScaledMask(
                for: observation.allInstances,
                scaledToImageFrom: handler
            )
            return SubjectMask(image: CIImage(cvPixelBuffer: buffer), foundSubject: true)
        }

        let fullCoverage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return SubjectMask(image: fullCoverage, foundSubject: false)
    }

    private func croppedToContent(_ image: CGImage, padding: Int = 4) -> CGImage {
        let width = image.width
        let height = image.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        guard let drawing = CGContext(
            data: &alpha,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return image }
        drawing.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 8 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }

        let rect = CGRect(
            x: max(minX - padding, 0),
            y: max(minY - padding, 0),
            width: min(maxX + padding, width - 1) - max(minX - padding, 0) + 1,
            height: min(maxY + padding, height - 1) - max(minY - padding, 0) + 1
        )
        return image.cropping(to: rect) ?? image
    }

    private func erasedMask(_ mask: CIImage, strokes: [EraseStroke]) -> CIImage {
        guard !strokes.isEmpty else { return mask }
        let width = Int(mask.extent.width)
        let height = Int(mask.extent.height)
        guard let drawing = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return mask }

        drawing.setFillColor(gray: 1, alpha: 1)
        drawing.fill(CGRect(x: 0, y: 0, width: width, height: height))
        drawing.setStrokeColor(gray: 0, alpha: 1)
        drawing.setLineCap(.round)
        drawing.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            drawing.setLineWidth(stroke.radius * 2)
            drawing.beginPath()
            drawing.move(to: first)
            for point in stroke.points.dropFirst() {
                drawing.addLine(to: point)
            }
            if stroke.points.count == 1 {
                drawing.addLine(to: first)
            }
            drawing.strokePath()
        }

        guard let image = drawing.makeImage() else { return mask }
        let combined = CIFilter.multiplyCompositing()
        combined.inputImage = CIImage(cgImage: image)
        combined.backgroundImage = mask
        return combined.outputImage?.cropped(to: mask.extent) ?? mask
    }

    private func composite(_ sticker: Sticker, erasing strokes: [EraseStroke]) -> CIImage {
        let mask = erasedMask(sticker.mask, strokes: strokes)
        let border = Self.borderWidth
        let canvas = sticker.source.extent.insetBy(dx: -border, dy: -border)
        let clear = CIImage(color: .clear).cropped(to: canvas)
        let black = CIImage(color: .black).cropped(to: canvas)

        let cutout = masked(sticker.source, by: mask, over: clear)

        let paddedMask = mask.composited(over: black).cropped(to: canvas)
        let grown = CIFilter.morphologyMaximum()
        grown.inputImage = paddedMask
        grown.radius = Float(border)
        let softened = CIFilter.gaussianBlur()
        softened.inputImage = grown.outputImage?.cropped(to: canvas)
        softened.radius = 1.5
        let borderMask = softened.outputImage?.cropped(to: canvas) ?? paddedMask

        let whiteLayer = masked(CIImage(color: .white).cropped(to: canvas), by: borderMask, over: clear)
        return cutout.composited(over: whiteLayer).cropped(to: canvas)
    }

    private func masked(_ image: CIImage, by mask: CIImage, over background: CIImage) -> CIImage {
        let blend = CIFilter.blendWithMask()
        blend.inputImage = image
        blend.backgroundImage = background
        blend.maskImage = mask
        return blend.outputImage ?? image
    }

    private func downscaledImage(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw StickerError.unreadableImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw StickerError.unreadableImage
        }
        return image
    }
}
