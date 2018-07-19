//
//  Response.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 12/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

public protocol Response {
    associatedtype Value
    associatedtype Error
    
    var result: Result<Value, Error> { get }

    init(result: Result<Value, Error>)
    init(from response: Self, withResult result: Result<Value, Error>)
    
    func map<NewValue, NewError, NewResponse>(_ closure: (Self) -> (Result<NewValue, NewError>))
        -> NewResponse
        where
            NewResponse: Response,
            NewResponse.Value == NewValue,
            NewResponse.Error == NewError
    
    func map(_ closure: (Self) -> (Result<Value, Error>)) -> Self

    
    func mapResult<NewValue, NewError, NewResponse>(_ closure: (Result<Value, Error>) -> (Result<NewValue, NewError>))
        -> NewResponse
        where
            NewResponse: Response,
            NewResponse.Value == NewValue,
            NewResponse.Error == NewError

    func map<NewValue, NewError, NewResponse>(success successClosure: (Value) -> (NewValue), failure failureClosure: (Error) -> (NewError))
        -> NewResponse
        where
            NewResponse: Response,
            NewResponse.Value == NewValue,
            NewResponse.Error == NewError

    func mapFailure<NewError, NewResponse>(_ closure: @escaping (Error) -> (NewError))
        -> NewResponse
        where
            NewResponse: Response,
            NewResponse.Value == Self.Value,
            NewResponse.Error == NewError
    
    func mapSuccess<NewValue, NewResponse>(_ closure: @escaping (Value) -> (NewValue))
        -> NewResponse
        where
            NewResponse: Response,
            NewResponse.Value == NewValue,
            NewResponse.Error == Self.Error
    
}

public extension Response {
    public typealias Status = TaskStatus<Self>
    public typealias TaskResult = Result<Value, Error>
    
    public typealias CompletionCallback = (Self) -> Void
    public typealias ProgressCallback = (Double) -> Void
    public typealias SuccessCallback = (Value) -> Void
    public typealias FailureCallback = (Error) -> Void
}

extension Response where Value: Equatable, Error: Equatable {

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.result == rhs.result
    }

}

extension Response {
    
    public func map<NewValue, NewError, NewResponse>(_ closure: (Self) -> (Result<NewValue, NewError>))
        -> NewResponse
        where
        NewResponse: Response,
        NewResponse.Error == NewError,
        NewResponse.Value == NewValue
    {
        let newResult = closure(self)
        return NewResponse.init(result: newResult)
    }
    
    public func map(_ closure: (Self) -> (Result<Value, Error>)) -> Self {
        let newResult = closure(self)
        return Self.init(result: newResult)
    }
    
    public func mapResult<NewValue, NewError, NewResponse>(_ closure: (Result<Value, Error>) -> (Result<NewValue, NewError>))
        -> NewResponse
        where
        NewResponse: Response,
        NewResponse.Error == NewError,
        NewResponse.Value == NewValue
    {
        return self.map({ closure($0.result) })
    }
    
    public func map<NewValue, NewError, NewResponse>(success successClosure: (Value) -> (NewValue), failure failureClosure: (Error) -> (NewError))
        -> NewResponse
        where
        NewResponse: Response,
        NewResponse.Error == NewError,
        NewResponse.Value == NewValue
    {
        return self.mapResult { result in
            switch result {
            case .success(let value): return .success(successClosure(value))
            case .failure(let error): return .failure(failureClosure(error))
            }
        }
    }
    
    public func mapFailure<NewError, NewResponse>(_ closure: @escaping (Error) -> (NewError))
        -> NewResponse
        where
        NewResponse : Response,
        NewResponse.Error == NewError,
        NewResponse.Value == Value
    {
        return self.map(success: { $0 }, failure: { closure($0) })
    }
    
    public func mapSuccess<NewValue, NewResponse>(_ closure: @escaping (Value) -> (NewValue))
        -> NewResponse
        where
        NewResponse : Response,
        NewResponse.Error == Error,
        NewResponse.Value == NewValue
    {
        return self.map(success: { closure($0) }, failure: { $0 })
    }
    
}
