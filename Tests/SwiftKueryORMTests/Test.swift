/**
 * Copyright IBM Corporation 2016
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
 **/

import XCTest

import Foundation
import Dispatch

protocol Test {
    func expectation(_ index: Int) -> XCTestExpectation
    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?)
}

extension Test {

    func doSetUp() {
    }
    
    func doTearDown() {
        // sleep(10)
    }

    func performTest(asyncTasks: (XCTestExpectation) -> Void...) {
        let queue = DispatchQueue(label: "Query queue")

        for (index, asyncTask) in asyncTasks.enumerated() {
            let expectation = self.expectation(index)
            queue.async() {
                asyncTask(expectation)
            }
        }

        waitExpectation(timeout: 10) { error in
                // blocks test until request completes
                XCTAssertNil(error)
        }
    }
}

extension XCTestCase: Test {
    func expectation(_ index: Int) -> XCTestExpectation {
        let expectationDescription = "\(type(of: self))-\(index)"
        return self.expectation(description: expectationDescription)
    }

    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?) {
        self.waitForExpectations(timeout: t, handler: handler)
    }
}
