import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// 二维码生成（系统 CoreImage，零第三方依赖）
/// 普通黑白版 + 按样式着色版（CIFalseColor：底色/码色）
enum QRCodeImage {
    static func make(string: String, size: CGFloat = 240) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = size / max(output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 样式着色版：background = 码盒底色，foreground = 码点颜色
    static func tinted(string: String, background: UIColor, foreground: UIColor, size: CGFloat = 240) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let matrix = filter.outputImage else { return nil }

        let falseColor = CIFilter(name: "CIFalseColor")
        falseColor?.setValue(matrix, forKey: "inputImage")
        falseColor?.setValue(CIColor(color: background), forKey: "inputColor0")
        falseColor?.setValue(CIColor(color: foreground), forKey: "inputColor1")
        guard let colored = falseColor?.outputImage else { return nil }

        let scale = size / max(colored.extent.width, 1)
        let scaled = colored.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
