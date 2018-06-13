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
import Foundation

/// Class caching the tables for the models of the application

public class TableInfo {
  private var codableMap = [String: (info: TypeInfo, table: Table, nestedTables: [Table])]()

  /// Get the table for a model
  func getTable<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, for type: T.Type) throws -> Table {
    return try getInfo(idColumn, tableName, type).table
  }

  /// Get the table for a model
  func getNestedTables<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, for type: T.Type) throws -> [Table] {
    return try getInfo(idColumn, tableName, type).nestedTables
  }

  func getInfo<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, _ type: T.Type) throws -> (info: TypeInfo, table: Table, nestedTables: [Table]) {
    if codableMap["\(type)"] == nil {
      let typeInfo = try TypeDecoder.decode(type)
      let tableInfo = try constructTable(idColumn, tableName, typeInfo)
      codableMap["\(type)"] = (info: typeInfo, table: tableInfo.table, tableInfo.nestedTables)
    }
    return codableMap["\(type)"]!
  }

  /// Construct the table for a Model
  func constructTable(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, _ typeInfo: TypeInfo, _ parentTableName: String? = nil) throws -> (table: Table, nestedTables: [Table]) {
    var columns: [Column] = []
    var nestedTables: [Table] = []
    var idColumnIsSet = false

    switch typeInfo {
    case .keyed(_, let dict):
      for (key, value) in dict {
        var keyedTypeInfo = value
        var optionalBool = false
        var noColumn = false
        if case .optional(let optionalType) = keyedTypeInfo {
          optionalBool = true
          keyedTypeInfo = optionalType
        }
        var valueType: Any? = nil
        switch keyedTypeInfo {
        case .single(_ as UUID.Type, _):
          valueType = UUID.self
        case .single(_, let singleType):
          valueType = singleType
          if valueType is Int.Type {
            valueType = Int64.self
          }
        case .unkeyed(_ as Data.Type, _):
          valueType = String.self
        case .keyed(_ as URL.Type, _):
          valueType = String.self
        case .keyed:
          throw RequestError(.ormTableCreationError, reason: "Nested structs or dictionaries are not supported")
        case .unkeyed(let type, let typeInfo):
          /*
          let tableInfoUnKeyed = try? constructTable((name: "id", type: idColumn.type), key, value)

          var error: Error? = nil
          createNestedTable(table: table!) { returnedError in 
            error = returnedError
          }
          if let error = error {
            throw error
          }
          nestedTables.append(tableInfo.table)
          foreignKey = table.*/
          throw RequestError(.ormTableCreationError, reason: "Arrays or sets are not supported")
        case .dynamicKeyed(_, _, _):
          let tableInfoDictionary = try constructTable((name: "id", type: idColumn.type), key, value, tableName)

          nestedTables.append(tableInfoDictionary.table)
          tableInfoDictionary.nestedTables.forEach { table in
            nestedTables.append(table)
          }

          valueType = idColumn.type
          noColumn = true
        default:
          throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: keyedTypeInfo)) is not supported")
        }
        if !noColumn {
          if let SQLType = valueType as? SQLDataType.Type {
            if key == idColumn.name && !idColumnIsSet {
              columns.append(Column(key, SQLType, primaryKey: true, notNull: !optionalBool))
              idColumnIsSet = true
            } else {
              let column = Column(key, SQLType, notNull: !optionalBool)
              columns.append(column)
            }
          } else {
            throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of Key: \(String(describing: key)) is not a SQLDataType")
          }
        }
      }
    case .unkeyed(_, let tableInfo):
      var valueType: Any? = nil
      switch tableInfo {
      case .single(_, let singleType):
        valueType = singleType
      default: 
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: typeInfo)) is not supported")
      }

      if let SQLType = valueType as? SQLDataType.Type {
        columns.append(Column("value", SQLType))
      } else {
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of Key: \(String(describing: "value")) is not a SQLDataType")
      }
    case .dynamicKeyed(_, let key, let value):
      var keyValueType: Any? = nil
      var valueType: Any? = nil

      switch key {
      case .single(_, let singleType):
        keyValueType = singleType
        if keyValueType is Int.Type {
          keyValueType = Int64.self
        }
      default: 
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: typeInfo)) is not supported")
      }

      if let SQLType = keyValueType as? SQLDataType.Type {
        columns.append(Column("\(tableName)_key", SQLType))
      } else {
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of Key: \(String(describing: "value")) is not a SQLDataType")
      }

      switch value {
      case .single(_, let singleType):
        valueType = singleType
        if valueType is Int.Type {
          valueType = Int64.self
        }
      default: 
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: typeInfo)) is not supported")
      }

      if let SQLType = valueType as? SQLDataType.Type {
        columns.append(Column("\(tableName)_value", SQLType))
      } else {
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of Key: \(String(describing: "value")) is not a SQLDataType")
      }

      let modelIdColumnName = parentTableName ?? "Model_id"
      columns.append(Column(modelIdColumnName, idColumn.type))
    default:
      //TODO enhance error message
      throw RequestError(.ormTableCreationError, reason: "Can only save a struct to the database")
    }
    if !idColumnIsSet {
      columns.append(Column(idColumn.name, idColumn.type, autoIncrement: true, primaryKey: true))
    }

    var table = Table(tableName: tableName, columns: columns)
    return (table: table, nestedTables: nestedTables)
  }

  private func createNestedTable(table: Table, completion: @escaping (Error?) -> Void) {
    guard let database = Database.default else {
      completion(RequestError.ormDatabaseNotInitialized)
      return
    }

    guard let connection = database.getConnection() else {
      completion(RequestError.ormConnectionFailed)
      return
    }

    connection.connect { error in
      if let error = error {
        completion(error)
      } else {
        table.create(connection: connection) { result in
          guard result.success else {
            guard let error = result.asError else {
              completion(QueryError.databaseError("Query failed to execute but error was nil"))
              return
            }
            completion(error)
            return
          }
        }
      }
    }
  }
}
