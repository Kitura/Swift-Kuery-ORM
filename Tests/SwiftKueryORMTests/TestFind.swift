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
            ("testFindAllLimit", testFindAllLimit),
            ("testFindAllLimitAndOffset", testFindAllLimitAndOffset),
            ("testFindAllOrderByDescending", testFindAllOrderByDescending),
            ("testFindAllOrderByAscending", testFindAllOrderByAscending),
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


    /**
      Testing that the correct SQL Query is created to retrieve a specific model.
      Testing that the model can be retrieved
    */
    func testFindAllLimit() {
        let connection: TestConnection = createConnection(.returnOneRow)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.findAll(limit: 1) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\" LIMIT 1"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  XCTAssertEqual(array.count, 1, "Find Failed: \(String(describing: array.count)) is not equal to 1")
                }
                expectation.fulfill()
            }
        })
    }

    /**
      Testing that the correct SQL Query is created to retrieve a specific model.
      Testing that the model can be retrieved
    */
    func testFindAllLimitAndOffset() {
        let connection: TestConnection = createConnection(.returnOneRow)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.findAll(offset: 2, limit: 1) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\" LIMIT 1 OFFSET 2"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  XCTAssertEqual(array.count, 1, "Find Failed: \(String(describing: array.count)) is not equal to 1")
                }
                expectation.fulfill()
            }
        })
    }

    /**
      Testing that the correct SQL Query is created to retrieve a specific model.
      Testing that correct amount of models are retrieved
      Testing that models are sorted by age in descending order
    */
    func testFindAllOrderByDescending() {
        let connection: TestConnection = createConnection(.returnThreeRowsSortedDescending)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.findAll(order: Order.desc("age")) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\" ORDER BY \"People\".\"age\" DESC"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  for (index, person) in array.enumerated() {
                    if index + 1 < array.count {
                      XCTAssertGreaterThanOrEqual(person.age, array[index + 1].age, "Find Failed: Age of person: \(String(describing: person.age)) is not greater than or equal to age of next person: \(String(describing: array[index + 1].age))")
                    }
                  }
                  XCTAssertEqual(array.count, 3, "Find Failed: \(String(describing: array.count)) is not equal to 3")
                }
                expectation.fulfill()
            }
        })
    }

    /**
      Testing that the correct SQL Query is created to retrieve a specific model.
      Testing that correct amount of models are retrieved
      Testing that models are sorted by age in ascending order
    */
    func testFindAllOrderByAscending() {
        let connection: TestConnection = createConnection(.returnThreeRowsSortedAscending)
        Database.default = Database(single: connection)
        performTest(asyncTasks: { expectation in
            Person.findAll(order: Order.asc("age")) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedQuery = "SELECT * FROM \"People\" ORDER BY \"People\".\"age\" ASC"
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertEqual(resultQuery, expectedQuery, "Find Failed: Invalid query")
                }
                XCTAssertNotNil(array, "Find Failed: No array of models returned")
                if let array = array {
                  for (index, person) in array.enumerated() {
                    if index + 1 < array.count {
                      XCTAssertLessThanOrEqual(person.age, array[index + 1].age, "Find Failed: Age of person: \(String(describing: person.age)) is not less than or equal to age of next person: \(String(describing: array[index + 1].age))")
                    }
                  }
                  XCTAssertEqual(array.count, 3, "Find Failed: \(String(describing: array.count)) is not equal to 3")
                }
                expectation.fulfill()
            }
        })
    }
}
