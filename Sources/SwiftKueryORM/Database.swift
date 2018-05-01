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

    /// Global default Database for the application
    public static var `default`: Database?

    /// Instance of TableInfo containing cached tables
    public static var tableInfo = TableInfo()

    /// Enum defining the connection strategy: a connection pool or custom
    /// connection generator
    private enum ConnectionStrategy {
        case pool(ConnectionPool)
        case generator(() -> Connection?)
    }

    private let connectionStrategy: ConnectionStrategy

    /// Constructor for a single connection which becomes a connection pool
    public convenience init(single connection: Connection) {
        // Create single entry connection pool for thread safety
        let singleConnectionPool = ConnectionPool(options: ConnectionPoolOptions(initialCapacity: 1, maxCapacity: 1),
                                                  connectionGenerator: { connection },
                                                  connectionReleaser: { _ in connection.closeConnection() })
        self.init(singleConnectionPool)
    }

    /// Default constructor for a connection pool
    public init(_ pool: ConnectionPool) {
        self.connectionStrategy = .pool(pool)
    }

    /// Constructor for a custom connection generator
    public init(generator: @escaping () -> Connection?) {
        self.connectionStrategy = .generator(generator)
    }

    /// Connection getter: either new connection from pool
    /// or call the custom generator
    public func getConnection() -> Connection? {
        switch connectionStrategy {
        case .pool(let pool): return pool.getConnection()
        case .generator(let generator): return generator()
        }
    }
}
