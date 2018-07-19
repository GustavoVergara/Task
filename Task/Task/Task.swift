//
//  Task.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 12/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

open class Task<TaskResponse: Response> {
    public typealias Value = TaskResponse.Value
    public typealias Error = TaskResponse.Error
    public typealias TaskResult = TaskResponse.TaskResult

    private typealias Callbacker = CallbackHandler<TaskResponse>
    
    private let callbackHandler: Callbacker
    
    public private(set) var status: TaskStatus<TaskResponse>
    public private(set) var progress: Double
    
    public var isRunning: Bool {
        switch self.status {
        case .running: return true
        case .completed, .cancelled, .paused: return false
        }
    }
    
    public var didFinish: Bool {
        switch self.status {
        case .running, .paused: return false
        case .completed, .cancelled: return true
        }
    }
    
    public init(_ contructor: (@escaping TaskResponse.ProgressCallback, @escaping TaskResponse.CompletionCallback, inout TaskConfigurations) -> Void) {
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
    
//    public convenience init(completedWith httpResponse: TaskResponse) {
//        self.init(noConfig: { didProgressTo, fulfillWith in
//            didProgressTo(1)
//            fulfillWith(httpResponse)
//        })
//    }
    
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
    
    open func mapResponse<NewResponse: Response>(_ mapResponse: @escaping (TaskResponse) -> NewResponse) -> Task<NewResponse> {
        return .init { (updatedProgressTo, completeWith, configurations) in
            self.onCompletion { response in
                completeWith(mapResponse(response))
            }
            
            self.onProgress(updatedProgressTo)
            
            configurations = self.callbackHandler.configurations
        }
    }
    
    public func mapResult<NewResponse: Response>(_ mapResult: @escaping (TaskResponse.TaskResult) -> NewResponse.TaskResult) -> Task<NewResponse> {
        return self.mapResponse { $0.mapResult(mapResult) }
    }
    
    public func map<NewResponse: Response>(success successMap: @escaping (Value) -> NewResponse.Value, failure failureMap: @escaping (Error) -> NewResponse.Error) -> Task<NewResponse> {
        return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
    }
    
    public func mapSuccess<NewResponse: Response>(_ successMap: @escaping (Value) -> NewResponse.Value) -> Task<NewResponse> where NewResponse.Error == Error {
        return self.map(success: { successMap($0) }, failure: { $0 })
    }
    
    public func mapFailure<NewResponse: Response>(_ failureMap: @escaping (Error) -> NewResponse.Error) -> Task<NewResponse> where NewResponse.Value == Value {
        return self.map(success: { $0 }, failure: { failureMap($0) })
    }
    
    public func flatMapSuccess<NewResponse: Response>(_ successMap: @escaping (Value) -> NewResponse.TaskResult) -> Task<NewResponse> where NewResponse.Error == Error {
        return self.mapResult { result in
            switch result {
            case .success(let value): return successMap(value)
            case .failure(let error): return .failure(error)
            }
        }
    }
    
    public func flatMapFailure<NewResponse: Response>(_ failureMap: @escaping (Error) -> NewResponse.TaskResult) -> Task<NewResponse> where NewResponse.Value == Value {
        return self.mapResult { result in
            switch result {
            case .success(let value): return .success(value)
            case .failure(let error): return failureMap(error)
            }
        }
    }
    
    // MARK - Thread
    
    public func `return`(in queue: DispatchQueue) -> Task<TaskResponse> {
        return Task<TaskResponse>.init { (updatedProgressTo, completeWith, configurations) in
            self.onCompletion { response in
                queue.async {
                    completeWith(response)
                }
            }
            
            self.onProgress { progress in
                queue.async {
                    updatedProgressTo(progress)
                }
            }
            
            configurations = self.callbackHandler.configurations
        }
    }
    
}

//public extension Task where TaskResponse == HTTPResponse<Data, Swift.Error> {
//
//    public func filterStatusCodes(_ statusCodes: Range<Int>, onError: @escaping (Int) -> Error) -> Task<TaskResponse> {
//        return self.mapResponse { immutableResponse in
//            var response = immutableResponse
//            guard let httpResponse = response.httpURLResponse else { return response }
//
//            if statusCodes.contains(httpResponse.statusCode) {
//                return response
//            } else {
//                response.result = TaskResponse.TaskResult.failure(onError(httpResponse.statusCode))
//                return response
//            }
//        }
//    }
//
//}

public extension Task where TaskResponse.Value == Data {
    
