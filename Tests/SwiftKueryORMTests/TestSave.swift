import XCTest

@testable import SwiftKueryORM
import Foundation
import KituraContracts

/*
  Function to extract the captured groups from a Regex match operation:
  https://samwize.com/2016/07/21/how-to-capture-multiple-groups-in-a-regex-with-swift/
**/
extension String {
    func capturedGroups(withRegex pattern: String) -> [String] {
        var results = [String]()

        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }

        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.count))

        guard let match = matches.first else { return results }

        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }

        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.range(at: i)
            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }

        return results
    }
}

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
                  let expectedTuples = [("name", "Joe"), ("age", "38")]

                  let resultQuery = connection.descriptionOf(query: query)
                  //Regex to extract the columns and values of an insert
                  //statement, such as:
                  //INSERT into table (columns) VALUES (values)
                  let regexPattern = ".*\\((.*)\\)[^\\(\\)]*\\((.*)\\)"
                  let groups = resultQuery.capturedGroups(withRegex: regexPattern)
                  XCTAssertEqual(groups.count, 2)

                  // Extracting the columns and values from the captured groups
                  let columns = groups[0].filter { $0 != " " }.split(separator: ",")
                  let values = groups[1].filter { $0 != " " && $0 != "'" }.split(separator: ",")

                  // Creating the result tuples (Column, Value)
                  var resultTuples: [(String, String)] = []
                  for (column, value) in zip(columns, values) {
                    resultTuples.append((String(column), String(value)))
                  }

                  // Asserting the results which the expectations
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.contains(expectedSQLStatement))
                  XCTAssertEqual(resultTuples.count, expectedTuples.count)
                  for i in 0..<expectedTuples.count {
                    XCTAssertEqual(resultTuples[i].0, expectedTuples[i].0)
                    XCTAssertEqual(resultTuples[i].1, expectedTuples[i].1)
                  }
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
                  let expectedColumns = ["name", "age"]
                  let expectedValues = ["'Joe'", "38"]
                  let resultQuery = connection.descriptionOf(query: query)
                  XCTAssertTrue(resultQuery.hasPrefix(expectedPrefix))
                  XCTAssertTrue(resultQuery.contains(expectedSQLStatement))
                  for (column, value) in zip(expectedColumns, expectedValues) {
                      XCTAssertTrue(resultQuery.contains(column))
                      XCTAssertTrue(resultQuery.contains(value))
                  }
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
