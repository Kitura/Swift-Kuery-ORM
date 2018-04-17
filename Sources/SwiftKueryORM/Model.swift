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


/// Type Alias for RequestError from [KituraContracts](https://github.com/IBM-Swift/KituraContracts)
public typealias RequestError = KituraContracts.RequestError
/// Type Alias for QueryParams from [KituraContracts](https://github.com/IBM-Swift/KituraContracts)
public typealias QueryParams = KituraContracts.QueryParams

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

  /// Call to find a model in the database with an id that accepts a completion
  /// handler. The callback is passed the model or an error
  static func find<I: Identifier>(id: I, using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)

  /// Call to find all the models in the database that accepts a completion
  /// handler. The callback is passed an array of models or an error
  static func findAll(using db: Database?, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void)

  /// Call to find all the models in the database that accepts a completion
  /// handler. The callback is passed an array of tuples (id, model) or an error
  static func findAll<I: Identifier>(using db: Database?, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void)

  /// Call to find all the models in the database that accepts a completion
  /// handler. The callback is passed a dictionary [id: model] or an error
  static func findAll<I: Identifier>(using db: Database?, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void)

  /// Call to find all the models in the database matching the QueryParams that accepts a completion
  /// handler. The callback is passed an array of models or an error
  static func findAll<Q: QueryParams>(using db: Database?, matching queryParams: Q, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void)

  /// Call to find all the models in the database matching the QueryParams that accepts a completion
  /// handler. The callback is passed an array of tuples (id, model) or an error
  static func findAll<Q: QueryParams, I: Identifier>(using db: Database?, matching queryParams: Q, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void)

  /// Call to find all the models in the database matching the QueryParams that accepts a completion
  /// handler. The callback is passed a dictionary [id: model] or an error
  static func findAll<Q: QueryParams, I: Identifier>(using db: Database?, matching queryParams: Q, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void)

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
  static func deleteAll<Q: QueryParams>(using db: Database?, matching queryParams:Q, _ onCompletion: @escaping (RequestError?) -> Void)

  /// Call to get the table of the model
  static func getTable() throws -> Table
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
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    connection.connect() { error in
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
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
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
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var values: [String : Any]
    do {
      values = try DatabaseEncoder().encode(self)
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let columns = table.columns.filter({$0.autoIncrement != true})
    let valueTuples = columns.filter({values[$0.name] != nil}).map({($0, values[$0.name]!)})
    let query = Insert(into: table, valueTuples: valueTuples)

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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

  func save<I: Identifier>(using db: Database? = nil, _ onCompletion: @escaping (I?, Self?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, nil, Self.convertError(error))
      return
    }

    var values: [String : Any]
    do {
      values = try DatabaseEncoder().encode(self)
    } catch {
      onCompletion(nil, nil, Self.convertError(error))
      return
    }

    let columns = table.columns.filter({$0.autoIncrement != true})
    let valueTuples = columns.filter({values[$0.name] != nil}).map({($0, values[$0.name]!)})
    let query = Insert(into: table, valueTuples: valueTuples, returnID: true)

    connection.connect { error in
      if let error = error {
        onCompletion(nil, nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, nil, Self.convertError(error))
            return
          }

          guard let rows = result.asRows, rows.count > 0 else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Could not retrieve id value for: \(String(describing: self))"))
            return
          }

          let dict = rows[0]
          guard let value = dict[Self.idColumnName] else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Could not find return id"))
            return
          }

          guard let unwrappedValue: Any = value else {
            onCompletion(nil, nil, RequestError(.ormNotFound, reason: "Return id is nil"))
            return
          }

          do {
            let identifier = try I(value: String(describing: unwrappedValue))
            onCompletion(identifier, self, nil)
          } catch {
            onCompletion(nil, nil, RequestError(.ormIdentifierError, reason: "Could not construct Identifier"))
          }
        }
      }
    }
  }

  /// Find a model with an id
  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple (Model, RequestError)
  static func find<I: Identifier>(id: I, using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table

    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    guard let idColumn = table.columns.first(where: {$0.name == Self.idColumnName}) else {
      onCompletion(nil, RequestError(.ormInvalidTableDefinition, reason: "Could not find id column"))
      return
    }

    let query = Select(from: table).where(idColumn == id.value)
    var dictionaryTitleToValue = [String: Any?]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          guard let rows = result.asRows, rows.count > 0 else {
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve value for id: " + String(describing: id)))
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

  ///
  static func findAll(using db: Database? = nil, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table)
    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [Self]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
              onCompletion(nil, Self.convertError(error))
              return
            }
            result.append(decodedModel)
          }
          onCompletion(result, nil)
        }
      }
    }
  }

  /// Find all the models
  /// - Parameter using: Optional Database to use
  /// - Returns: An array of tuples (id, model)
  static func findAll<I: Identifier>(using db: Database? = nil, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table)
    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [(I,Self)]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
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
      }
    }
  }

  /// :nodoc:
  static func findAll<I: Identifier>(using db: Database? = nil, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table)
    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          if case QueryResult.successNoData = result {
            onCompletion([:], nil)
            return
          }

          guard let rows = result.asRows else {
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [I: Self]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
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
              result[identifier] = decodedModel
            } catch {
              onCompletion(nil, RequestError(.ormIdentifierError, reason: "Could not construct Identifier"))
            }
          }
          onCompletion(result, nil)
        }
      }
    }
  }

  /// Find all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Parameter matching: Optional QueryParams to use
  /// - Returns: An array of model
  static func findAll<Q: QueryParams>(using db: Database? = nil, matching queryParams: Q, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var filter: Filter
    do {
      filter = try Self.getFilter(queryParams: queryParams, table: table)
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table).where(filter)
    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [Self]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
              onCompletion(nil, Self.convertError(error))
              return
            }
            result.append(decodedModel)
          }
          onCompletion(result, nil)
        }
      }
    }
  }

  /// Find all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Returns: An array of tuples (id, model) 
  static func findAll<Q: QueryParams, I: Identifier>(using db: Database? = nil, matching queryParams: Q, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var filter: Filter
    do {
      filter = try Self.getFilter(queryParams: queryParams, table: table)
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table).where(filter)
    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [(I,Self)]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
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
      }
    }
  }

  /// Find all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Returns: A dictionary [id: model]
  static func findAll<Q:QueryParams, I: Identifier>(using db: Database? = nil, matching queryParams: Q, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var filter: Filter
    do {
      filter = try Self.getFilter(queryParams: queryParams, table: table)
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table).where(filter)
    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }

          if case QueryResult.successNoData = result {
            onCompletion([:], nil)
            return
          }

          guard let rows = result.asRows else {
            onCompletion(nil, RequestError(.ormNotFound, reason: "Could not retrieve values from table: \(String(describing: Self.tableName))"))
            return
          }

          for row in rows {
            dictionariesTitleToValue.append(row)
          }

          var result = [I: Self]()
          for dictionary in dictionariesTitleToValue {
            var decodedModel: Self
            do {
              decodedModel = try DatabaseDecoder().decode(Self.self, dictionary)
            } catch {
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
              result[identifier] = decodedModel
            } catch {
              onCompletion(nil, RequestError(.ormIdentifierError, reason: "Could not construct Identifier"))
            }
          }
          onCompletion(result, nil)
        }
      }
    }
  }

  func update<I: Identifier>(id: I, using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    var values: [String: Any]
    do {
      values = try DatabaseEncoder().encode(self)
    } catch {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let columns = table.columns.filter({$0.autoIncrement != true})
    let valueTuples = columns.filter({values[$0.name] != nil}).map({($0, values[$0.name]!)})
    guard let idColumn = table.columns.first(where: {$0.name == Self.idColumnName}) else {
      onCompletion(nil, RequestError(rawValue: 708, reason: "Could not find id column"))
      return
    }

    let query = Update(table, set: valueTuples).where(idColumn == id.value)

    connection.connect {error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
          guard result.success else {
            guard let error = result.asError else {
              onCompletion(nil, Self.convertError(QueryError.databaseError("Query failed to execute but error was nil")))
              return
            }
            onCompletion(nil, Self.convertError(error))
            return
          }
          onCompletion(self,nil)
        }
      }
    }
  }

  static func delete(id: Identifier, using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(.ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(.ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(Self.convertError(error))
      return
    }

    guard let idColumn = table.columns.first(where: {$0.name == idColumnName}) else {
      onCompletion(RequestError(.ormNotFound, reason: "Could not find id column"))
      return
    }

    let query = Delete(from: table).where(idColumn == id.value)

    connection.connect {error in
      if let error = error {
        onCompletion(Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
      }
    }
  }

  static func deleteAll(using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(.ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(.ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(Self.convertError(error))
      return
    }

    let query = Delete(from: table)

    connection.connect {error in
      if let error = error {
        onCompletion(Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
      }
    }
  }

  /// Delete all the models matching the QueryParams
  /// - Parameter using: Optional Database to use
  /// - Returns: An optional RequestError
  static func deleteAll<Q: QueryParams>(using db: Database? = nil, matching queryParams: Q, _ onCompletion: @escaping (RequestError?) -> Void) {
    guard let database = db ?? Database.default else {
      onCompletion(.ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(.ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(Self.convertError(error))
      return
    }

    var filter: Filter
    do {
      filter = try Self.getFilter(queryParams: queryParams, table: table)
    } catch {
      onCompletion(Self.convertError(error))
      return
    }

    let query = Delete(from: table).where(filter)

    connection.connect {error in
      if let error = error {
        onCompletion(Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
      }
    }
  }
  static func getTable() throws -> Table {
    return try Database.tableInfo.getTable((Self.idColumnName, Self.idColumnType), Self.tableName, for: Self.self)
  }

  internal static func executeQuery(query: Query, using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void ) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var dictionaryTitleToValue = [String: Any?]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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

  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple ([Model], RequestError)
  internal static func executeQuery(query: Query, using db: Database? = nil, _ onCompletion: @escaping ([Self]?, RequestError?)-> Void ) {
    guard let database = db ?? Database.default else {
      onCompletion(nil, .ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(nil, .ormConnectionFailed)
      return
    }

    var dictionariesTitleToValue = [[String: Any?]]()

    connection.connect { error in
      if let error = error {
        onCompletion(nil, Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
      }
    }
  }

  /// - Parameter using: Optional Database to use
  /// - Returns: An optional RequestError
  internal static func executeQuery(using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void ) {
    guard let database = db ?? Database.default else {
      onCompletion(.ormDatabaseNotInitialized)
      return
    }
    guard let connection = database.getConnection() else {
      onCompletion(.ormConnectionFailed)
      return
    }

    var table: Table
    do {
      table = try Self.getTable()
    } catch {
      onCompletion(Self.convertError(error))
      return
    }

    let query = Delete(from: table)

    connection.connect {error in
      if let error = error {
        onCompletion(Self.convertError(error))
        return
      } else {
        connection.execute(query: query) { result in
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
      }
    }
  }

  /// This function converts the Query Parameter into a Filter used in SwiftKuery
  /// Parameters:
  /// - A generic QueryParams instance
  /// - A Table instance
  /// Steps:
  /// 1 - Convert the values in the QueryParams to a dictionary of String to String
  /// 2 - Construct an array of tuples (Column, Value)
  /// 3 - Verify that we have at least one tuple
  /// 4 - Iterate through the tuples
  /// 5 - Remove the first tuple and create a filter
  /// 6 - If the array still as tuples, iterate through them and append a new filter (column == value) with an AND operator
  /// 7 - Finally, return the Filter

  private static func getFilter<Q: QueryParams>(queryParams: Q, table: Table) throws -> Filter {
    var queryDictionary: [String: String] = try QueryEncoder().encode(queryParams)

    var columnsToValues: [(column: Column, value: String)] = []
    for column in table.columns {
      if let value = queryDictionary[column.name] {
        columnsToValues.append((column, value))
      }
    }

    if columnsToValues.count < 1 {
      throw RequestError(.ormQueryError, reason: "Could not extract values for Query Parameters")
    }

    let firstTuple = columnsToValues.removeFirst()
    var filter: Filter = (firstTuple.column == firstTuple.value)
    for (column, value) in columnsToValues {
      filter = filter && (column == value)
    }
    return filter
  }

  private static func convertError(_ error: Error) -> RequestError {
    switch error {
    case let requestError as RequestError:
      return requestError
    case let queryError as QueryError:
      return RequestError(.ormQueryError, reason: String(describing: queryError))
    case let decodingError as DecodingError:
      return RequestError(.ormCodableDecodingError, reason: String(describing: decodingError))
    case let internalError as InternalError:
      return RequestError(.ormInternalError, reason: String(describing: internalError))
    default:
      return RequestError(.ormDatabaseDecodingError, reason: String(describing: error))
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
