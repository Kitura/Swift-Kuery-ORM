import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestId: XCTestCase {
    static var allTests: [(String, (TestId) -> () throws -> Void)] {
        return [
            ("testFind", testFind),
            ("testUpdate", testUpdate),
            ("testDelete", testDelete),
            ("testNilIDInsert", testNilIDInsert),
            ("testNonAutoNilIDInsert", testNonAutoNilIDInsert),
        ]
    }

    struct Person: Model {
        static var tableName = "People"
        static var idColumnName = "name"
        var name: String
        var age: Int
    }

    /**
      The following tests check that the ID field for the model is the name field in the model.
    */

    /**
      Testing that the correct SQL Query is created to retrieve a specific model.
      Testing that the model can be retrieved
    */
    func testFind() {
        let connection: TestConnection = createConnection(.returnOneRow)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.find(id: "Joe") { p, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\" WHERE \"People\".\"name\" = ?1"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(p, "Find Failed: No model returned")
                if let p = p {
                    XCTAssertEqual(p.name, "Joe", "Find Failed: \(String(describing: p.name)) is not equal to Joe")
                    XCTAssertEqual(p.age, 38, "Find Failed: \(String(describing: p.age)) is not equal to 38")
                }
                expectation.fulfill()
            }
        })
    }

    /**
      Testing that the correct SQL Query is created to update a specific model.
    */
    func testUpdate() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            let person = Person(name: "Joe", age: 38)
            person.update(id: "Joe") { p, error in
                XCTAssertNil(error, "Update Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Update Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "UPDATE \"People\" SET"
                  let expectedSuffix = "WHERE \"People\".\"name\" = ?3"
                  let expectedUpdates = [["\"name\" = ?1", "\"name\" = ?2"], ["\"age\" = ?1", "\"age\" = ?2"]]
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.hasSuffix(expectedSuffix))
                  for updates in expectedUpdates {
                      var success = false
                      for update in updates where resultQuery.contains(update) {
                        success = true
                      }
                      XCTAssertTrue(success)
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

    /**
      Testing that the correct SQL Query is created to delete a specific model
    */
    func testDelete() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.delete(id: "Joe") { error in
                XCTAssertNil(error, "Delete Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Delete Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "DELETE FROM \"People\" WHERE \"People\".\"name\" = ?1"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Expected query \(String(describing: expectedQuery)) did not match result query: \(String(describing: resultQuery))")
                }
                expectation.fulfill()
            }
        })
    }

    struct IdentifiedPerson: Model {
        static var tableName = "People"
        static var idKeyPath: IDKeyPath = \IdentifiedPerson.id

        var id: Int?
        var name: String
        var age: Int
    }

    func testNilIDInsert() {
        let connection: TestConnection = createConnection(.returnOneRow) //[1, "Joe", Int32(38)]
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            let myIPerson = IdentifiedPerson(id: nil, name: "Joe", age: 38)
            myIPerson.save() { identifiedPerson, error in
                XCTAssertNil(error, "Error on IdentifiedPerson.save")
                if let newPerson = identifiedPerson {
                    XCTAssertEqual(newPerson.id, 1, "Id not stored on IdentifiedPerson")
                }
                expectation.fulfill()
            }
        })
    }

    struct NonAutoIDPerson: Model {
        static var tableName = "People"

        var id: Int?
        var name: String
        var age: Int
    }

    func testNonAutoNilIDInsert() {
        let connection: TestConnection = createConnection(.returnOneRow) //[1, "Joe", Int32(38)]
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            NonAutoIDPerson.createTable { result, error in
                XCTAssertNil(error, "Table Creation Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.raw, "Table Creation Failed: Query is nil")
                if let raw = connection.raw {
                    let expectedQuery = "CREATE TABLE \"People\" (\"id\" type PRIMARY KEY, \"name\" type NOT NULL, \"age\" type NOT NULL)"
                    XCTAssertEqual(raw, expectedQuery, "Table Creation Failed: Invalid query")
                }
                expectation.fulfill()
            }
        })
    }
}
