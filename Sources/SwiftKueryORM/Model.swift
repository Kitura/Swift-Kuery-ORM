/**
 Copyright IBM Corporation 2018

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import SwiftKuery
import KituraContracts
import Foundation
import Dispatch

/// Protocol Model conforming to Codable defining the available operations
public protocol Model: Codable {
  /// Defines the tableName in the Database
  static var tableName: String {get}
  /// Defines the id column name in the Database
  static var idColumnName: String {get}
  /// Defines the id column type in the Database
  static var idColumnType: SQLDataType.Type {get}

  /// Call to create the table in the database synchronously
  static func createTableSync(using db: Database?) throws -> Bool

  /// Call to create the table in the database asynchronously
  static func createTable(using db: Database?, _ onCompletion: @escaping (Bool?, RequestError?) -> Void)

  /// Call to drop the table in the database synchronously
  static func dropTableSync(using db: Database?) throws -> Bool

  /// Call to drop the table in the database asynchronously
  static func dropTable(using db: Database?, _ onCompletion: @escaping (Bool?, RequestError?) -> Void)

  /// Call to save a model to the database that accepts a completion
  /// handler. The callback is passed a model or an error
  func save(using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)

  /// Call to save a model to the database that accepts a completion
  /// handler. The callback is passed an id, a model or an error
  func save<I: Identifier>(using db: Database?, _ onCompletion: @escaping (I?, Self?, RequestError?) -> Void)

  /// Call to update a model in the database with an id that accepts a completion
  /// handler. The callback is passed a updated model or an error
  func update<I: Identifier>(id: I, using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)

  /// Call to delete a model in the database with an id that accepts a completion
  /// handler. The callback is passed an optional error
  static func delete(id: Identifier, using db: Database?, _ onCompletion: @escaping (RequestError?) -> Void)

  /// Call to delete all the models in the database that accepts a completion
  /// handler. The callback is passed an optional error
  static func deleteAll(using db: Database?, _ onCompletion: @escaping (RequestError?) -> Void)

  /// Call to delete all the models in the database mathcing the QueryParams that accepts a completion
  /// handler. The callback is passed an optional error
  static func deleteAll<Q: QueryParams>(using db: Database?, matching queryParams:Q?, _ onCompletion: @escaping (RequestError?) -> Void)

  /// Call to get the table of the model
  static func getTable() throws -> Table

  /// Call to find a model in the database with an id that accepts a completion
  /// handler. The callback is passed the model or an error
  static func find<I: Identifier>(id: I, using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)

  /// Call to find all the models in the database that accepts a completion
  /// handler. The callback is passed an array of models or an error
  static func findAll(using db: Database?, order: Order..., offset: Int?, limit: Int?, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void)

  /// Call to find all the models in the database that accepts a completion
  /// handler. The callback is passed an array of tuples (id, model) or an error
  static func findAll<I: Identifier>(using db: Database?, order: Order..., offset: Int?, limit: Int?, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void)

  /// Call to find all the models in the database that accepts a completion
  /// handler. The callback is passed a dictionary [id: model] or an error
  static func findAll<I: Identifier>(using db: Database?, order: Order..., offset: Int?, limit: Int?, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void)

  /// Call to find all the models in the database matching the QueryParams that accepts a completion
  /// handler. The callback is passed an array of models or an error
  static func findAll<Q: QueryParams>(using db: Database?, matching queryParams: Q?, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void)

  /// Call to find all the models in the database matching the QueryParams that accepts a completion
  /// handler. The callback is passed an array of tuples (id, model) or an error
  static func findAll<Q: QueryParams, I: Identifier>(using db: Database?, matching queryParams: Q?, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void)

  /// Call to find all the models in the database matching the QueryParams that accepts a completion
  /// handler. The callback is passed a dictionary [id: model] or an error
  static func findAll<Q: QueryParams, I: Identifier>(using db: Database?, matching queryParams: Q?, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void)

}

public extension Model {
  /// Defaults to the name of the model + "s"
  static var tableName: String {
    let structName = String(describing: self)
    if structName.last == "s" {
      return structName
    }
    return structName + "s"
  }

  /// Defaults to "id"
  static var idColumnName: String { return "id" }
  /// Defaults to Int64
  static var idColumnType: SQLDataType.Type { return Int64.self }

  @discardableResult
  static func createTableSync(using db: Database? = nil) throws -> Bool {
    var result: Bool?
    var error: RequestError?
    let semaphore = DispatchSemaphore(value: 1)
    createTable(using: db) { res, err in
      result = res
      error = err
      semaphore.signal()
    }
    semaphore.wait()

    if let errorUnwrapped = error {
      throw errorUnwrapped
    }
    guard let resultUnwrapped = result else {
      throw RequestError(.ormInternalError, reason: "Database table creation function did not return expected result (both result and error were nil)")
    }

    return resultUnwrapped
  }

  static func createTable(using db: Database? = nil, _ onCompletion: @escaping (Bool?, RequestError?) -> Void) {
    var connection: Connection
    var table: Table
    do {
      connection = try Self.getConnection(using: db)
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        table.create(connection: connection) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }
          onCompletion(true, nil)
        }
      }
    }
  }

  @discardableResult
  static func dropTableSync(using db: Database? = nil) throws -> Bool {
    var result: Bool?
    var error: RequestError?
    let semaphore = DispatchSemaphore(value: 1)
    dropTable(using: db) { res, err in
      result = res
      error = err
      semaphore.signal()
    }
    semaphore.wait()

    if let errorUnwrapped = error {
      throw errorUnwrapped
    }
    guard let resultUnwrapped = result else {
      throw RequestError(.ormInternalError, reason: "Database table creation function did not return expected result (both result and error were nil)")
    }

    return resultUnwrapped
  }

  static func dropTable(using db : Database? = nil, _ onCompletion: @escaping (Bool?, RequestError?) -> Void) {
    var connection: Connection
    var table: Table
    do {
      table = try Self.getTable()
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: table.drop()) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }
          onCompletion(true, nil)
        }
      }
    }
  }

  func save(using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    var table: Table
    var values: [String : Any]
    do {
      table = try Self.getTable()
      values = try DatabaseEncoder().encode(self)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let columns = table.columns.filter({$0.autoIncrement != true && values[$0.name] != nil})
    let parameters: [Any?] = columns.map({values[$0.name]!})
    let parameterPlaceHolders: [Parameter] = parameters.map {_ in return Parameter()}
    let query = Insert(into: table, columns: columns, values: parameterPlaceHolders)
    self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  func save<I: Identifier>(using db: Database? = nil, _ onCompletion: @escaping (I?, Self?, RequestError?) -> Void) {
    var table: Table
    var values: [String : Any]
    do {
      table = try Self.getTable()
      values = try DatabaseEncoder().encode(self)
    } catch let error {
      onCompletion(nil, nil, Self.convertError(error))
      return
    }

    let columns = table.columns.filter({$0.autoIncrement != true && values[$0.name] != nil})
    let parameters: [Any?] = columns.map({values[$0.name]!})
    let parameterPlaceHolders: [Parameter] = parameters.map {_ in return Parameter()}
    let query = Insert(into: table, columns: columns, values: parameterPlaceHolders, returnID: true)
    self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  func update<I: Identifier>(id: I, using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    var table: Table
    var values: [String: Any]
    do {
      table = try Self.getTable()
      values = try DatabaseEncoder().encode(self)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let columns = table.columns.filter({$0.autoIncrement != true})
    var parameters: [Any?] = columns.map({values[$0.name]})
    let parameterPlaceHolders: [(Column, Any)] = columns.map({($0, Parameter())})
    guard let idColumn = table.columns.first(where: {$0.name == Self.idColumnName}) else {
      onCompletion(nil, RequestError(rawValue: 708, reason: "Could not find id column"))
      return
    }

    let query = Update(table, set: parameterPlaceHolders).where(idColumn == Parameter())
    parameters.append(id.value)
    executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  static func delete(id: Identifier, using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(Self.convertError(error))
      return
    }

    guard let idColumn = table.columns.first(where: {$0.name == idColumnName}) else {
      onCompletion(RequestError(.ormNotFound, reason: "Could not find id column"))
      return
    }

    let query = Delete(from: table).where(idColumn == Parameter())
    let parameters: [Any?] = [id.value]
    Self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  static func deleteAll(using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(Self.convertError(error))
      return
    }

    let query = Delete(from: table)
    self.executeQuery(query: query, using: db, onCompletion)
  }

  /// Delete all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Returns: An optional RequestError
  static func deleteAll<Q: QueryParams>(using db: Database? = nil, matching queryParams: Q?, _ onCompletion: @escaping (RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(Self.convertError(error))
      return
    }

    var query: Delete = Delete(from: table)
    var parameters: [Any?]? = nil
    if let queryParams = queryParams {
      do {
        let values: [String: Any] = try QueryEncoder().encode(queryParams)
        if values.count < 1 {
          onCompletion(RequestError(.ormQueryError, reason: "Could not extract values for Query Parameters"))
        }
        let filterInfo = try Self.getFilter(values: values, table: table)
        if let filter = filterInfo.filter,
           let filterParameters = filterInfo.parameters {
          parameters = filterParameters
          query = query.where(filter)
        } else {
          onCompletion(RequestError(.ormQueryError, reason: "Value for Query Parameters found but could not be added to a database delete query"))
          return
        }
      } catch let error {
        onCompletion(Self.convertError(error))
        return
      }
    }
    Self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  internal func executeQuery(query: Query, parameters: [Any?], using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void ) {
    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query, parameters: parameters) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          onCompletion(self, nil)
        }
      }
    }
  }

  internal func executeQuery<I: Identifier>(query: Query, parameters: [Any?], using db: Database? = nil, _ onCompletion: @escaping (I?, Self?, RequestError?) -> Void ) {

    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, nil, Self.convertError(error))
      return
    }

    var dictionaryTitleToValue = [String: Any?]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query, parameters: parameters) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, nil, Self.convertError(error))
            return
          }

          guard let rows = result.asRows, rows.count > 0 else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Could not retrieve value for Query: \(String(describing: query))"))
            return
          }

          dictionaryTitleToValue = rows[0]

          guard let value = dictionaryTitleToValue[Self.idColumnName] else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Could not find return id"))
            return
          }

          guard let unwrappedValue: Any = value else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Return id is nil"))
            return
          }

          var identifier: I
          do {
            identifier = try I(value: String(describing: unwrappedValue))
          } catch {
            onCompletion(nil, nil, RequestError(.ormIdentifierError, reason: "Could not construct Identifier"))
            return
          }

          onCompletion(identifier, self, nil)
        }
      }
    }
  }

  internal static func executeQuery(query: Query, parameters: [Any?], using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void ) {
    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var dictionaryTitleToValue = [String: Any?]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query, parameters: parameters) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          guard let rows = result.asRows, rows.count > 0 else {
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve value for Query: \(String(describing: query))"))
            return
          }

          dictionaryTitleToValue = rows[0]

          var decodedModel: Self
          do {
            decodedModel = try DatabaseDecoder().decode(Self.self, dictionaryTitleToValue)
          } catch {
            onCompletion(nil, Self.convertError(error))
            return
          }

          onCompletion(decodedModel, nil)
        }
      }
    }
  }

  internal static func executeQuery<I: Identifier>(query: Query, parameters: [Any?], using db: Database? = nil, _ onCompletion: @escaping (I?, Self?, RequestError?) -> Void ) {
    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, nil, Self.convertError(error))
      return
    }

    var dictionaryTitleToValue = [String: Any?]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query, parameters: parameters) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, nil, Self.convertError(error))
            return
          }

          guard let rows = result.asRows, rows.count > 0 else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Could not retrieve value for Query: \(String(describing: query))"))
            return
          }

          dictionaryTitleToValue = rows[0]

          guard let value = dictionaryTitleToValue[Self.idColumnName] else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Could not find return id"))
            return
          }

          guard let unwrappedValue: Any = value else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Return id is nil"))
            return
          }

          var identifier: I
          do {
            identifier = try I(value: String(describing: unwrappedValue))
          } catch {
            onCompletion(nil, nil, RequestError(.ormIdentifierError, reason: "Could not construct Identifier"))
            return
          }

          var decodedModel: Self
          do {
            decodedModel = try DatabaseDecoder().decode(Self.self, dictionaryTitleToValue)
          } catch {
            onCompletion(nil, nil, Self.convertError(error))
            return
          }

          onCompletion(identifier, decodedModel, nil)
        }
      }
    }
  }

  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple ([Model], RequestError)
  internal static func executeQuery(query: Query, parameters: [Any?]? = nil, using db: Database? = nil, _ onCompletion: @escaping ([Self]?, RequestError?)-> Void ) {
    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        let executeCompletion = { (result: QueryResult) in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          if case QueryResult.successNoData = result {
            onCompletion([], nil)
            return
          }

          guard let rows = result.asRows else {
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName)))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var list = [Self]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
              onCompletion(nil, Self.convertError(error))
              return
            }

            list.append(decodedModel)
          }

          onCompletion(list, nil)
        }

        if let parameters = parameters {
         connection.execute(query: query, parameters: parameters, onCompletion: executeCompletion)
        } else {
         connection.execute(query: query, onCompletion: executeCompletion)
        }
      }
    }
  }

  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple ([Model], RequestError)
  internal static func executeQuery<I: Identifier>(query: Query, parameters: [Any?]? = nil, using db: Database? = nil, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void ) {
    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        let executeCompletion = { (result: QueryResult) in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          if case QueryResult.successNoData = result {
            onCompletion([], nil)
            return
          }

          guard let rows = result.asRows else {
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName)))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [(I, Self)]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch let error {
              onCompletion(nil, Self.convertError(error))
              return
            }

            guard let value = dictionary[idColumnName] else {
              onCompletion(nil, RequestError(.ormNotFound, reason: "Could not find return id"))
              return
            }

            guard let unwrappedValue: Any = value else {
              onCompletion(nil, RequestError(.ormNotFound, reason: "Return id is nil"))
              return
            }

            do {
              let identifier = try I(value: String(describing: unwrappedValue))
              result.append((identifier, decodedModel))
            } catch {
              onCompletion(nil, RequestError(.ormIdentifierError, reason: "Could not construct Identifier"))
            }
          }
          onCompletion(result, nil)
        }

        if let parameters = parameters {
          connection.execute(query: query, parameters: parameters, onCompletion: executeCompletion)
        } else {
          connection.execute(query: query, onCompletion: executeCompletion)
        }
      }
    }
  }

  /// - Parameter using: Optional Database to use
  /// - Returns: An optional RequestError

  internal static func executeQuery(query: Query, parameters: [Any?]? = nil, using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void ) {
    var connection: Connection
    do {
      connection = try Self.getConnection(using: db)
    } catch let error {
      onCompletion(Self.convertError(error))
      return
    }

    connection.connect {error in
      if let error = error {
        onCompletion(Self.convertError(error))
        return
      } else {
        let executeCompletion = { (result: QueryResult) in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(Self.convertError(error))
            return
          }
          onCompletion(nil)
        }

        if let parameters = parameters {
          connection.execute(query: query, parameters: parameters, onCompletion: executeCompletion)
        } else {
          connection.execute(query: query, onCompletion: executeCompletion)
        }
      }
    }
  }

  static func getTable() throws -> Table {
    return try Database.tableInfo.getTable((Self.idColumnName, Self.idColumnType), Self.tableName, for: Self.self)
  }

  /**
    This functions accepts a Select query, an instance of QueryParams and the database table.
    It returns the updated Select query containing the filtering values extracted from the QueryParameters and the parameters to inject in the SQL Query (this is to prevent SQL Injection)
  */
  private static func getSelectQueryWithFilters<Q: QueryParams>(query: Select, queryParams: Q, table: Table) throws -> (query: Select, parameters: [Any?]?) {
      let values: [String: Any] = try QueryEncoder().encode(queryParams)
      if values.count < 1 {
        throw RequestError(.ormQueryError, reason: "Could not extract values for Query Parameters")
      }
      let filterInfo = try Self.getFilter(values: values, table: table)
      let order: [OrderBy] = Self.getOrderBy(values: values, table: table)
      let pagination = Self.getPagination(values: values)

      var resultQuery = query
      var parameters: [Any?]? = nil
      var success = false
      if let filter = filterInfo.filter,
         let filterParameters = filterInfo.parameters {
        parameters = filterParameters
        resultQuery = resultQuery.where(filter)
        success = true
      }

      if order.count > 0 {
        resultQuery = resultQuery.order(by: order)
        success = true
      }

      if let pagination = pagination {
        resultQuery = resultQuery.limit(to: pagination.limit).offset(pagination.offset)
        success = true
      }

      if !success {
        throw RequestError(.ormQueryError, reason: "QueryParameters found but failed construct database query")
      }
      return (resultQuery, parameters)
  }

  /// This function converts the Query Parameter into a Filter used in SwiftKuery
  /// Parameters:
  /// - A generic QueryParams instance
  /// - A Table instance
  /// Steps:
  /// 1 - Convert the values in the QueryParams to a dictionary of String to String
  /// 2 - Construct an array of tuples (Column, Operator, Value)
  /// 3 - Verify that we have at least one tuple, else return nil
  /// 4 - Iterate through the tuples
  /// 5 - Remove the first tuple and create a filter with the getOperation() function
  /// 6 - If the array still as tuples, iterate through them and append a new filter (column == value) with an AND operator
  /// 7 - Finally, return the Filter

  private static func getFilter(values: [String: Any], table: Table) throws -> (filter: Filter?, parameters: [Any?]?) {
    var columnsToValues: [(column: Column, opr: Operator, value: String)] = []

    for column in table.columns {
      if let value = values[column.name] {
        var stringValue = String(describing: value)
        var opr: Operator = .equal
        if let operation = value as? KituraContracts.Operation {
          opr = operation.getOperator()
          stringValue = operation.getStringValue()
        } else if var array = value as? Array<Any> {
          opr = .or
          stringValue = String(describing: array.removeFirst())
          for val in array {
            stringValue += ",\(val)"
          }
        }
        columnsToValues.append((column, opr, stringValue))
      }
    }

    if columnsToValues.count < 1 {
      return (nil, nil)
    }

    let firstTuple = columnsToValues.removeFirst()
    let resultTuple = try extractFilter(firstTuple.column, firstTuple.opr, firstTuple.value)
    var filter = resultTuple.filter
    var parameters: [Any?] = resultTuple.parameters

    for (column, opr, value) in columnsToValues {
      let resultTuple = try extractFilter(column, opr, value)
      parameters.append(contentsOf: resultTuple.parameters)
      filter = filter && resultTuple.filter
    }

    return (filter, parameters)
  }

  /**
    This function creates the appropriate Filter from a Column , an Operator and a String value
  */

  private static func extractFilter(_ column: Column, _ opr: Operator, _ value: String) throws -> (filter: Filter, parameters: [Any?]) {
      let filter: Filter
      var parameters: [Any?] = [value]
      switch opr {
      case .equal:
          filter = (column == Parameter())
      case .greaterThan:
          filter = (column > Parameter())
      case .greaterThanOrEqual:
          filter = (column >= Parameter())
      case .lowerThan:
          filter = (column < Parameter())
      case .lowerThanOrEqual:
          filter = (column <= Parameter())
      case .inclusiveRange:
          let array = value.split(separator: ",")
          if array.count == 2 {
            filter = (column >= Parameter()) && (column <= Parameter())
            parameters = array.map { String($0) }
          } else {
            throw RequestError(.ormQueryError, reason: "Could not extract values for Query Parameters")
          }
      case .exclusiveRange:
          let array = value.split(separator: ",")
          if array.count == 2 {
            filter = (column > Parameter()) && (column < Parameter())
            parameters = array.map { String($0) }
          } else {
            throw RequestError(.ormQueryError, reason: "Could not extract values for Query Parameters")
          }
      case .or:
          let array = value.split(separator: ",")
          if array.count > 1 {
            var newFilter: Filter = (column == Parameter())
            for _ in array {
              newFilter = newFilter || (column == Parameter())
            }
            filter = newFilter
            parameters = array.map { String($0) }
          } else {
            filter = (column == Parameter())
          }
      }

      return (filter, parameters)
  }

  /**
    This function extracts the pagination values from the QueryParameters values
  */
  private static func getPagination(values: [String: Any]) -> (limit: Int, offset: Int)? {
    var result: (limit: Int, offset: Int)? = nil
    for (_, value) in values {
       if let pagValue = value as? Pagination {
         let pagValues = pagValue.getValues()
         result = (limit: pagValues.size, offset: pagValues.start)
       }
    }

    return result
  }

  /**
    This function constructs an array of OrderBy from the QueryParameters or the Order values
  */
  private static func getOrderBy(values: [String: Any]? = nil, order: [Order]? = nil, table: Table) -> [OrderBy] {
    var orderByArray: [OrderBy] = []
    var orders: [Order] = []
    let columnDictionary = table.columns.reduce(into: [String: Column]()) { dict, value in
        dict[value.name] = value
    }

    if let order = order {
        orders = order
    } else if let values = values {
      for (_, value) in values {
        if let orderValue = value as? Ordering {
          orders = orderValue.getValues()
        }
      }
    }

    for order in orders where columnDictionary[order.value] != nil {
      let column = columnDictionary[order.value]!
      if case .asc(_) = order {
        orderByArray.append(.ASC(column))
      } else {
        orderByArray.append(.DESC(column))
      }
    }

    return orderByArray
  }

  private static func convertError(_ error: Error) -> RequestError {
    switch error {
    case let requestError as RequestError:
      return requestError
    case let queryError as QueryError:
      return RequestError(.ormQueryError, reason: String(describing: queryError))
    case let decodingError as DecodingError:
      return RequestError(.ormCodableDecodingError, reason: String(describing: decodingError))
    default:
      return RequestError(.ormInternalError, reason: String(describing: error))
    }
  }

  private static func getConnection(using db: Database? = nil) throws -> Connection {
    guard let database = db ?? Database.default else {
      throw RequestError.ormDatabaseNotInitialized
    }

    guard let connection = database.getConnection() else {
      throw RequestError.ormConnectionFailed
    }

    return connection
  }
  /// Find a model with an id
  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple (Model, RequestError)
  static func find<I: Identifier>(id: I, using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    guard let idColumn = table.columns.first(where: {$0.name == Self.idColumnName}) else {
      onCompletion(nil, RequestError(.ormInvalidTableDefinition, reason: "Could not find id column"))
      return
    }

    let query = Select(from: table).where(idColumn == Parameter())
    let parameters: [Any?] = [id.value]
    Self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }


  ///
  static func findAll(using db: Database? = nil, order: Order..., offset: Int? = nil, limit: Int? = nil, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }
    let orderBy: [OrderBy] = Self.getOrderBy(order: order, table: table)

    var query = Select(from: table)
    if orderBy.count > 0 {
        query = query.order(by: orderBy)
    }
    if let offset = offset {
        query = query.offset(offset)
    }
    if let limit = limit {
        query = query.limit(to: limit)
    }

    Self.executeQuery(query: query, using: db, onCompletion)
  }

  /// Find all the models
  /// - Parameter using: Optional Database to use
  /// - Returns: An array of tuples (id, model)
  static func findAll<I: Identifier>(using db: Database? = nil, order: Order..., offset: Int? = nil, limit: Int? = nil, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }
    let orderBy: [OrderBy] = Self.getOrderBy(order: order, table: table)

    var query = Select(from: table)
    if orderBy.count > 0 {
        query = query.order(by: orderBy)
    }
    if let offset = offset {
        query = query.offset(offset)
    }
    if let limit = limit {
        query = query.limit(to: limit)
    }

    Self.executeQuery(query: query, using: db, onCompletion)
  }

  /// :nodoc:
  static func findAll<I: Identifier>(using db: Database? = nil, order: Order..., offset: Int? = nil, limit: Int? = nil, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }
    let orderBy: [OrderBy] = Self.getOrderBy(order: order, table: table)

    var query = Select(from: table)
    if orderBy.count > 0 {
        query = query.order(by: orderBy)
    }
    if let offset = offset {
        query = query.offset(offset)
    }
    if let limit = limit {
        query = query.limit(to: limit)
    }

    Self.executeQuery(query: query, using: db) { (tuples: [(I, Self)]?, error: RequestError?) in
      if let error = error {
        onCompletion(nil, error)
        return
      } else if let tuples = tuples {
        var result = [I: Self]()
        for (id, model) in tuples {
          result[id] = model
        }
        onCompletion(result, nil)
        return
      } else {
        onCompletion(nil, .ormInternalError)
      }
    }
  }

  /// - Parameter matching: Optional QueryParams to use
  /// - Returns: An array of model
  static func findAll<Q: QueryParams>(using db: Database? = nil, matching queryParams: Q? = nil, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var query: Select = Select(from: table)
    var parameters: [Any?]? = nil
    if let queryParams = queryParams {
      do {
        (query, parameters) = try getSelectQueryWithFilters(query: query, queryParams: queryParams, table: table)
      } catch let error {
        onCompletion(nil, Self.convertError(error))
        return
      }
    }
    Self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  /// Find all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Returns: An array of tuples (id, model)
  static func findAll<Q: QueryParams, I: Identifier>(using db: Database? = nil, matching queryParams: Q? = nil, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var query: Select = Select(from: table)
    var parameters: [Any?]? = nil
    if let queryParams = queryParams {
      do {
        (query, parameters) = try getSelectQueryWithFilters(query: query, queryParams: queryParams, table: table)
      } catch let error {
        onCompletion(nil, Self.convertError(error))
        return
      }
    }
    Self.executeQuery(query: query, parameters: parameters, using: db, onCompletion)
  }

  /// Find all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Returns: A dictionary [id: model]
  static func findAll<Q:QueryParams, I: Identifier>(using db: Database? = nil, matching queryParams: Q? = nil, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var query: Select = Select(from: table)
    var parameters: [Any?]? = nil
    if let queryParams = queryParams {
      do {
        (query, parameters) = try getSelectQueryWithFilters(query: query, queryParams: queryParams, table: table)
      } catch let error {
        onCompletion(nil, Self.convertError(error))
        return
      }
    }

    Self.executeQuery(query: query, parameters: parameters, using: db) { (tuples: [(I, Self)]?, error: RequestError?) in
      if let error = error {
        onCompletion(nil, error)
        return
      } else if let tuples = tuples {
        var result = [I: Self]()
        for (id, model) in tuples {
          result[id] = model
        }
        onCompletion(result, nil)
        return
      } else {
        onCompletion(nil, .ormInternalError)
      }
    }
  }
}

