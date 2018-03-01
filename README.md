<p align="center">
    <a href="http://kitura.io/">
        <img src="https://raw.githubusercontent.com/IBM-Swift/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
    </a>
</p>


<p align="center">
    <a href="http://www.kitura.io/">
    <img src="https://img.shields.io/badge/docs-kitura.io-1FBCE4.svg" alt="Docs">
    </a>
    <a href="https://travis-ci.org/IBM-Swift/Swift-Kuery-ORM">
    <img src="https://travis-ci.org/IBM-Swift/Swift-Kuery-ORM.svg?branch=master" alt="Build Status - Master">
    </a>
    <img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="Mac OS X">
    <img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
    <img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
    <a href="http://swift-at-ibm-slack.mybluemix.net/">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
    </a>
</p>

# Swift-Kuery-ORM

## Summary
Swift-Kuery-ORM is an Object-relational Mapping build on top of [Swift-Kuery](http://github.com/IBM-Swift/Swift-Kuery). Using Codable it provides an easy way of persisting your data.

## Example
This example demonstrates how to persist data from a struct using [Swift-Kuery-PostgreSQL](http://github.com/IBM-Swift/Swift-Kuery-PostgreSQL). It assumes there is a PostgreSQL server running at localhost:5432.

### Import

Add Swift-Kuery-ORM and Swift-Kuery-PostgreSQL to your `Package.swift`:

```swift
  dependencies: [
    ...
    // Add these two lines
    .package(url: "https://github.com/IBM-Swift/Swift-Kuery-ORM.git", from: "0.0.1"),
    .package(url: "https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: ...
      // Add these two modules to your target(s)
      dependencies: [..., "SwiftKueryORM", "SwiftKueryPostgreSQL"]),
  ]
```

Import Swift-Kuery-ORM and Swift-Kuery-PostgreSQL in your `*.swift`:

```swift
import SwiftKueryORM
import SwiftKueryPostgreSQL
```

### Database

After installing [PostgreSQL](http://github.com/IBM-Swift/Swift-Kuery-PostgreSQL), in your terminal create a database:

```bash
createdb school
```

Initialise your database in your `*.swift`:

```swift
let pool = PostgreSQLConnection.createPool(host: "localhost", port: 5432, options: [.databaseName("school")], poolOptions: ConnectionPoolOptions(initialCapacity: 10, maxCapacity: 50, timeout: 10000))
Database.default = Database(pool)
```

### Model

Define a Model:

```swift
struct Grade: Model {
  var course: String
  var grade: Int
}
```

Create the table in the database:

```swift
do {
  try Grade.createTableSync()
} catch {
  // Error
}
```

### Saving

Save a grade:

```swift
let grade = Grade(course: "physics", grade: 80)

grade.save { grade, error in
  ...
}
```

Save your grade and get back it's id:

```swift
grade.save { (id: Int?, grade: Grade?, error: RequestError?) in
  ...
}
```

### Updating

Update a grade:

```swift
let grade = Grade(course: "physics", grade: 80)
grade.course = "maths"

grade.update(id: 1) { id, grade, error in
  ...
}
```

### Finding

Find a grade:

```swift
Grade.find(id: 1) {id, result, error in
  ...
}
```

Find all the grades:

```swift
Grade.findAll { result, error in
  ...
}
```

```swift
Grade.findAll { (result: [(Int, Grade)]?, error: RequestError?) in
  ...
}
```

```swift
Grade.findAll { (result: [Int: Grade]?, error: RequestError?) in
  ...
}
```

### Deleting

Delete a grade:

```swift
Grade.delete(id: 1) { error in
  ...
}
```

Delete all the grades:

```swift
Grade.deleteAll { error in
  ...
}
```

### Customise

Using [Swift-Kuery](http://github.com/IBM-Swift/Swift-Kuery) in the ORM.

#### Get the table of your Model

```swift
do {
  let table = Grade.getTable()
} catch {
  // Error
}
```

#### Create a query

Following [SwiftKuery](https://github.com/IBM-Swift/Swift-Kuery#query-examples)

#### Execute a query

Executing a query that returns a optional grade or an optional error:

```swift
executeQuery(query: Query) { grade, error in
  ...
}
```

Executing a query that returns an optional array of grades or an optional error:

```swift
executeQuery(query: Query) { grade, error in
  ...
}
```

Executing a query that returns an optional error:

```swift
executeQuery(query: Query) { error in
  ...
}
```

## List of plugins:

* [PostgreSQL](https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL)

* [SQLite](https://github.com/IBM-Swift/Swift-Kuery-SQLite)

* [MySQL](https://github.com/IBM-Swift/SwiftKueryMySQL)

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
