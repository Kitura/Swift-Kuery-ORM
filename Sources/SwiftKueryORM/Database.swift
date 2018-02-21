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

public enum ConnectionStrategy {
  case global(Connection)
  case pool(ConnectionPool)
  case generator(() -> Connection?)
}

public typealias ConnectionPoolOptions = SwiftKuery.ConnectionPoolOptions
public class Database {
  public static var defaultConnection: ConnectionStrategy?
  public static var tableInfo = TableInfo()
  public var optionalConnection: Connection
  public static var connection: Connection? {
    switch defaultConnection {
    case .global(let globalConnection)?: return globalConnection // don't use when multi-threaded
    case .pool(let connectionPool)?: return connectionPool.getConnection() // boo, this can return nil, so connection needs to be optional above
    case .generator(let generator)?: return generator()
    default: return nil
    }
  }

  public init(connection: Connection) {
    self.optionalConnection = connection
  }
}
