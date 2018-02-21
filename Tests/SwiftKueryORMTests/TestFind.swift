import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestFind: XCTestCase {
    static var allTests: [(String, (TestFind) -> () throws -> Void)] {
        return [
            ("testSave", testFind),
            ("testSave", testFindAll),
        ]
    }

    struct Person: Model {
        var name: String
        var age: Int
    }

    func testFind() {
        Database.defaultConnection = .global(createConnection(.returnOneRow))
        performTest(asyncTasks: { expectation in
            Person.find(id: 1) { id, p, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(p, "Find Failed: No model returned")
                if let p = p {
                    XCTAssertEqual(p.name, "Joe", "Find Failed: \(String(describing: p.name)) is not equal to Joe")
                    XCTAssertEqual(p.age, 38, "Find Failed: \(String(describing: p.age)) is not equal to 38")
                }
                expectation.fulfill()
            }
        })
    }

    func testFindAll() {
        Database.defaultConnection = .global(createConnection(.returnThreeRows))
        performTest(asyncTasks: { expectation in
            Person.findAll { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  XCTAssertEqual(array.count, 3, "Find Failed: \(String(describing: array.count)) is not equal to 3")
                }
                expectation.fulfill()
            }
        })
    }
}
