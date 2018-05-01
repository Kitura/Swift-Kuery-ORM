import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestDelete: XCTestCase {
    static var allTests: [(String, (TestDelete) -> () throws -> Void)] {
        return [
            ("testDeleteWithId", testDeleteWithId),
            ("testDeleteAll", testDeleteAll),
            ("testDeleteAllMatching", testDeleteAllMatching),
        ]
    }

    struct Person: Model {
        static var tableName = "People"
        var name: String
        var age: Int
    }

    /**
      Testing that the correct SQL Query is created to delete a specific model
    */
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

    /**
      Testing that the correct SQL Query is created to delete all model
    */
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

    struct Filter: QueryParams {
      let name: String
      let age: Int
    }

    /**
      Testing that the correct SQL Query is created to delete all model matching the QueryParams
    */
    func testDeleteAllMatching() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        let filter = Filter(name: "Joe", age: 38)
        performTest(asyncTasks: { expectation in
            Person.deleteAll(matching: filter) { error in
                XCTAssertNil(error, "Delete Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Delete Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "DELETE FROM People WHERE"
                  let expectedClauses = ["People.name = 'Joe'", "People.age = '38'"]
                  let expectedOperator = "AND"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  for whereClause in expectedClauses {
                    XCTAssertTrue(resultQuery.contains(whereClause))
                  }
                  XCTAssertTrue(resultQuery.contains(expectedOperator))
                }
                expectation.fulfill()
            }
        })
    }
}
