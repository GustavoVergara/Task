//
//  CommonTask.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 16/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

open class CommonTask<Value, Error>: TaskProtocol {
    public typealias TaskResponse = CommonResponse<Value, Error>
    
    private typealias Callbacker = CallbackHandler<TaskResponse>
    
    private let callbackHandler: Callbacker

    public var status: TaskStatus<TaskResponse>
    public var progress: Double
    
    public var configurations: TaskConfigurations {
        return self.callbackHandler.configurations
    }
    
    // MARK: Contructors
    
    public required init(_ contructor: (@escaping TaskResponse.ProgressCallback, @escaping TaskResponse.CompletionCallback, inout TaskConfigurations) -> Void) {
        self.callbackHandler = Callbacker()
        self.status = .running
        self.progress = 0
        
        let internalProgressHandler: TaskResponse.ProgressCallback = { progress in
            self.progress = progress
            self.callbackHandler.progress(to: progress)
        }
        
        let internalCompletionHandler: TaskResponse.CompletionCallback = { response in
            self.status = .completed(response)
            self.callbackHandler.complete(with: response)
        }
        
        contructor(internalProgressHandler, internalCompletionHandler, &self.callbackHandler.configurations)
    }
    
    // MARK: Control Methods
    
    public func cancel() {
        self.callbackHandler.cancel()
    }
    
    public func resume() {
        self.callbackHandler.resume()
    }
    
    public func pause() {
        self.callbackHandler.pause()
    }

    // MARK: Callbacks
    
    @discardableResult
    open func onCompletion(_ handler: @escaping TaskResponse.CompletionCallback) -> CallbackCanceller {
        switch self.status {
        case .running, .paused:
            return self.callbackHandler.addCompletionHandler(handler)
        case .completed(let response):
            handler(response)
            return CallbackCanceller(cancel: {})
        case .cancelled:
            return CallbackCanceller(cancel: {})
        }
    }
    
    @discardableResult
    open func onProgress(_ handler: @escaping TaskResponse.ProgressCallback) -> CallbackCanceller {
        switch self.status {
        case .running, .paused:
            return self.callbackHandler.addProgressHandler(handler)
        case .completed:
            handler(1)
            return CallbackCanceller(cancel: {})
        case .cancelled:
            return CallbackCanceller(cancel: {})
        }
    }
    
    @discardableResult
    open func onSuccess(_ handler: @escaping TaskResponse.SuccessCallback) -> CallbackCanceller {
        return self.onCompletion { response in
            guard case let .success(value) = response.result else { return }
            
            handler(value)
        }
    }
    
    @discardableResult
    open func onFailure(_ handler: @escaping TaskResponse.FailureCallback) -> CallbackCanceller {
        return self.onCompletion { response in
            guard case let .failure(error) = response.result else { return }
            
            handler(error)
        }
    }

    // MARK: Maps
    
    public func mapResponse<NewValue, NewError>(_ mapResponse: @escaping (TaskResponse) -> CommonTask<NewValue, NewError>.TaskResponse) -> CommonTask<NewValue, NewError> {
        return .init { (updatedProgressTo, completeWith, configurations) in
            self.onCompletion { response in
                completeWith(mapResponse(response))
            }
            
            self.onProgress(updatedProgressTo)
            
            configurations = self.callbackHandler.configurations
        }
    }
    
    public func mapResult<NewValue, NewError>(_ mapResult: @escaping (TaskResult) -> Result<NewValue, NewError>) -> CommonTask<NewValue, NewError> {
        return self.mapResponse { $0.mapResult(mapResult) }
    }
    
    public func map<NewValue, NewError>(success successMap: @escaping (Value) -> NewValue, failure failureMap: @escaping (Error) -> NewError) -> CommonTask<NewValue, NewError> {
        return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
    }
    
    public func mapSuccess<NewValue>(_ successMap: @escaping (Value) -> NewValue) -> CommonTask<NewValue, Error> {
        return self.map(success: { successMap($0) }, failure: { $0 })
    }
    
    public func mapFailure<NewError>(_ failureMap: @escaping (Error) -> NewError) -> CommonTask<Value, NewError> {
        return self.map(success: { $0 }, failure: { failureMap($0) })
    }
    
    public func flatMapSuccess<NewValue>(_ successMap: @escaping (Value) -> Result<NewValue, Error>) -> CommonTask<NewValue, Error> {
        return self.mapResult { result in
            switch result {
            case .success(let value): return successMap(value)
            case .failure(let error): return .failure(error)
            }
        }
    }
    
    public func flatMapFailure<NewError>(_ failureMap: @escaping (Error) -> Result<Value, NewError>) -> CommonTask<Value, NewError> {
        return self.mapResult { result in
            switch result {
            case .success(let value): return .success(value)
            case .failure(let error): return failureMap(error)
            }
        }
    }

}

//open class CommonTask<Value, Error>: Task<CommonResponse<Value, Error>> {
//    public typealias TaskResponse = CommonResponse<Value, Error>
//
//    public func mapResult<NewValue, NewError>(_ mapResult: @escaping (Result<Value, Error>) -> Result<NewValue, NewError>) -> Task<CommonResponse<NewValue, NewError>> {
//        return self.mapResponse { $0.mapResult(mapResult) }
//    }
//
//    public func map<NewValue, NewError>(success successMap: @escaping (Value) -> NewValue, failure failureMap: @escaping (Error) -> NewError) -> Task<CommonResponse<NewValue, NewError>> {
//        return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
//    }
//
//    public func mapSuccess<NewValue>(_ successMap: @escaping (Value) -> NewValue) -> Task<CommonResponse<NewValue, Error>> {
//        return self.map(success: { successMap($0) }, failure: { $0 })
//    }
//
//    public func mapFailure<NewError>(_ failureMap: @escaping (Error) -> NewError) -> Task<CommonResponse<Value, NewError>> {
//        return self.map(success: { $0 }, failure: { failureMap($0) })
//    }
//
//    public func flatMapSuccess<NewValue>(_ successMap: @escaping (Value) -> Result<NewValue, Error>) -> Task<CommonResponse<NewValue, Error>> {
//        return self.mapResult { result in
//            switch result {
//            case .success(let value): return successMap(value)
//            case .failure(let error): return .failure(error)
//            }
//        }
//    }
//
//    public func flatMapFailure<NewError>(_ failureMap: @escaping (Error) -> Result<Value, NewError>) -> Task<CommonResponse<Value, NewError>> {
//        return self.mapResult { result in
//            switch result {
//            case .success(let value): return .success(value)
//            case .failure(let error): return failureMap(error)
//            }
//        }
//    }
//
//}
