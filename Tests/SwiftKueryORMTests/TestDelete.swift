import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestDelete: XCTestCase {
    static var allTests: [(String, (TestDelete) -> () throws -> Void)] {
        return [
            ("testDeleteWithId", testDeleteWithId),
            ("testDeleteAll", testDeleteAll),
        ]
    }

    struct Person: Model {
        static var tableName = "People"
        var name: String
        var age: Int
    }

    func testDeleteWithId() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.delete(id: 1) { error in
                XCTAssertNil(error, "Delete Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Delete Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "DELETE FROM People WHERE People.id = '1'"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Expected query \(String(describing: expectedQuery)) did not match result query: \(String(describing: resultQuery))")
                }
                expectation.fulfill()
            }
        })
    }

    func testDeleteAll() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.deleteAll { error in
                XCTAssertNil(error, "Delete Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Delete Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "DELETE FROM People"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Expected query \(String(describing: expectedQuery)) did not match result query: \(String(describing: resultQuery))")
                }
                expectation.fulfill()
            }
        })
    }
}
