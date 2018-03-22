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

public typealias RequestError = KituraContracts.RequestError

public protocol Model: Codable {
  static var tableName: String {get}
  static var idColumnName: String {get}

  static func createTableSync(using db: Database?) throws -> Bool
  static func createTable(using db: Database?, _ onCompletion: @escaping (Bool?, RequestError?) -> Void)
  static func dropTableSync(using db: Database?) throws -> Bool
  static func dropTable(using db: Database?, _ onCompletion: @escaping (Bool?, RequestError?) -> Void)

  func save(using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)
  func save<I: Identifier>(using db: Database?, _ onCompletion: @escaping (I?, Self?, RequestError?) -> Void)

  static func find<I: Identifier>(id: I, using db: Database?, onCompletion: @escaping (Self?, RequestError?) -> Void)
  static func findAll(using db: Database?, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void)
  static func findAll<I: Identifier>(using db: Database?, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void)
  static func findAll<I: Identifier>(using db: Database?, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void)

  func update<I: Identifier>(id: I, using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)

  static func delete(id: Identifier, using db: Database?, _ onCompletion: @escaping (RequestError?) -> Void)
  static func deleteAll(using db: Database?, _ onCompletion: @escaping (RequestError?) -> Void)

  static func getTable() throws -> Table
}

public extension Model {
  /// Default implementation of the table name
  static var tableName: String {
    let structName = String(describing: self)
    if structName.last == "s" {
      return structName
    }
    return structName + "s"
  }

  /// Default implementation of id column name
  static var idColumnName: String { return "id" }


  /// Synchronous function creating the table in the database
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

  /// Asynchronous function creating the table in the database
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


  /// Synchronous function droping the table from the database
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

  /// Asynchronous function droping the table from the database
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

  /// Save a instance of model to the database : `model.save()`
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

  /// Save a instance of model to the database : `model.save()` and 
  /// get back the auto incrementing id value
  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple (Identifier, Model, RequestError)
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
  static func find<I: Identifier>(id: I, using db: Database? = nil, onCompletion: @escaping (Self?, RequestError?) -> Void) {
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

  /// Find all the models
  /// - Parameter using: Optional Database to use
  /// - Returns: An array of model
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

  /// Find all the models
  /// - Parameter using: Optional Database to use
  /// - Returns: A dictionary [id: model]
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

  /// Update a model
  /// - Parameter id: Identifier of the model to update
  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple (model, error)
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

  /// Delete a model
  /// - Parameter id: Identifier of the model to delete
  /// - Parameter using: Optional Database to use
  /// - Returns: An optional RequestError
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

    guard let idColumn = table.columns.first(where: {$0.name == "id"}) else {
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

  /// Delete all the models
  /// - Parameter using: Optional Database to use
  /// - Returns: An optional RequestError
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

  static func getTable() throws -> Table {
    return try Database.tableInfo.getTable(Self.idColumnName, Self.tableName, for: Self.self)
  }

  /// - Parameter using: Optional Database to use
  /// - Returns: A tuple (Model, RequestError)
  static func executeQuery(query: Query, using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void ) {
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
  static func executeQuery(query: Query, using db: Database? = nil, _ onCompletion: @escaping ([Self]?, RequestError?)-> Void ) {
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
  static func executeQuery(using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void ) {
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

//TODO Kitura should update to convert 7XX into 500
extension RequestError {
  init(_ base: RequestError, reason: String) {
    self.init(rawValue: base.rawValue, reason: reason)
  }
  public static let ormDatabaseNotInitialized = RequestError(rawValue: 700, reason: "Database not Initialized")
  public static let ormTableCreationError = RequestError(rawValue: 701)
  public static let ormCodableDecodingError = RequestError(rawValue: 702)
  public static let ormDatabaseDecodingError = RequestError(rawValue: 703)
  public static let ormDatabaseEncodingError = RequestError(rawValue: 704)
  public static let ormQueryError = RequestError(rawValue: 706)
  public static let ormNotFound = RequestError(rawValue: 707)
  public static let ormInvalidTableDefinition = RequestError(rawValue: 708)
  public static let ormIdentifierError = RequestError(rawValue: 709)
  public static let ormInternalError = RequestError(rawValue: 710)
  public static let ormConnectionFailed = RequestError(rawValue: 711, reason: "Failed to retrieve a connection from the database")
}
