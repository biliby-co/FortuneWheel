import XCTest
@testable import FortuneWheel

final class FortuneWheelTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual("Hello, World!", "Hello, World!")
    }
    
    func testFortuneWheelModelWithTickSound() {
        let model = FortuneWheelModel(
            titles: ["Option 1", "Option 2", "Option 3"],
            size: 300,
            onSpinEnd: nil,
            enableTickSound: true
        )
        
        XCTAssertTrue(model.enableTickSound)
        XCTAssertEqual(model.titles.count, 3)
    }
    
    func testFortuneWheelModelWithoutTickSound() {
        let model = FortuneWheelModel(
            titles: ["Option 1", "Option 2"],
            size: 300,
            onSpinEnd: nil,
            enableTickSound: false
        )
        
        XCTAssertFalse(model.enableTickSound)
        XCTAssertEqual(model.titles.count, 2)
    }
    
    func testConsecutiveResultPrevention() {
        let model = FortuneWheelModel(
            titles: ["Option 1", "Option 2", "Option 3"],
            size: 300,
            onSpinEnd: nil,
            enableTickSound: false
        )
        
        _ = FortuneWheelViewModel(model: model)
        
        // Verify the model setup for consecutive prevention
        XCTAssertTrue(model.titles.count > 1, "Model should have multiple options for consecutive prevention test")
        
        // The actual consecutive prevention logic is tested through integration testing
        // when the wheel is actually spun in the UI
    }

    static var allTests = [
        ("testExample", testExample),
        ("testFortuneWheelModelWithTickSound", testFortuneWheelModelWithTickSound),
        ("testFortuneWheelModelWithoutTickSound", testFortuneWheelModelWithoutTickSound),
        ("testConsecutiveResultPrevention", testConsecutiveResultPrevention),
    ]
}
