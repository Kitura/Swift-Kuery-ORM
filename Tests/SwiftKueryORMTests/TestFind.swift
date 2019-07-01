import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestFind: XCTestCase {
    static var allTests: [(String, (TestFind) -> () throws -> Void)] {
        return [
            ("testFind", testFind),
            ("testFindAll", testFindAll),
            ("testFindAllMatching", testFindAllMatching),
            ("testFindAllMatchingArrayFilter", testFindAllMatchingArrayFilter),
        ]
    }

    struct Person: Model {
        static var tableName = "People"
        var name: String
        var age: Int
    }

    /**
      Testing that the correct SQL Query is created to retrieve a specific model.
      Testing that the model can be retrieved
    */
    func testFind() {
        let connection: TestConnection = createConnection(.returnOneRow)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.find(id: 1) { p, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\" WHERE \"People\".\"id\" = ?1"
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
     Testing that the correct SQL Query is created to retrieve a specific model when using a non-default database.
     Testing that the model can be retrieved
     */
    func testFindUsingDB() {
        let connection: TestConnection = createConnection(.returnOneRow)
        let db = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.find(id: 1, using: db) { p, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                    let expectedQuery = "SELECT * FROM \"People\" WHERE \"People\".\"id\" = ?1"
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
      Testing that the correct SQL Query is created to retrieve all the models.
      Testing that correct amount of models are retrieved
    */
    func testFindAll() {
        let connection: TestConnection = createConnection(.returnThreeRows)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.findAll { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\""
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  XCTAssertEqual(array.count, 3, "Find Failed: \(String(describing: array.count)) is not equal to 3")
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
      Testing that the correct SQL Query is created to retrieve all the models.
      Testing that correct amount of models are retrieved
    */
    func testFindAllMatching() {
        let connection: TestConnection = createConnection(.returnOneRow)
        Database.default = Database(single: connection)
        let filter = Filter(name: "Joe", age: 38)
        performTest(asyncTasks: { expectation in
            Person.findAll(matching: filter) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "SELECT * FROM \"People\" WHERE"
                  let expectedClauses = [["\"People\".\"name\" = ?1", "\"People\".\"name\" = ?2"], ["\"People\".\"age\" = ?1", "\"People\".\"age\" = ?2"]]
                  let expectedOperator = "AND"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  for whereClauses in expectedClauses {
                    var success = false
                    for whereClause in whereClauses where resultQuery.contains(whereClause) {
                      success = true
                    }
                    XCTAssertTrue(success)
                  }
                  XCTAssertTrue(resultQuery.contains(expectedOperator))
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  XCTAssertEqual(array.count, 1, "Find Failed: \(String(describing: array.count)) is not equal to 1")
                  let user = array[0]
                  XCTAssertEqual(user.name, "Joe")
                  XCTAssertEqual(user.age, 38)
                }
                expectation.fulfill()
            }
        })
    }

    struct AgeFilter: QueryParams {
        let age: [Int]
    }

    /**
     Testing that the correct SQL Query is created to retrieve all the models.
     Testing that correct amount of models are retrieved
     */
    func testFindAllMatchingArrayFilter() {
        let connection: TestConnection = createConnection(.returnThreeRows)
        Database.default = Database(single: connection)
        let filterArray = [38,28,36]
        let filter = AgeFilter(age: filterArray)
        let numberOfFilters = filterArray.count
        performTest(asyncTasks: { expectation in
            Person.findAll(matching: filter) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                    let expectedPrefix = "SELECT * FROM \"People\" WHERE"
                    let expectedClauses = [["\"People\".\"age\" = ?1", "\"People\".\"age\" = ?2", "\"People\".\"age\" = ?3"]]
                    let expectedOperator = "OR"
                    let resultQuery = connection.descriptionOf(query: query)
                    XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                    var numberOfClauses = 0
                    for whereClauses in expectedClauses {
                        var success = false
                        for whereClause in whereClauses where resultQuery.contains(whereClause) {
                            success = true
                        }
                        XCTAssertTrue(success)
                        numberOfClauses += 1
                    }
                    XCTAssertTrue(resultQuery.contains(expectedOperator))
                    XCTAssertEqual(numberOfFilters, numberOfClauses, "Incorrect number of where clauses in query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                    XCTAssertEqual(array.count, 3, "Find Failed: \(String(describing: array.count)) is not equal to 1")
                }
                expectation.fulfill()
            }
        })
    }

    struct Order: Model {
        static var tableName = "Orders"
        var item: Int
        var deliveryAddress: String
    }

    /**
     Testing that a Model can be decoded if it contains camel case property name.
     */
    func testCamelCaseProperty() {
        let connection: TestConnection = createConnection(.returnOneOrder)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Order.findAll { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                    let expectedQuery = "SELECT * FROM \"Orders\""
                    let resultQuery = connection.descriptionOf(query: query)
                    XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                    XCTAssertEqual(array.count, 1, "Find Failed: \(String(describing: array.count)) is not equal to 3")
                }
                expectation.fulfill()
            }
        })
    }

}
