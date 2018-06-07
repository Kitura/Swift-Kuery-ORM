/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

#if os(Linux)
    import Glibc
#elseif os(OSX)
    import Darwin
#endif

import XCTest
import Foundation

import SwiftKuery

class TestConnection: Connection {
    let queryBuilder: QueryBuilder
    let result: Result
    var query: Query? = nil
    var raw: String? = nil

    enum Result {
        case returnEmpty
        case returnOneRow
        case returnThreeRows
        case returnError
        case returnValue
    }

    init(result: Result, withDeleteRequiresUsing: Bool = false, withUpdateRequiresFrom: Bool = false, createAutoIncrement: ((String) -> String)? = nil) {
        self.queryBuilder = QueryBuilder(withDeleteRequiresUsing: withDeleteRequiresUsing, withUpdateRequiresFrom: withUpdateRequiresFrom, createAutoIncrement: createAutoIncrement)
        self.result = result
    }

    func connect(onCompletion: (QueryError?) -> ()) {onCompletion(nil)}

    public var isConnected: Bool { return true }

    func closeConnection() {}

    func execute(query: Query, onCompletion: @escaping ((QueryResult) -> ())) {
        self.query = query
        returnResult(onCompletion)
    }

    func execute(_ raw: String, onCompletion: @escaping ((QueryResult) -> ())) {
        self.raw = raw
        returnResult(onCompletion)
    }

    func execute(query: Query, parameters: [Any?], onCompletion: @escaping ((QueryResult) -> ())) {
        self.query = query
        returnResult(onCompletion)
    }

    func execute(_ raw: String, parameters: [Any?], onCompletion: @escaping ((QueryResult) -> ())) {
        self.raw = raw
        returnResult(onCompletion)
    }

    func execute(query: Query, parameters: [String:Any?], onCompletion: @escaping ((QueryResult) -> ())) {
        self.query = query
        returnResult(onCompletion)
    }

    func execute(_ raw: String, parameters: [String:Any?], onCompletion: @escaping ((QueryResult) -> ()))  {
        self.raw = raw
        returnResult(onCompletion)
    }


    func descriptionOf(query: Query) -> String {
        do {
            let kuery = try query.build(queryBuilder: queryBuilder)
            return kuery
        }
        catch let error {
            XCTFail("Failed to build query: \(error)")
            return ""
        }
    }

    private func returnResult(_ onCompletion: @escaping ((QueryResult) -> ())) {
        switch result {
        case .returnEmpty:
            onCompletion(.successNoData)
        case .returnOneRow:
            onCompletion(.resultSet(ResultSet(TestResultFetcher(numberOfRows: 1))))
        case .returnThreeRows:
            onCompletion(.resultSet(ResultSet(TestResultFetcher(numberOfRows: 3))))
        case .returnError:
            onCompletion(.error(QueryError.noResult("Error in query execution.")))
        case .returnValue:
            onCompletion(.success(5))
        }
    }

    func startTransaction(onCompletion: @escaping ((QueryResult) -> ())) {}

    func commit(onCompletion: @escaping ((QueryResult) -> ())) {}

    func rollback(onCompletion: @escaping ((QueryResult) -> ())) {}

    func create(savepoint: String, onCompletion: @escaping ((QueryResult) -> ())) {}

    func rollback(to savepoint: String, onCompletion: @escaping ((QueryResult) -> ())) {}

    func release(savepoint: String, onCompletion: @escaping ((QueryResult) -> ())) {}

    struct TestPreparedStatement: PreparedStatement {}

    func prepareStatement(_ query: Query) throws -> PreparedStatement { return TestPreparedStatement() }

    func prepareStatement(_ raw: String) throws -> PreparedStatement { return TestPreparedStatement() }

    func execute(preparedStatement: PreparedStatement, onCompletion: @escaping ((QueryResult) -> ())) {}

    func execute(preparedStatement: PreparedStatement, parameters: [Any?], onCompletion: @escaping ((QueryResult) -> ())) {}

    func execute(preparedStatement: PreparedStatement, parameters: [String:Any?], onCompletion: @escaping ((QueryResult) -> ())) {}

    func release(preparedStatement: PreparedStatement, onCompletion: @escaping ((QueryResult) -> ())) {}
}

class TestResultFetcher: ResultFetcher {
    let numberOfRows: Int
    let rows = [[1, "Joe", Int32(38)], [2, "Adam", Int32(28)], [3, "Chris", Int32(36)]]
    let titles = ["id", "name", "age"]
    var fetched = 0

    init(numberOfRows: Int) {
        self.numberOfRows = numberOfRows
    }

    func fetchNext() -> [Any?]? {
        if fetched < numberOfRows {
            fetched += 1
            return rows[fetched - 1]
        }
        return nil
    }

    func fetchNext(callback: ([Any?]?) ->()) {
        callback(fetchNext())
    }

    func fetchTitles() -> [String] {
        return titles
    }
}

func createConnection(_ result: TestConnection.Result) -> TestConnection {
    return TestConnection(result: result)
}

func createConnection(withDeleteRequiresUsing: Bool = false, withUpdateRequiresFrom: Bool = false, createAutoIncrement: ((String) -> String)? = nil) -> TestConnection {
    return TestConnection(result: .returnEmpty, withDeleteRequiresUsing: withDeleteRequiresUsing, withUpdateRequiresFrom: withUpdateRequiresFrom, createAutoIncrement: createAutoIncrement)
}

// Dummy class for test framework
class CommonUtils { }


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
            let nsString = NSString(string: self)
            let matchedString = nsString.substring(with: capturedGroupIndex)
            results.append(matchedString)
        }

        return results
    }
}

func verifyColumnsAndValues(resultQuery: String, expectedDictionary: [String: String]) {
  //Regex to extract the columns and values of an insert
  //statement, such as:
  //INSERT into table (columns) VALUES (values)
  let regexPattern = ".*\\((.*)\\)[^\\(\\)]*\\((.*)\\)"
  let groups = resultQuery.capturedGroups(withRegex: regexPattern)
  XCTAssertEqual(groups.count, 2)

  // Extracting the columns and values from the captured groups
  let columns = groups[0].filter { $0 != " " }.split(separator: ",")
  let values = groups[1].filter { $0 != " " && $0 != "'" }.split(separator: ",")
  // Creating the result dictionary [Column: Value]
  var resultDictionary: [String: String] = [:]
  for (column, value) in zip(columns, values) {
    resultDictionary[String(column)] = String(value)
  }

  // Asserting the results which the expectations
  XCTAssertEqual(resultDictionary.count, expectedDictionary.count)
  for (key, value) in expectedDictionary {
    XCTAssertNotNil(resultDictionary[key], "Value for key: \(String(describing: key)) is nil in the result dictionary")
    var values = value.split(separator: ",")
    var success = false
    for value in values where resultDictionary[key] == String(value) {
      success = true
    }
    XCTAssertTrue(success)
  }
}

