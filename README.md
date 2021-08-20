<p align="center">
    <a href="https://www.kitura.dev/">
        <img src="https://raw.githubusercontent.com/Kitura/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
    </a>
</p>


<p align="center">
    <a href="https://kitura.github.io/Swift-Kuery-ORM/index.html">
    <img src="https://img.shields.io/badge/apidoc-SwiftKueryORM-1FBCE4.svg?style=flat" alt="APIDoc">
    </a>
    <a href="https://travis-ci.org/Kitura/Swift-Kuery-ORM">
    <img src="https://travis-ci.org/Kitura/Swift-Kuery-ORM.svg?branch=master" alt="Build Status - Master">
    </a>
    <img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
    <img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
    <img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
    <a href="https://slack.kitura.dev">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
    </a>
</p>

# Swift-Kuery-ORM

Swift-Kuery-ORM is an ORM (Object Relational Mapping) library built for Swift. Using it allows you to simplify persistence of model objects with your server.

Swift-Kuery-ORM is built on top of [Swift-Kuery](http://github.com/Kitura/Swift-Kuery), which means that its possible to use Swift-Kuery to customize SQL queries made to the database, if the functionality of the ORM is insufficient.

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
extension Grade: Model { }
```

Now that your `Grade` struct conforms to `Model`, after you have set up your database connection pool and created a database table, you automatically have access to a slew of convenience functions for your object.

Need to retrieve all instances of `Grade`? You can implement:

```swift
Grade.findAll()
```

Need to add a new instance of `Grade`? Here's how:

```swift
grade.save()
```

The `Model` protocol is the key to using the ORM. Let's walk through how to fully set up an application to make use of the ORM.

## Example

Follow [Getting Started](https://www.kitura.dev/docs/getting-started/installation) to create a Kitura server. In this example you'll be using the [Swift Kuery PostgreSQL plugin](https://github.com/Kitura/Swift-Kuery-PostgreSQL), so you will need PostgreSQL running on your local machine, which you can install with `brew install postgresql`. The default port for PostgreSQL is 5432.

### Update your Package.swift file

Add Swift-Kuery-ORM and Swift-Kuery-PostgreSQL to your application's `Package.swift`. Substitute `"x.x.x"` with the latest `Swift-Kuery-ORM` [release](https://github.com/Kitura/Swift-Kuery-ORM/releases) and the latest `Swift-Kuery-PostgreSQL` [release](https://github.com/Kitura/Swift-Kuery-PostgreSQL/releases).

```swift
dependencies: [
    ...
    // Add these two lines
    .package(url: "https://github.com/Kitura/Swift-Kuery-ORM.git", from: "x.x.x"),
    .package(url: "https://github.com/Kitura/Swift-Kuery-PostgreSQL.git", from: "x.x.x"),
  ],
  targets: [
    .target(
      name: ...
      // Add these two modules to your target(s)
      dependencies: [..., "SwiftKueryORM", "SwiftKueryPostgreSQL"]),
  ]
```

Let's assume you want to add ORM functionality to a file called `Application.swift`. You'll need to add the following import statements at the top of the file:

```swift
import SwiftKueryORM
import SwiftKueryPostgreSQL
```

### Create Your Database

As mentioned before, we recommend you use [Homebrew](https://brew.sh) to set up PostgreSQL on your machine. You can install PostgreSQL and set up your table like so:

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

### Updating

If you have the id for an existing record of your object, and you'd like to update the record with an object, you can use the `update()` function to do so:

```swift
let grade = Grade(course: "physics", grade: 80)
grade.course = "maths"

grade.update(id: 1) { grade, error in
  ...
}
```

### Retrieving

If you'd like to find a specific object, and you have its id, you can use the `find()` function to retrieve it:

```swift
Grade.find(id: 1) { result, error in
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

### Customizing your Model

The ORM defines an extension to `Model` which provides a number of `public static executeQuery(…)` functions. These can be used to create custom functions within your model that perform more complex database operations. The example below defines a Person model and with a custom function that will retrieve all records which have age > 20:

```swift
// define the Person struct
struct Person: Codable {
    var firstname: String
    var surname: String
    var age: Int
}

// extend Person to conform to model and add overTwenties function
extension Person: Model {

    // Define a synchronous function to retrieve all records of Person with age > 20
    public static func getOverTwenties() -> [Person]? {
        let wait = DispatchSemaphore(value: 0)
        // First get the table
        var table: Table
        do {
            table = try Person.getTable()
        } catch {
            // Handle error
        }
        // Define result, query and execute
        var overTwenties: [Person]? = nil
        let query = Select(from: table).where("age > 20")

        Person.executeQuery(query: query, parameters: nil) { results, error in
            guard let results = results else {
                // Handle error
            }
            overTwenties = results
            wait.signal()
            return
        }
        wait.wait()
        return overTwenties
    }
}
```

Alternatively you can define and asynchronous getOverTwenties function:
```swift
public static func getOverTwenties(oncompletion: @escaping ([Person]?, RequestError?)-> Void) {
    var table: Table
    do {
        table = try Person.getTable()
    } catch {
        // Handle error
    }
    let query = Select(from: table).where("age > 20")
    Person.executeQuery(query: query, parameters: nil, oncompletion)
}
```

which can be called in a fashion similar to the following:
```swift
Person.getOverTwenties() { result, error in
    guard let result = result else {
        // Handle error
    }
    // Use result
}
```

If you'd like to learn more about how you can customize queries, check out the [Swift-Kuery](https://github.com/Kitura/Swift-Kuery) repository for more information.

## Model Identifiers

The ORM has several options available for identifying an instance of a model.

### Automatic ID assignment

If you define your `Model` without specifying an ID property, either by using the `idColumnName` property or the default name of `id`, then the ORM will create an auto-incrementing column named `id` in the database table for the model, eg.

```swift
struct Person: Model {
    var firstname: String
    var surname: String
    var age: Int
}
```
 
The model does not contain a property for the ID. The ORM provides a specific `save` API that will return the ID that was assigned. It is important to note the ORM will not link the returned ID to the instance of the Model in any way; you are responsible for maintaining this relationship if necessary. Below is an example of retrieving an ID for an instance of the `Person` model defined above:

```swift
let person = Person(firstname: "example", surname: "person", age: 21)
person.save() { (id: Int?, person, error) in
    guard let id = id, let person = person else{
        // Handle error
        return
    }
    // Use person and id
}
```
The compiler requires you to declare the type of the ID received by your completion handler; the type should be `Int?` for an ID that has been automatically assigned.

### Manual ID assignment

You can manage the assignment of IDs yourself by adding an `id` property to your model. You may customise the name of this property by defining `idColumnName`. For example:

```swift
struct Person: Model {
    var myIDField: Int
    var firstname: String
    var surname: String
    var age: Int

    static var idColumnName = "myIDField"
    static var idColumnType = Int.self
}
```

When using a `Model` defined in this way, you are responsible for the assignment and management of IDs. Below is an example of saving an instance of the `Person` model defined above:

```swift
let person = Person(myIDField: 1, firstname: "example", surname: "person", age: 21)
person.save() { (person, error) in
    guard let person = person else {
        // Handle error
        return
    }
    // Use newly saved person
}
```

### Using `optional` ID properties

Declaring your ID property as optional allows the ORM to assign the ID automatically when the model is saved. If the value of ID is `nil`, the database will assign an auto-incremented value. At present this is only support for an `Int?` type.

You may instead provide an explicit value, which will be used instead of automatic assignment.

Optional IDs must be identified by defining the `idKeypath: IDKeyPath` property, as in the example below:

```swift
struct Person: Model {
    var id: Int?
    var firstname: String
    var surname: String
    var age: Int

    static var idKeypath: IDKeyPath = \Person.id
}
```

In the example above, the `Model` is defined with an ID property matching the default `idColumnName` value, but should you wish to use an alternative name you must define `idColumnName` accordingly.

Below is an example of saving an instance of the `Person` defined above, both with an explicitly defined ID and without:

```swift
let person = Person(id: nil, firstname: “Banana”, surname: “Man”, age: 21)
let specificPerson = Person(id: 5, firstname: “Super”, surname: “Ted”, age: 26)

person.save() { (savedPerson, error) in
        guard let newPerson = savedPerson else {
            // Handle error
        }
        print(newPerson.id) // Prints the next value in the databases identifier sequence, eg. 1
}

specificPerson.save() { (savedPerson, error) in
        guard let newPerson = savedPerson else {
            // Handle error
        }
        print(newPerson.id) // Prints 5
}
```

**NOTE** - When using manual or optional ID properties, you should be prepared to handle violation of unique identifier constraints. These can occur if you attempt to save a model with an ID that already exists, or in the case of Postgres, if the auto-incremented value collides with an ID that was previously inserted explicitly.

## Alternative encoding for `Date` properties

By default any property on your Model that is declared as a `Date` will be encoded and decoded as a `Double`.

You can change this behaviour by overriding the default value of the property `dateEncodingStrategy`. The dateEncodingStrategy will apply to all Date properties on your Model.

The example below defines a model which will have its Date properties encoded and decoded as a timestamp:

```swift

struct Person: Model {

    static var dateEncodingFormat: DateEncodingFormat = .timestamp

    var firstname: String
    var surname: String
    var age: Int
    var dob: Date
}
```

## List of plugins

* [PostgreSQL](https://github.com/Kitura/Swift-Kuery-PostgreSQL)

* [SQLite](https://github.com/Kitura/Swift-Kuery-SQLite)

* [MySQL](https://github.com/Kitura/SwiftKueryMySQL)

## API Documentation
For more information visit our [API reference](https://kitura.github.io/Swift-Kuery-ORM/index.html).

## Community

We love to talk server-side Swift, and Kitura. Join our [Slack](https://slack.kitura.dev) to meet the team!

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
