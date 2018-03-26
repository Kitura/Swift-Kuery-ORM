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

/// Class caching all the tables for each model of the application
/// Gets used once for every model
public class TableInfo {
  private var codableMap = [String: (info: TypeInfo, table: Table)]()

  func getTable<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, for type: T.Type) throws -> Table {
    return try getInfo(idColumn, tableName, type).table
  }

  func getInfo<T: Decodable>(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, _ type: T.Type) throws -> (info: TypeInfo, table: Table) {
    if codableMap["\(type)"] == nil {
      let typeInfo = try TypeDecoder.decode(type)
      codableMap["\(type)"] = (info: typeInfo, table: try constructTable(idColumn, tableName, typeInfo))
    }
    return codableMap["\(type)"]!
  }

  func constructTable(_ idColumn: (name: String, type: SQLDataType.Type), _ tableName: String, _ typeInfo: TypeInfo) throws -> Table {
    var columns: [Column] = []
    var idColumnIsSet = false
    switch typeInfo {
    case .keyed(_, let dict):
      for (key, value) in dict {
        var keyedTypeInfo = value
        var optionalBool = false
        if case .optional(let optionalType) = keyedTypeInfo {
          optionalBool = true
          keyedTypeInfo = optionalType
        }
        var valueType: Any? = nil
        switch keyedTypeInfo {
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
        case .unkeyed:
          throw RequestError(.ormTableCreationError, reason: "Arrays or sets are not supported")
        default:
          throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: keyedTypeInfo)) is not supported")
        }
        if let SQLType = valueType as? SQLDataType.Type {
          if key == idColumn.name && !idColumnIsSet {
            columns.append(Column(key, SQLType, primaryKey: true, notNull: !optionalBool))
            idColumnIsSet = true
          } else {
            columns.append(Column(key, SQLType, notNull: !optionalBool))
          }
        } else {
          throw RequestError(.ormTableCreationError, reason: "Type: \(String(describing: valueType)) of Key: \(String(describing: key)) is not a SQLDataType")
        }
      }
    default:
      //TODO enhance error message
      throw RequestError(.ormTableCreationError, reason: "Can only save a struct to the database")
    }
    if !idColumnIsSet {
     columns.append(Column(idColumn.name, idColumn.type, autoIncrement: true, primaryKey: true))
    }
    return Table(tableName: tableName, columns: columns)
  }
}
