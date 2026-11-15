#if DEBUG
import UIKit
import XCTest
@testable import StarLink

final class ImageResizerTests: XCTestCase {
    private func makeJPEG(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 1.0) ?? Data()
    }

    func testResizeCapsLongestSide() throws {
        let output = try XCTUnwrap(
            ImageResizer.resize(data: makeJPEG(width: 2000, height: 1500), maxDimension: 1280, quality: 0.8)
        )
        let image = try XCTUnwrap(UIImage(data: output))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 1281)
    }

    func testCorruptDataReturnsNil() {
        XCTAssertNil(ImageResizer.resize(data: Data([0x00, 0x01, 0x02]), maxDimension: 1280, quality: 0.8))
    }
}
#endif
