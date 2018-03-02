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
Swift-Kuery-ORM is an ORM (Object Relational Mapping) library built for Swift. Using it allows you to simplify persistence of model objects with your server.

Swift-Kuery-ORM is built on top of [Swift-Kuery](http://github.com/IBM-Swift/Swift-Kuery), which means that its possible to use Swift-Kuery to customize SQL queries made to the database, if the functionality of the ORM is insufficient.

## The Model Protocol
The key component of Swift-Kuery-ORM is the protocol `Model`. 

Let's propose a struct to use as an example. We can declare an object that looks like so:

```swift
struct Grade: Codable {
  var course: String
  var grade: Int
}
```

Thanks to [Codable Routing](https://developer.ibm.com/swift/2017/10/30/codable-routing/) in Kitura 2.0, we declare our struct to be `Codable` to simplify our RESTful routes for these objects on our server. The `Model` protocol extends what `Codable` does to work with the ORM. In your server application, you would extend your object like so:

```swift
extension Grade : Model { }
```

Now that your `Grade` struct conforms to `Model`, after you [set up]() your database connection pool and create a table sync, you automatically have access to a slew of convenience functions for your object.

Need to retrieve all instances of `Grade`? You can implement:

```swift
Grade.retrieveAll()
```

Need to add a new instance of `Grade`? Here's how:

```swift
grade.save()
```

The `Model` protocol is the key to using the ORM. Let's walk through how to fully set up an application to make use of the ORM.

## Example

You'll want to go [here](http://www.kitura.io/en/starter/gettingstarted.html) to create a server from the CLI to get started. You'll be using the [PostGreSQL plugin of Swift Kuery](https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL), so you will want to make sure that you have PostGreSQL running on your local machine, which you can install with `brew install postgresql`. The default port for PostGreSQL is 5432.

### Update your Package.swift file

Go to your Add Swift-Kuery-ORM and Swift-Kuery-PostgreSQL to your `Package.swift`:

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

Let's assume you want to add ORM functionality to a file called `Application.swift`. You'll need to make the following import statements at the top of the file:

```swift
import SwiftKueryORM
import SwiftKueryPostgreSQL
```

### Create Your Database

As mentioned before, we recommend you use [Homebrew](https://brew.sh) to set up PostGreSQL on your machine. You can install PostGreSQL and set up your table like so:

```bash
brew install postgresql
brew services start postgresql
createdb school
```

Initialize your database in your `Application.swift` file:

```swift
let pool = PostgreSQLConnection.createPool(host: "localhost", port: 5432, options: [.databaseName("school")], poolOptions: ConnectionPoolOptions(initialCapacity: 10, maxCapacity: 50, timeout: 10000))
Database.default = Database(pool)
```

### Set Up Your Object

Like before, assume you will work with a struct that looks like so:

```swift
struct Grade : Codable {
  var course: String
  var grade: Int
}
```

In your `Application.swift` file, extend `Grade` to conform to `Model`

```swift
extension Grade : Model { 
    // here, you can add any server-side specific logic to your object
}
```

Now, you need to create your table. If you are configuring your database while you start up your server, you can use `createTableSync()`, which runs synchronously. If you want to use an asynchronous function, you can use `createTable()` elsewhere. You can implement either of these functions like so:

```swift
do {
  try Grade.createTableSync()
} catch let error {
  // Error
}
```

It's important to point out that if you've already created your table, this will throw an error here.

Your application is now ready to make use of all the functions available in the `Model` protocol. If you'd like to see a fully working example of the ORM using [Codable Routing](https://www.ibm.com/blogs/bluemix/2018/01/kitura-2-0-taking-advantage-of-codable-routes/), visit our [FoodTracker](https://github.com/IBM/foodtrackerbackend) example.

Let's cover all the functionality you have available to you now.

### Saving

If you'd like to save a new object to your database, you have to create the object and use the `save()` function:

```swift
let grade = Grade(course: "physics", grade: 80)
grade.save { grade, error in
  ...
}
```

You also optionally have the ability to pass the ID of the newly saved object into your closure. Add it to the collection of parameters like so:

```swift
grade.save { (id: Int?, grade: Grade?, error: RequestError?) in
  ...
}
```

**NB**: If you want to use `RequestError`, you'll need to import `KituraContracts` at the top of your swift file.

### Updating

If you have the id for an existing record of your object, and you'd like to update the record with an object, you can use the `update()` function to do so:

```swift
let grade = Grade(course: "physics", grade: 80)
grade.course = "maths"

grade.update(id: 1) { id, grade, error in
  ...
}
```

### Retrieving

If you'd like to find a specific object, and you have its id, you can use the `find()` function to retrieve it:

```swift
Grade.find(id: 1) {id, result, error in
  ...
}
```

If you'd like to retrieve all instances of a particular object, you can make use of `findAll()` as a static function on the type you are trying to retrieve:

```swift
Grade.findAll { (result: [Grade]?, error: RequestError?) in
  ...
}
```

You also have the ability to form your results in different ways and formats, like so:

```swift
Grade.findAll { (result: [(Int, Grade)]?, error: RequestError?) in
  ...
}

Grade.findAll { (result: [Int: Grade]?, error: RequestError?) in
  ...
}
```

### Deleting

If you'd like to delete an object, and you have its id, you can use the `delete()` function like so:

```swift
Grade.delete(id: 1) { error in
  ...
}
```

If you're feeling bold, and you'd like to remove all instances of an object from your database, you can use the static function `deleteAll()` with your type:

```swift
Grade.deleteAll { error in
  ...
}
```

### Customization

The ORM uses [Swift-Kuery](https://github.com/IBM-Swift/Swift-Kuery) which allows you to customize and execute your own queries without breaking any existing ORM functionality. You'll want to have access to the table for your object, which you can get with the `getTable()` function:

```swift
do {
  let table = Grade.getTable()
} catch {
  // Error
}
```

After you retrieve your table, you can create a `Query` object to specify what you want to execute on your database, and perform it like so:

```swift
executeQuery(query: Query) { (grade: Grade?, error: RequestError?) in
  ...
}
```

You can customize the parameters passed into your closure after you execute a `Query` like so:

```swift
executeQuery(query: Query) { grade, error in
  ...
}

executeQuery(query: Query) { error in
  ...
}
```

If you'd like to learn more about how you can customize queries, check out the [Swift-Kuery](https://github.com/IBM-Swift/Swift-Kuery) repository for more information.

## List of plugins:

* [PostgreSQL](https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL)

* [SQLite](https://github.com/IBM-Swift/Swift-Kuery-SQLite)

* [MySQL](https://github.com/IBM-Swift/SwiftKueryMySQL)

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
