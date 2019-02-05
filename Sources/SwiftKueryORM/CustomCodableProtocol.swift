//
//  CustomCodableProtocol.swift
//  KituraContracts
//
//  Created by Matthew Kilner on 31/01/2019.
//

import Foundation

public typealias CustomEncoder = (Any) -> Any?
public typealias CustomDecoder = (Any) -> Any?

public protocol CustomCodable {

    static var customCoders: [String: (CustomEncoder,CustomDecoder)]  {get}

}

public extension CustomCodable {

    static var customCoders: [String: (CustomEncoder,CustomDecoder)] { return [:] }

}
