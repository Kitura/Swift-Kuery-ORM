
import SwiftKuery

/**
 Defines the nested type with the associated field name as a String
*/

indirect enum NestedType {
  case dictionary(table: Table, fieldName: String, keyNestedType: NestedType?, valueNestedType: NestedType?)
  case array(Table, String, NestedType?)
  case model(modelTable: Table, relationshipTable: Table, String, [NestedType]?)

  var fieldName: String {
    switch self {
    case .dictionary(_, let fieldName, _, _):
      return fieldName
    case .array(_, let fieldName, _):
      return fieldName
    case .model(_, let fieldName, _):
      return fieldName
    }
  }

  var table: Table {
    switch self {
    case .dictionary(let table, _, _, _):
      return table
    case .array(let table, _, _):
      return table
    case .model(_, let relationshipTable, _, _):
      return relationshipTable
    }
  }
}
