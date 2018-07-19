//
//  HTTPTask.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 17/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

open class HTTPTask<Value, Error>: TaskProtocol {
    public typealias TaskResponse = HTTPResponse<Value, Error>
    
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
    
//    public init(noConfig contructor: (@escaping TaskResponse.ProgressCallback, @escaping TaskResponse.CompletionCallback) -> Void) {
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
//        contructor(internalProgressHandler, internalCompletionHandler)
//    }
    
    public convenience init(completedWith httpResponse: TaskResponse) {
        self.init { didProgressTo, fulfillWith, configurations in
            
//            func unsafePointer<T>(to pointer: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<T> {
//                return pointer
//            }
//            unsafePointer(to: &configurations).deallocate()
            
//            withUnsafePointer(to: httpResponse, { pointer -> Void in
//                pointer.deallocate()
//                return ()
//            })
//            let pointer = UnsafePointer<TaskConfigurations>.init(bitPattern: 0)!
//            pointer.deallocate()
            
            DispatchQueue.global(qos: .unspecified).asyncAfter(deadline: .now(), execute: {
                didProgressTo(1)
                fulfillWith(httpResponse)
            })
//            didProgressTo(1)
//            fulfillWith(httpResponse)
        }
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
    
    public func mapResponse<NewValue, NewError>(_ mapResponse: @escaping (TaskResponse) -> HTTPTask<NewValue, NewError>.TaskResponse) -> HTTPTask<NewValue, NewError> {
        return .init { (updatedProgressTo, completeWith, configurations) in
            self.onCompletion { response in
                completeWith(mapResponse(response))
            }
            
            self.onProgress(updatedProgressTo)
            
            configurations = self.callbackHandler.configurations
        }
    }
    
    public func mapResult<NewValue, NewError>(_ mapResult: @escaping (TaskResult) -> Result<NewValue, NewError>) -> HTTPTask<NewValue, NewError> {
        return self.mapResponse { $0.mapResult(mapResult) }
    }
    
    public func map<NewValue, NewError>(success successMap: @escaping (Value) -> NewValue, failure failureMap: @escaping (Error) -> NewError) -> HTTPTask<NewValue, NewError> {
        return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
    }
    
    public func mapSuccess<NewValue>(_ successMap: @escaping (Value) -> NewValue) -> HTTPTask<NewValue, Error> {
        return self.map(success: { successMap($0) }, failure: { $0 })
    }
    
    public func mapFailure<NewError>(_ failureMap: @escaping (Error) -> NewError) -> HTTPTask<Value, NewError> {
        return self.map(success: { $0 }, failure: { failureMap($0) })
    }
    
    public func flatMapSuccess<NewValue>(_ successMap: @escaping (Value) -> Result<NewValue, Error>) -> HTTPTask<NewValue, Error> {
        return self.mapResult { result in
            switch result {
            case .success(let value): return successMap(value)
            case .failure(let error): return .failure(error)
            }
        }
    }
    
    public func flatMapFailure<NewError>(_ failureMap: @escaping (Error) -> Result<Value, NewError>) -> HTTPTask<Value, NewError> {
        return self.mapResult { result in
            switch result {
            case .success(let value): return .success(value)
            case .failure(let error): return failureMap(error)
            }
        }
    }
    
    public func filterStatusCodes(_ statusCodes: Range<Int>, onError: @escaping (Int) -> Error) -> HTTPTask<Value, Error> {
        return self.mapResponse { immutableResponse in
            var response = immutableResponse
            guard let httpResponse = response.httpURLResponse else { return response }
            
            if statusCodes.contains(httpResponse.statusCode) {
                return response
            } else {
                response.result = .failure(onError(httpResponse.statusCode))
                return response
            }
        }
    }
    
    public func onStatusCode(_ statusCode: Int, returnError error: Error) -> HTTPTask<Value, Error> {
        return self.mapResponse { immutableResponse in
            var response = immutableResponse
            guard let httpResponse = response.httpURLResponse else { return response }
            
            if statusCode == httpResponse.statusCode {
                return response
            } else {
                response.result = .failure(error)
                return response
            }
        }
    }
    
}

public extension HTTPTask where TaskResponse.Value == Data {
    
