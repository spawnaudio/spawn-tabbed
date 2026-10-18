import CoreGraphics
import XCTest
@testable import Tabbed

final class ParkingSpotTests: XCTestCase {
    private let size = CGSize(width: 800, height: 600)
    private let main = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func test_singleScreen_parksBottomRight() {
        let parked = ParkingSpot.frame(for: size, screens: [(main, main)])
        XCTAssertEqual(parked?.origin, CGPoint(x: 1439, y: -599))
    }

    func test_displayToTheRight_parksBottomLeftInstead() {
        let right = CGRect(x: 1440, y: -500, width: 1920, height: 1080)
        let parked = ParkingSpot.frame(for: size, screens: [(main, main), (right, right)])!
        XCTAssertEqual(parked.origin, CGPoint(x: -799, y: -599))
        XCTAssertFalse(parked.intersects(right))
    }

    func test_displaysOnBothSides_usesAnotherScreensCorner() {
        let left = CGRect(x: -1920, y: -500, width: 1920, height: 1080)
        let right = CGRect(x: 1440, y: -500, width: 1920, height: 1080)
        let screens = [(main, main), (left, left), (right, right)]
        // Both corners of the main screen touch a neighbour, so park on the left display.
        XCTAssertEqual(ParkingSpot.frame(for: size, screens: screens)?.origin, CGPoint(x: -1, y: -1099))
    }
}
