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

import KituraContracts
import SwiftKuery

/// Protocol IdentifiedModel conforming to Model defining the available operations
public protocol IdentifiedModel: Model {
  associatedtype I: Identifier

  /// id field to be declared by the user
  var id: I? { get set }

  /// Find method to be called on an instance
  func find(using db: Database?, _ onCompletion: @escaping (Self?, RequestError?) -> Void)

  /// Delete method to be called on an instance
  func delete(using db: Database?, _ onCompletion: @escaping (RequestError?) -> Void)
}

public extension IdentifiedModel {

  // Default implementation of save call which itself calls the save method in Model returning
  // (Identifier?, Model, RequestError?)
  // Then makes a copy of the model and sets the id of that copy. Finally, call the
  // completion with the model and the error
  func save(using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    save(using: db) { (id: I?, model: Self?, error: RequestError?) in
      if let error = error {
        onCompletion(nil, error)
        return
      }

      if var identifiedModel = model,
         let id = id {
        identifiedModel.id = id
        onCompletion(identifiedModel, error)
        return
      }

      onCompletion(nil, RequestError( .ormInternalError, reason: "Save Failed but no error found"))
    }
  }

  // Default implementation of find which itself calls the find method in Model returning
  // (Model?, RequestError?) with the id
  // Then makes a copy of the model and sets the id of that copy. Finally, call the
  // completion with the model and the error
  func find(using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) {
    if let id = self.id {
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
    } else {
      onCompletion(nil, RequestError( .ormIdentifierError, reason: "Find Failed: id not found! Please save before finding"))
    }
  }


  // Default implementation of update which itself calls the update method in Model returning
  // (Model?, RequestError?)
  func update(using db: Database? = nil, _ onCompletion: @escaping (Self?, RequestError?) -> Void) { 
    if let id = self.id {
      update(id: id, using: db) { (_: Self?, error: RequestError?) in
        if let error = error {
          onCompletion(nil, error)
          return
        }

        onCompletion(self, nil)
      }
    } else {
      onCompletion(nil, RequestError( .ormIdentifierError, reason: "Update Failed: id not found! Please save before updating"))
    }
  }


  // Default implementation of delete which itself calls the delete method in Model returning
  // (RequestError?)
  func delete(using db: Database? = nil, _ onCompletion: @escaping (RequestError?) -> Void) {
    if let id = self.id {
      Self.delete(id: id, using: db) { (error: RequestError?) in
        onCompletion(error)
      }
    } else {
      onCompletion(RequestError( .ormIdentifierError, reason: "Delete Failed: id not found! Please save before deleting"))
    }
  }

  static func findAll(using db: Database? = nil, _ onCompletion: @escaping ([Self]?, RequestError?) -> Void) {
    var table: Table
    do {
      table = try Self.getTable()
    } catch let error {
      onCompletion(nil, Self.convertError(error))
      return
    }

    let query = Select(from: table)
    Self.executeQuery(query: query, using: db, onCompletion)
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

          if self.idColumnName != "id" && dictionaryTitleToValue[self.idColumnName] != nil {
            dictionaryTitleToValue["id"] = dictionaryTitleToValue[self.idColumnName]
            dictionaryTitleToValue[self.idColumnName] = nil
          }

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
          for var dictionary in dictionariesTitleToValue {
            var decodedModel: Self

            if self.idColumnName != "id" && dictionary[self.idColumnName] != nil {
              dictionary["id"] = dictionary[self.idColumnName]
              dictionary[self.idColumnName] = nil
            }

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

  static func findAll<I: Identifier>(using db: Database? = nil, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void) {
    onCompletion(nil, RequestError(.ormNotAvailable, reason: "Method not available for IdentifiedModel. Identifier is embedded within the object"))
  }

  static func findAll<I: Identifier>(using db: Database? = nil, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void) {
    onCompletion(nil, RequestError(.ormNotAvailable, reason: "Method not available for IdentifiedModel. Identifier is embedded within the object."))
  }

  static func findAll<Q: QueryParams, I: Identifier>(using db: Database? = nil, matching queryParams: Q? = nil, _ onCompletion: @escaping ([(I, Self)]?, RequestError?) -> Void) {
    onCompletion(nil, RequestError(.ormNotAvailable, reason: "Method not available for IdentifiedModel. Identifier is embedded within the object"))
  }

  static func findAll<Q: QueryParams, I: Identifier>(using db: Database? = nil, matching queryParams: Q? = nil, _ onCompletion: @escaping ([I: Self]?, RequestError?) -> Void) {
    onCompletion(nil, RequestError(.ormNotAvailable, reason: "Method not available for IdentifiedModel. Identifier is embedded within the object"))
  }
}