    func mapSuccess<NewValue: Decodable>(as decodable: NewValue.Type, using jsonDecoder: JSONDecoder = JSONDecoder(), onError: @escaping (Swift.Error) -> Error) -> HTTPTask<NewValue, Error> {
        return self.flatMapSuccess { data in
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

public extension HTTPTask where TaskResponse.Value == Data, TaskResponse.Error == Swift.Error {
    
    public convenience init(withRequest request: URLRequest, using urlSession: URLSession = URLSession.shared) {
        self.init { (didProgressTo, fulfillWith, configurations) in
            let disposeBag = KVODisposeBag()
            let dataTask = urlSession.dataTask(with: request, completionHandler: { (data, urlResponse, error) in
                fulfillWith(HTTPResponse(urlRequest: request, urlResponse: urlResponse, rawData: data, rawError: error))
                
                disposeBag.clear()
            })
            
            dataTask.observe(\URLSessionDataTask.countOfBytesReceived, options: .initial) { (dataTask, change) in
                var progress = Double(dataTask.countOfBytesSent + dataTask.countOfBytesReceived) / Double(dataTask.countOfBytesExpectedToSend + dataTask.countOfBytesExpectedToReceive)
                
                if progress.isNaN || progress < 0 {
                    progress = 0
                } else if progress > 1 {
                    progress = 1
                }
                
                didProgressTo(progress)
            }.dispose(in: disposeBag)
            
            configurations.cancel = {
                dataTask.cancel()
            }
            
            configurations.resume = {
                dataTask.resume()
            }
            
            configurations.pause = {
                dataTask.suspend()
            }
        }
    }
    
    func mapSuccess<NewValue: Decodable>(as decodable: NewValue.Type, using jsonDecoder: JSONDecoder = JSONDecoder()) -> HTTPTask<NewValue, Error> {
        return self.flatMapSuccess { data in
            do {
                let parsedData = try jsonDecoder.decode(decodable, from: data)
                return .success(parsedData)
            } catch {
                return .failure(error)
            }
        }
    }
    
}

//open class HTTPTask<Value, Error>: Task<HTTPResponse<Value, Error>> {
//    public typealias TaskResponse = HTTPResponse<Value, Error>
//
//    public func mapResult<NewValue, NewError>(_ mapResult: @escaping (TaskResponse.TaskResult) -> Result<NewValue, NewError>) -> Task<HTTPResponse<NewValue, NewError>> {
//        return self.mapResponse { $0.mapResult(mapResult) }
//    }
//
//    public func map<NewValue, NewError>(success successMap: @escaping (Value) -> NewValue, failure failureMap: @escaping (Error) -> NewError) -> Task<HTTPResponse<NewValue, NewError>> {
//        return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
//    }
//
//    public func mapSuccess<NewValue>(_ successMap: @escaping (Value) -> NewValue) -> Task<HTTPResponse<NewValue, Error>> {
//        return self.map(success: { successMap($0) }, failure: { $0 })
//    }
//
//    public func mapFailure<NewError>(_ failureMap: @escaping (Error) -> NewError) -> Task<HTTPResponse<Value, NewError>> {
//        return self.map(success: { $0 }, failure: { failureMap($0) })
//    }
//
//    public func flatMapSuccess<NewValue>(_ successMap: @escaping (Value) -> Result<NewValue, Error>) -> Task<HTTPResponse<NewValue, Error>> {
//        return self.mapResult { result in
//            switch result {
//            case .success(let value): return successMap(value)
//            case .failure(let error): return .failure(error)
//            }
//        }
//    }
//
//    public func flatMapFailure<NewError>(_ failureMap: @escaping (Error) -> Result<Value, NewError>) -> Task<HTTPResponse<Value, NewError>> {
//        return self.mapResult { result in
//            switch result {
//            case .success(let value): return .success(value)
//            case .failure(let error): return failureMap(error)
//            }
//        }
//    }
//}

//public func mapResult<NewValue, NewError>(_ mapResult: @escaping (TaskResponse.TaskResult) -> Result<NewValue, NewError>) -> HTTPTask<NewValue, NewError> {
//    return self.mapResponse { $0.mapResult(mapResult) }
//}
//
//public func map<NewValue, NewError>(success successMap: @escaping (Value) -> NewValue, failure failureMap: @escaping (Error) -> NewError) -> HTTPTask<NewValue, NewError> {
//    return self.mapResponse { $0.map(success: successMap, failure: failureMap) }
//}
//
//public func mapSuccess<NewValue>(_ successMap: @escaping (Value) -> NewValue) -> HTTPTask<NewValue, Error> {
//    return self.map(success: { successMap($0) }, failure: { $0 })
//}
//
//public func mapFailure<NewError>(_ failureMap: @escaping (Error) -> NewError) -> HTTPTask<Value, NewError> {
//    return self.map(success: { $0 }, failure: { failureMap($0) })
//}
//
//public func flatMapSuccess<NewValue>(_ successMap: @escaping (Value) -> Result<NewValue, Error>) -> HTTPTask<NewValue, Error> {
//    return self.mapResult { result in
//        switch result {
//        case .success(let value): return successMap(value)
//        case .failure(let error): return .failure(error)
//        }
//    }
//}
//
//public func flatMapFailure<NewError>(_ failureMap: @escaping (Error) -> Result<Value, NewError>) -> HTTPTask<Value, NewError> {
//    return self.mapResult { result in
//        switch result {
//        case .success(let value): return .success(value)
//        case .failure(let error): return failureMap(error)
//        }
//    }
//}
