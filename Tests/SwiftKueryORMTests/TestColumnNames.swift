import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

class TestColumnNames: XCTestCase {
    static var allTests: [(String, (TestColumnNames) -> () throws -> Void)] {
        return [
            ("testSave", testSave),
            ("testUpdate", testUpdate),
            ("testFindAllMatching", testFindAllMatching),
            ("testDeleteAllMatching", testDeleteAllMatching),
        ]
    }

    struct Student: Model {
        static var columnNames = ["name": "my_name", "age": "my_age"]
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
            let student = Student(name: "Joe", age: 38)
            student.save { newStudent, error in
                XCTAssertNil(error, "Save Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Save Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "INSERT INTO Students"
                  let expectedSQLStatement = "VALUES"
                  let expectedDictionary = ["my_name": "?1,?2", "my_age": "?1,?2"]

                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.contains(expectedSQLStatement))
                  verifyColumnsAndValues(resultQuery: resultQuery, expectedDictionary: expectedDictionary)
                }
                XCTAssertNotNil(newStudent, "Save Failed: No model returned")
                if let newStudent = newStudent {
                    XCTAssertEqual(newStudent.name, student.name, "Save Failed: \(String(describing: newStudent.name)) is not equal to \(String(describing: student.name))")
                    XCTAssertEqual(newStudent.age, student.age, "Save Failed: \(String(describing: newStudent.age)) is not equal to \(String(describing: student.age))")
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
            let student = Student(name: "Joe", age: 38)
            student.save { (id: Int?, newStudent: Student?, error: RequestError?) in
                XCTAssertNil(error, "Save Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Save Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "INSERT INTO Students"
                  let expectedSQLStatement = "VALUES"
                  let expectedDictionary = ["my_name": "?1,?2", "my_age": "?1,?2"]

                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.contains(expectedSQLStatement))
                  verifyColumnsAndValues(resultQuery: resultQuery, expectedDictionary: expectedDictionary)
                }
                XCTAssertNotNil(newStudent, "Save Failed: No model returned")
                XCTAssertEqual(id, 1, "Save Failed: \(String(describing: id)) is not equal to 1)")
                if let newStudent = newStudent {
                    XCTAssertEqual(newStudent.name, student.name, "Save Failed: \(String(describing: newStudent.name)) is not equal to \(String(describing: student.name))")
                    XCTAssertEqual(newStudent.age, student.age, "Save Failed: \(String(describing: newStudent.age)) is not equal to \(String(describing: student.age))")
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
            Student.findAll(matching: filter) { array, error in
                XCTAssertNil(error, "Find Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Find Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "SELECT * FROM Students WHERE"
                  let expectedClauses = [["Students.my_name = ?1", "Students.my_name = ?2"], ["Students.my_age = ?1", "Students.my_age = ?2"]]
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
                  let student = array[0]
                  XCTAssertEqual(student.name, "Joe")
                  XCTAssertEqual(student.age, 38)
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
            let student = Student(name: "Joe", age: 38)
            student.update(id: 1) { newStudent, error in
                XCTAssertNil(error, "Update Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Update Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "UPDATE Students SET"
                  let expectedSuffix = "WHERE Students.id = ?3"
                  let expectedUpdates = [["my_name = ?1", "my_name = ?2"], ["my_age = ?1", "my_age = ?2"]]
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
                XCTAssertNotNil(newStudent, "Update Failed: No model returned")
                if let newStudent = newStudent {
                    XCTAssertEqual(newStudent.name, student.name, "Update Failed: \(String(describing: newStudent.name)) is not equal to \(String(describing: student.name))")
                    XCTAssertEqual(newStudent.age, student.age, "Update Failed: \(String(describing: newStudent.age)) is not equal to \(String(describing: student.age))")
                }
                expectation.fulfill()
            }
        })
    }

    /**
      Testing that the correct SQL Query is created to delete all model matching the QueryParams
    */
    func testDeleteAllMatching() {
        let connection: TestConnection = createConnection()
        Database.default = Database(single: connection)
        let filter = Filter(name: "Joe", age: 38)
        performTest(asyncTasks: { expectation in
            Student.deleteAll(matching: filter) { error in
                XCTAssertNil(error, "Delete Failed: \(String(describing: error))")
                XCTAssertNotNil(connection.query, "Delete Failed: Query is nil")
                if let query = connection.query {
                  let expectedPrefix = "DELETE FROM Students WHERE"
                  let expectedClauses = [["Students.my_name = ?1", "Students.my_name = ?2"], ["Students.my_age = ?1", "Students.my_age = ?2"]]
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
                expectation.fulfill()
            }
        })
    }
}
