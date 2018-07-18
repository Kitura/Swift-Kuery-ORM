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
  private var codableMap = [String: (info: TypeInfo, table: Table, nestedInfo: [NestedType])]()

  /// Get the table for a model
  func getTable<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, for type: T.Type) throws -> Table {
    return try getInfo(idColumn, tableName, type).table
  }

  /// Get the table for a model
  func getNestedInfo<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, for type: T.Type) throws -> [NestedType] {
    return try getInfo(idColumn, tableName, type).nestedInfo
  }

  func getInfo<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, _ type: T.Type) throws -> (info: TypeInfo, table: Table, nestedInfo: [NestedType]) {
    if codableMap["\(type)"] == nil {
      let typeInfo = try TypeDecoder.decode(type)
      let tableInfo = try constructTable(idColumn, tableName, typeInfo)
      codableMap["\(type)"] = (info: typeInfo, table: tableInfo.table, tableInfo.nestedInfo)
    }
    return codableMap["\(type)"]!
  }

  /// Construct the table for a Model
  func constructTable(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, _ typeInfo: TypeInfo, _ parentTableName: String? = nil) throws -> (table: Table, nestedInfo: [NestedType]) {
    var columns = [Column]()
    var nestedInfo = [NestedType]()
    var idColumnIsSet = false
    var foreignKeys = [Column]()
    var referencingForeignKeys = [Column]()

    switch typeInfo {
    case .keyed(_, let dict):
      for (key, value) in dict {
        var columnName = key
        var keyedTypeInfo = value
        var optionalBool = false
        var createColumn = true
        var isForeignKey = false

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
        case .keyed(let type, _):
          // TODO async locking
          guard let keyedInfo = codableMap["\(type)"] else {
            throw RequestError(.ormTableCreationError, reason: "Please create table for \(type) Model")
          }

          nestedModels.append(keyedInfo.table)
          createColumn = false
        case .unkeyed(_, _):
          throw RequestError(.ormTableCreationError, reason: "Arrays or sets are not supported")
        case .dynamicKeyed(_, _, _):
          let dictionaryTableName = "\(tableName)_\(key)"
          let tableInfoDictionary = try constructTable((name: "id", type: idColumn.type), dictionaryTableName, value, tableName)

          let nestedDictionaryTable = tableInfoDictionary.table
          let nestedDictionaryInfo = tableInfoDictionary.nestedInfo
          if nestedDictionaryInfo.count == 2 {}
          nestedInfo.append(.dictionary(nestedDictionaryTable, key, nestedDictionaryInfo,))

          valueType = idColumn.type
          createColumn = false
        default:
          throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: keyedTypeInfo)) is not supported")
        }

        if createColumn {
          if let SQLType = valueType as? SQLDataType.Type {
            var column: Column

            if key == idColumn.name && !idColumnIsSet {
              column = Column(columnName, SQLType, primaryKey: true, notNull: !optionalBool)
              idColumnIsSet = true
            } else {
              column = Column(columnName, SQLType, notNull: !optionalBool)
            }

            if isForeignKey { foreignKeys.append(column) }
            columns.append(column)
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
      case .single(_ as UUID.Type, _):
        keyValueType = UUID.self
      case .single(_, let singleType):
        keyValueType = singleType
        if keyValueType is Int.Type {
          keyValueType = Int64.self
        }
      case .unkeyed(_ as Data.Type, _):
        keyValueType = String.self
      case .keyed(_ as URL.Type, _):
        keyValueType = String.self
      default:
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: key)) for key in dictionary is not supported")
      }

      if let SQLType = keyValueType as? SQLDataType.Type {
        columns.append(Column("\(tableName)_key", SQLType))
      } else {
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of key in Dictionary is not a SQLDataType")
      }

      switch value {
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
      default: 
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: value)) for value in Dictionary is not supported")
      }

      if let SQLType = valueType as? SQLDataType.Type {
        columns.append(Column("\(tableName)_value", SQLType))
      } else {
        throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of value in Dictionary is not a SQLDataType")
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
    if foreignKeys.count > 0 && referencingForeignKeys.count > 0 {
      table = table.foreignKey(foreignKeys, references: referencingForeignKeys)
    }

    for nestedModelTable in nestedModels {
      let nestedModelTableName = nestedModelTable.nameInQuery
      guard let nestedModelIdColumn = nestedModelTable.columns.first(where: { $0.isPrimaryKey }) else {
        // TODO change error
        throw RequestError(.ormTableCreationError, reason: "Could not find ID column for \(nestedtModelTableName)")
      }

      guard let currentModelIdColumn = table.columns.first(where: { $0.isPrimaryKey }) else {
        // TODO change error
        throw RequestError(.ormTableCreationError, reason: "Could not find ID column for \(tableName)")
      }

      let relationshipTableName = "\(tableName)_\(nestedModelTableName)"
      let columns = [Column("\(tableName)_id", idColumn.type), Column("\(nestedModelTableName)_id", nestedModelIdColumn.type, isUnique: true)]
      let relationshipTable = Table(tableName: tableName, columns: columns).foreignkey(columns[0], currentModelIdColumn).foreignKey(columns[1], nestedModelIdColumn)
      nestedInfo.append(.model(nestedModelTable, relationshipTable, , ))
    }

    return (table: table, nestedInfo: nestedInfo)
  }
}
