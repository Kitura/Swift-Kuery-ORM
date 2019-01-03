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

/// Defines the parameters of the ConnectionPool from SwiftKuery
public typealias ConnectionPoolOptions = SwiftKuery.ConnectionPoolOptions

/// Class defining the connection to the database.
///
/// To setup the database, in this case using [PostgreSQL](https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL):
/// ```
/// import SwiftKueryORM
/// import SwiftKueryPostgreSQL
/// let pool = PostgreSQLConnection.createPool(host: "localhost", port: 5432,
///                                            options: [.databaseName("FoodDatabase")],
///                                            poolOptions: ConnectionPoolOptions(
///                                                                       initialCapacity: 10,
///                                                                       maxCapacity: 50,
///                                                                       timeout: 10000))
/// Database.default = Database(pool)
/// ```

public class Database {

    /// Definition of a DatabaseTask completion handler which accepts an optional Connection and optional Error
    public typealias DatabaseTask = (Connection?, QueryError?) -> ()

    /// Global default Database for the application
    public static var `default`: Database?

    /// Instance of TableInfo containing cached tables
    public static var tableInfo = TableInfo()

    /// Enum defining the connection strategy: a connection pool or custom
    /// connection generator
    private enum ConnectionStrategy {
        case pool(ConnectionPool)
        case generator(((@escaping DatabaseTask)) -> ())
    }

    private let connectionStrategy: ConnectionStrategy

    /**
     Create a Database instance which uses a single connection to perform each operation.
     The connection is wrapped in a connection pool which prevents any concurrent operations being carried out on the connection
     The connection will retain system resources for its lifetime.
     Below is example code which creates a connection and uses it to create a Database instance:
     ```swift
     var opts = [ConnectionOptions]()
     opts.append(ConnectionOptions.userName("myUser"))
     opts.append(ConnectionOptions.password("myPassword"))
     let connection = PostgreSQLConnection(host: host, port: port, options: opts)
     let result = connection.connectSync()
     guard let result.success else {
         // Handle error
         return
     }
     let db = Database(single: connection)
     ```
     */
    public convenience init(single connection: Connection) {
        // Create single entry connection pool for thread safety
        let singleConnectionPool = ConnectionPool(options: ConnectionPoolOptions(initialCapacity: 1, maxCapacity: 1),
                                                  connectionGenerator: { connection },
                                                  connectionReleaser: { _ in connection.closeConnection() })
        self.init(singleConnectionPool)
    }

    /**
     Create a Database instance which uses a connection pool. A connection will be removed from the pool for each operation and returned to the pool nce the operation is complete.
     The pooled connections will hold system resources while not in use but will result in more efficient processing of operations when the pool has an available connection.
     Below is an example code which creates a connection pool and uses it to create a Database instance:
     ```swift
     let connectionPool = PostgreSQLConnection.createPool(host: host, port: port, options: [.userName("myUser"), .password("myPassword")], poolOptions: ConnectionPoolOptions(initialCapacity: 5, maxCapacity: 10))

     let db = Database(pgresPool)
     ```
     */
    public init(_ pool: ConnectionPool) {
        self.connectionStrategy = .pool(pool)
    }

    /**
     Create a Database instance which uses short-lived connections that are generated on demand. A new Connection is created for every operation, and will be closed once the operation completes.
     An advantage of this approach is that memory and resources are not tied up with connections when they are not required, however, the process of establishing a connection will impact the time taken to process each operation.
     Below is an example of a function that can be used as a connection generator and the call to create the Database instance:
     ```swift
     func getConnectionAndRunTask(task: @escaping (Connection?, QueryError?) -> ()) {
         var opts = [ConnectionOptions]()
         opts.append(ConnectionOptions.userName("myUser"))
         opts.append(ConnectionOptions.password("myPassword"))
         let connection = PostgreSQLConnection(host: host, port: port, options: opts)
         connection.connect() { result in
             guard result.success else {
                 // Handle error
                 return task(nil, QueryError.connection(result.asError?.localizedDescription ?? "Unknown connection error"))
             }
         return task(connection, nil)
         }
     }

     let db = Database(generator: getConnectionAndRunTask)```
    */
    public init(generator: @escaping (@escaping DatabaseTask) -> ()) {
        self.connectionStrategy = .generator(generator)
    }

    /// Function that redirects the passed databaseTask based on the current connectionStrategy
    internal func executeTask(task: @escaping DatabaseTask) {
        switch connectionStrategy {
        case .pool(let pool): return pool.getConnection(poolTask: task)
        case .generator(let generator): return generator(task)
        }
    }
}