/**
 Extension of the RequestError from [KituraContracts](https://github.com/IBM-Swift/KituraContracts.git)
 */
extension RequestError {
  init(_ base: RequestError, reason: String) {
    self.init(rawValue: base.rawValue, reason: reason)
  }
  /// Error when the Database has not been set
  public static let ormDatabaseNotInitialized = RequestError(rawValue: 700, reason: "Database not Initialized")
  /// Error when the createTable call fails
  public static let ormTableCreationError = RequestError(rawValue: 701)
  /// Error when the TypeDecoder failed to extract the types from the model
  public static let ormCodableDecodingError = RequestError(rawValue: 702)
  /// Error when the DatabaseDecoder could not construct a Model
  public static let ormDatabaseDecodingError = RequestError(rawValue: 703)
  /// Error when the DatabaseEncoder could not decode a Model
  public static let ormDatabaseEncodingError = RequestError(rawValue: 704)
  /// Error when the Query fails to be executed
  public static let ormQueryError = RequestError(rawValue: 706)
  /// Error when the values retrieved from the database are nil
  public static let ormNotFound = RequestError(rawValue: 707)
  /// Error when the table defined does not contain a specific column
  public static let ormInvalidTableDefinition = RequestError(rawValue: 708)
  /// Error when the Identifier could not be constructed
  public static let ormIdentifierError = RequestError(rawValue: 709)
  /// Error when an internal error occurs
  public static let ormInternalError = RequestError(rawValue: 710)
  /// Error when retrieving a connection from the database fails
  public static let ormConnectionFailed = RequestError(rawValue: 711, reason: "Failed to retrieve a connection from the database")
}
