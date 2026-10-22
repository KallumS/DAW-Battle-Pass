import XCTest
@testable import PassCore
final class DiceTests: XCTestCase {
  func testSame() { XCTAssertEqual(Dice(5).next(), Dice(5).next()) }
}
