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
      Self.find(id: id, using: db) { (model: Self?, error: RequestError?) in
        if let error = error {
          onCompletion(nil, error)
          return
        }

        if var identifiedModel = model {
          identifiedModel.id = id
          onCompletion(identifiedModel, error)
          return
        }

        onCompletion(nil, RequestError( .ormInternalError, reason: "Find Failed but no error found"))
      }
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
}

