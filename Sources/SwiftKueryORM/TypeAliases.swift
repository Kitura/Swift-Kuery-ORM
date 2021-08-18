/*
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import KituraContracts
import SwiftKuery

/*
 This file declares public typealiases for types stored in the dependencies.
 The purpose is to expose these types at the top level without having to import a specific dependency.
 */

/// Type Alias for Database (See [#22](https://github.com/Kitura/Swift-Kuery-ORM/issues/22))
public typealias ORMDatabase = Database

/// Type Alias for RequestError from [KituraContracts](https://github.com/IBM-Swift/KituraContracts)
public typealias RequestError = KituraContracts.RequestError

/// Type Alias for SQLDataType from [SwiftKuery](https://github.com/IBM-Swift/Swift-Kuery)
public typealias SQLDataType = SwiftKuery.SQLDataType

/// Public TypeAlias for QueryParams Type from KituraContracts
public typealias QueryParams = KituraContracts.QueryParams

/// Public TypeAlias for GreaterThan Type from KituraContracts
public typealias GreaterThan = KituraContracts.GreaterThan

/// Public TypeAlias for LowerThan Type from KituraContracts
public typealias LowerThan = KituraContracts.LowerThan

/// Public TypeAlias for GreaterThanOrEqual Type from KituraContracts
public typealias GreaterThanOrEqual = KituraContracts.GreaterThanOrEqual

/// Public TypeAlias for LowerThanOrEqual Type from KituraContracts
public typealias LowerThanOrEqual = KituraContracts.LowerThanOrEqual

/// Public TypeAlias for InclusiveRange Type from KituraContracts
public typealias InclusiveRange = KituraContracts.InclusiveRange

/// Public TypeAlias for ExclusiveRange Type from KituraContracts
public typealias ExclusiveRange = KituraContracts.ExclusiveRange

/// Public TypeAlias for Pagination Type from KituraContracts
public typealias Pagination = KituraContracts.Pagination

/// Public TypeAlias for Ordering Type from KituraContracts
public typealias Ordering = KituraContracts.Ordering
