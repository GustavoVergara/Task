//
//  HTTPTask.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 13/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation


public struct HTTPResponse<Value, Error>: Response {
    public var result: Result<Value, Error>
    public var urlRequest: URLRequest?
    public var httpURLResponse: HTTPURLResponse?
    public var data: Data?
    
    public init(result: Result<Value, Error>) {
        self.result = result
    }

    public init(result: Result<Value, Error>, urlRequest: URLRequest?, httpURLResponse: HTTPURLResponse?, data: Data?) {
        self.result = result
        self.urlRequest = urlRequest
        self.httpURLResponse = httpURLResponse
        self.data = data
    }
    
    public init(from response: HTTPResponse<Value, Error>, withResult result: Result<Value, Error>) {
        self.result = result
        self.urlRequest = response.urlRequest
        self.httpURLResponse = response.httpURLResponse
        self.data = response.data
    }
    
}

public extension HTTPResponse where Value == Data, Error == Swift.Error {
    
    init(urlRequest: URLRequest?, urlResponse: URLResponse?, rawData: Data?, rawError: Swift.Error?) {
        let result: Result<Data, Error>
        
        if let error = rawError {
            result = .failure(error)
        } else if let data = rawData {
            result = .success(data)
        } else {
            result = .failure(Result<Data, Error>.error("HTTPResponse - No Data"))
        }
        
        self.init(result: result, urlRequest: urlRequest, httpURLResponse: urlResponse as? HTTPURLResponse, data: rawData)
    }
    
}
