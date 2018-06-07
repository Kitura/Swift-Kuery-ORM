import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts


class TestSave: XCTestCase {
    static var allTests: [(String, (TestSave) -> () throws -> Void)] {
        return [
            ("testSave", testSave),
            ("testSave", testSaveWithId),
        ]
    }

    struct Person: Model {
        static var tableName = "People"
        var name: String
        var age: Int
    }
    /**
      Testing that the correct SQL Query is created to save a Model
    */
    func testSave() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            let person = Person(name: "Joe", age: 38)
            person.save { p, error in
                XCTAssertNil(error, "Save Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Save Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "INSERT INTO People"
                  let expectedSQLStatement = "VALUES"
                  let expectedDictionary = ["name": "?1,?2", "age": "?1,?2"]

                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.contains(expectedSQLStatement))
                  verifyColumnsAndValues(resultQuery: resultQuery, expectedDictionary: expectedDictionary)
                }
                XCTAssertNotNil(p, "Save Failed: No model returned")
                if let p = p {
                    XCTAssertEqual(p.name, person.name, "Save Failed: \(String(describing: p.name)) is not equal to \(String(describing: person.name))")
                    XCTAssertEqual(p.age, person.age, "Save Failed: \(String(describing: p.age)) is not equal to \(String(describing: person.age))")
                }
                expectation.fulfill()
            }
        })
    }

    /**
      Testing that the correct SQL Query is created to save a Model
      Testing that an id is correcly returned
    */
    func testSaveWithId() {
        let connection: TestConnection = createConnection(.returnOneRow)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            let person = Person(name: "Joe", age: 38)
            person.save { (id: Int?, p: Person?, error: RequestError?) in
                XCTAssertNil(error, "Save Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Save Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "INSERT INTO People"
                  let expectedSQLStatement = "VALUES"
                  let expectedDictionary = ["name": "?1,?2", "age": "?1,?2"]

                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.contains(expectedSQLStatement))
                  verifyColumnsAndValues(resultQuery: resultQuery, expectedDictionary: expectedDictionary)
                }
                XCTAssertNotNil(p, "Save Failed: No model returned")
                XCTAssertEqual(id, 1, "Save Failed: \(String(describing: id)) is not equal to 1)")
                if let p = p {
                    XCTAssertEqual(p.name, person.name, "Save Failed: \(String(describing: p.name)) is not equal to \(String(describing: person.name))")
                    XCTAssertEqual(p.age, person.age, "Save Failed: \(String(describing: p.age)) is not equal to \(String(describing: person.age))")
                }
                expectation.fulfill()
            }
        })
    }

}
