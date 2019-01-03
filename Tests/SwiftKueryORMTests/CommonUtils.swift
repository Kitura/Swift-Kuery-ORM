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
import Dispatch

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

    init(result: Result, withDeleteRequiresUsing: Bool = false, withUpdateRequiresFrom: Bool = false, createAutoIncrement: ((String, Bool) -> String)? = nil) {
        self.queryBuilder = QueryBuilder(withDeleteRequiresUsing: withDeleteRequiresUsing, withUpdateRequiresFrom: withUpdateRequiresFrom, columnBuilder: TestColumnBuilder())
        self.result = result
    }

    func connect(onCompletion: @escaping (QueryResult) -> ()) {
        onCompletion(QueryResult.successNoData)
    }

    func connectSync() -> QueryResult {
        return QueryResult.successNoData
    }

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
            onCompletion(.resultSet(ResultSet(TestResultFetcher(numberOfRows: 1), connection: self)))
        case .returnThreeRows:
            onCompletion(.resultSet(ResultSet(TestResultFetcher(numberOfRows: 3), connection: self)))
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

    func prepareStatement(_ query: Query, onCompletion: @escaping ((QueryResult) -> ())) {
        onCompletion(QueryResult.success(TestPreparedStatement()))
    }

    func prepareStatement(_ raw: String, onCompletion: @escaping ((QueryResult) -> ())) {
        onCompletion(QueryResult.success(TestPreparedStatement()))
    }

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

    func done() {
        return
    }

    func fetchNext(callback: @escaping (([Any?]?, Error?)) -> ()) {
        DispatchQueue.global().async {
            if self.fetched < self.numberOfRows {
                self.fetched += 1
                return callback((self.rows[self.fetched - 1], nil))
            }
            return callback((nil, nil))
        }
    }

    func fetchTitles(callback: @escaping (([String]?, Error?)) -> ()) {
        callback((titles, nil))
    }
}

func createConnection(_ result: TestConnection.Result) -> TestConnection {
    return TestConnection(result: result)
}

func createConnection(withDeleteRequiresUsing: Bool = false, withUpdateRequiresFrom: Bool = false, createAutoIncrement: ((String, Bool) -> String)? = nil) -> TestConnection {
    return TestConnection(result: .returnEmpty, withDeleteRequiresUsing: withDeleteRequiresUsing, withUpdateRequiresFrom: withUpdateRequiresFrom, createAutoIncrement: createAutoIncrement)
}

// Dummy class for test framework
class CommonUtils { }

// Classes that conform to Connection are required to provide a QueryBuilder which in turn requires an implementation conforming to ColumnCreator. The TestColumnBuilder class fulfils this requirement.
class TestColumnBuilder: ColumnCreator {
    func buildColumn(for column: Column, using queryBuilder: QueryBuilder) -> String? {

        var result = column.name
        let identifierQuoteCharacter = queryBuilder.substitutions[QueryBuilder.QuerySubstitutionNames.identifierQuoteCharacter.rawValue]
        if !result.hasPrefix(identifierQuoteCharacter) {
            result = identifierQuoteCharacter + result + identifierQuoteCharacter + " "
        }

        result += "type"

        if column.autoIncrement {
            result += " AUTO_INCREMENT"
        }

        if column.isPrimaryKey {
            result += " PRIMARY KEY"
        }
        if column.isNotNullable {
            result += " NOT NULL"
        }
        return result
    }
}