    func mapSuccess<NewValue: Decodable, NewResponse: Response>(as decodable: NewValue.Type, using jsonDecoder: JSONDecoder = JSONDecoder(), onError: @escaping (Swift.Error) -> Error)
        -> Task<NewResponse>
        where
        NewResponse.Value == NewValue,
        NewResponse.Error == Error
    {
        return self.flatMapSuccess { data -> NewResponse.TaskResult in
            do {
                let parsedData = try jsonDecoder.decode(decodable, from: data)
                return .success(parsedData)
            } catch let error as Error {
                return .failure(error)
            } catch {
                return .failure(onError(error))
            }
        }
    }
    
}

public extension Task where TaskResponse.Value == Data, TaskResponse.Error == Swift.Error {
    
    func mapSuccess<NewValue: Decodable, NewResponse: Response>(as decodable: NewValue.Type, using jsonDecoder: JSONDecoder = JSONDecoder())
        -> Task<NewResponse>
        where
        NewResponse.Value == NewValue,
        NewResponse.Error == Error
    {
        return self.flatMapSuccess { data -> Result<NewValue, Error> in
            do {
                let parsedData = try jsonDecoder.decode(decodable, from: data)
                return .success(parsedData)
            } catch {
                return .failure(error)
            }
        }
    }
    
}

//open class Task<TaskResponse: Response> {
//    public typealias Value = TaskResponse.Value
//    public typealias Error = TaskResponse.Error
//    public typealias TaskResult = TaskResponse.TaskResult
//
//    private typealias Callbacker = CallbackHandler<TaskResponse>
//
//    private let callbackHandler: Callbacker
//
//    public private(set) var status: TaskResponse.Status
//    public private(set) var progress: Double
//
//    public var isRunning: Bool {
//        switch self.status {
//        case .running: return true
//        case .completed, .cancelled, .paused: return false
//        }
//    }
//
//    public var didFinish: Bool {
//        switch self.status {
//        case .running, .paused: return false
//        case .completed, .cancelled: return true
//        }
//    }
//
//    public init(_ contructor: (@escaping TaskResponse.ProgressCallback, @escaping TaskResponse.CompletionCallback, inout TaskConfigurations) -> Void) {
//        self.callbackHandler = Callbacker()
//        self.status = .running
//        self.progress = 0
//
//        let internalProgressHandler: TaskResponse.ProgressCallback = { progress in
//            self.progress = progress
//            self.callbackHandler.progress(to: progress)
//        }
//
//        let internalCompletionHandler: TaskResponse.CompletionCallback = { response in
//            self.status = .completed(response)
//            self.callbackHandler.complete(with: response)
//        }
//
//        contructor(internalProgressHandler, internalCompletionHandler, &self.callbackHandler.configurations)
//    }
//
//    public convenience init(completedWith httpResponse: TaskResponse) {
//        self.init { didProgressTo, fulfillWith, _ in
//            didProgressTo(1)
//            fulfillWith(httpResponse)
//        }
//    }
//
//    public func cancel() {
//        self.callbackHandler.cancel()
//    }
//
//    public func resume() {
//        self.callbackHandler.resume()
//    }
//
//    public func pause() {
//        self.callbackHandler.pause()
//    }
//
//    // MARK: Callbacks
//
//    @discardableResult
//    open func onCompletion(_ handler: @escaping TaskResponse.CompletionCallback) -> CallbackCanceller {
//        switch self.status {
//        case .running, .paused:
//            return self.callbackHandler.addCompletionHandler(handler)
//        case .completed(let response):
//            handler(response)
//            return CallbackCanceller(cancel: {})
//        case .cancelled:
//            return CallbackCanceller(cancel: {})
//        }
//    }
//
//    @discardableResult
//    open func onProgress(_ handler: @escaping TaskResponse.ProgressCallback) -> CallbackCanceller {
//        switch self.status {
//        case .running, .paused:
//            return self.callbackHandler.addProgressHandler(handler)
//        case .completed:
//            handler(1)
//            return CallbackCanceller(cancel: {})
//        case .cancelled:
//            return CallbackCanceller(cancel: {})
//        }
//    }
//
//    @discardableResult
//    open func onSuccess(_ handler: @escaping TaskResponse.SuccessCallback) -> CallbackCanceller {
//        return self.onCompletion { response in
//            guard case let .success(value) = response.result else { return }
//
//            handler(value)
//        }
//    }
//
//    @discardableResult
//    open func onFailure(_ handler: @escaping TaskResponse.FailureCallback) -> CallbackCanceller {
//        return self.onCompletion { response in
//            guard case let .failure(error) = response.result else { return }
//
//            handler(error)
//        }
//    }
//
//    // MARK: Maps
//
//    open func mapResponse<NewResponse: Response>(_ mapResponse: @escaping (TaskResponse) -> NewResponse) -> Task<NewResponse> {
//        return .init { (updatedProgressTo, completeWith, configurations) in
//            self.onCompletion { response in
//                completeWith(mapResponse(response))
//            }
//
//            self.onProgress(updatedProgressTo)
//
//            configurations = self.callbackHandler.configurations
//        }
//    }
//
//    public func mapResult<NewResponse: Response>(_ mapResult: @escaping (TaskResponse.TaskResult) -> NewResponse.TaskResult) -> Task<NewResponse> {
//        return self.mapResponse { $0.mapResult(mapResult) }
//    }
//
//    public func map<NewResponse: Response>(success successMap: @escaping (Value) -> NewResponse.Value, failure failureMap: @escaping (Error) -> NewResponse.Error) -> Task<NewResponse> {
//        return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
//    }
//
//    public func mapSuccess<NewResponse: Response>(_ successMap: @escaping (Value) -> NewResponse.Value) -> Task<NewResponse> where NewResponse.Error == Error {
//        return self.map(success: { successMap($0) }, failure: { $0 })
//    }
//
//    public func mapFailure<NewResponse: Response>(_ failureMap: @escaping (Error) -> NewResponse.Error) -> Task<NewResponse> where NewResponse.Value == Value {
//        return self.map(success: { $0 }, failure: { failureMap($0) })
//    }
//
//    public func flatMapSuccess<NewResponse: Response>(_ successMap: @escaping (Value) -> NewResponse.TaskResult) -> Task<NewResponse> where NewResponse.Error == Error {
//        return self.mapResult { result in
//            switch result {
//            case .success(let value): return successMap(value)
//            case .failure(let error): return .failure(error)
//            }
//        }
//    }
//
//    public func flatMapFailure<NewResponse: Response>(_ failureMap: @escaping (Error) -> NewResponse.TaskResult) -> Task<NewResponse> where NewResponse.Value == Value {
//        return self.mapResult { result in
//            switch result {
//            case .success(let value): return .success(value)
//            case .failure(let error): return failureMap(error)
//            }
//        }
//    }
//
//    // MARK - Thread
//
//    public func `return`(in queue: DispatchQueue) -> Task<TaskResponse> {
//        return Task<TaskResponse>.init { (updatedProgressTo, completeWith, configurations) in
//            self.onCompletion { response in
//                queue.async {
//                    completeWith(response)
//                }
//            }
//
//            self.onProgress { progress in
//                queue.async {
//                    updatedProgressTo(progress)
//                }
//            }
//
//            configurations = self.callbackHandler.configurations
//        }
//    }
//
//}
//
//public extension Task where TaskResponse == HTTPResponse<Data, Swift.Error> {
//
//    public func filterStatusCodes(_ statusCodes: Range<Int>, onError: @escaping (Int) -> Error) -> Task<TaskResponse> {
//        return self.mapResponse { immutableResponse in
//            var response = immutableResponse
//            guard let httpResponse = response.httpURLResponse else { return response }
//
//            if statusCodes.contains(httpResponse.statusCode) {
//                return response
//            } else {
//                response.result = TaskResponse.TaskResult.failure(onError(httpResponse.statusCode))
//                return response
//            }
//        }
//    }
//
//}
//
//public extension Task where TaskResponse.Value == Data {
//
//    func mapSuccess<NewValue: Decodable, NewResponse: Response>(as decodable: NewValue.Type, using jsonDecoder: JSONDecoder = JSONDecoder(), onError: @escaping (Swift.Error) -> Error)
//        -> Task<NewResponse>
//        where
//        NewResponse.Value == NewValue,
//        NewResponse.Error == Error
//    {
//        return self.flatMapSuccess { data -> NewResponse.TaskResult in
//            do {
//                let parsedData = try jsonDecoder.decode(decodable, from: data)
//                return .success(parsedData)
//            } catch let error as Error {
//                return .failure(error)
//            } catch {
//                return .failure(onError(error))
//            }
//        }
//    }
//
//}
//
//public extension Task where TaskResponse.Value == Data, TaskResponse.Error == Swift.Error {
//
//    func mapSuccess<NewValue: Decodable, NewResponse: Response>(as decodable: NewValue.Type, using jsonDecoder: JSONDecoder = JSONDecoder())
//        -> Task<NewResponse>
//        where
//        NewResponse.Value == NewValue,
//        NewResponse.Error == Error
//    {
//        return self.flatMapSuccess { data -> Result<NewValue, Error> in
//            do {
//                let parsedData = try jsonDecoder.decode(decodable, from: data)
//                return .success(parsedData)
//            } catch {
//                return .failure(error)
//            }
//        }
//    }
//
//}
