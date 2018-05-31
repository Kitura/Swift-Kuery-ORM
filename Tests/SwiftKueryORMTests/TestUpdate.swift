import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestUpdate: XCTestCase {
    static var allTests: [(String, (TestUpdate) -> () throws -> Void)] {
        return [
            ("testUpdate", testUpdate),
        ]
    }

    struct Person: Model {
        static var tableName = "People"
        var name: String
        var age: Int
    }

    /**
      Testing that the correct SQL Query is created to update a specific model.
    */
    func testUpdate() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            let person = Person(name: "Joe", age: 38)
            person.update(id: 1) { p, error in
                XCTAssertNil(error, "Update Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Update Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "UPDATE People SET"
                  let expectedSuffix = "WHERE People.id = ?3"
                  let expectedUpdates = ["name = ?1", "age = ?2"]
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.hasSuffix(expectedSuffix))
                  for update in expectedUpdates {
                      XCTAssertTrue(resultQuery.contains(update))
                  }
                }
                XCTAssertNotNil(p, "Update Failed: No model returned")
                if let p = p {
                    XCTAssertEqual(p.name, person.name, "Update Failed: \(String(describing: p.name)) is not equal to \(String(describing: person.name))")
                    XCTAssertEqual(p.age, person.age, "Update Failed: \(String(describing: p.age)) is not equal to \(String(describing: person.age))")
                }
                expectation.fulfill()
            }
        })
    }
}
