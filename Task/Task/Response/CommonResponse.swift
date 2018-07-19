//
//  CommonResponse.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 13/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

public struct CommonResponse<Value, Error>: Response {
    public var result: Result<Value, Error>
    
    public init(result: Result<Value, Error>) {
        self.result = result
    }
    
    public init(from response: CommonResponse<Value, Error>, withResult result: Result<Value, Error>) {
        self.result = result
    }

}
