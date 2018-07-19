//
//  TaskProtocol.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 17/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

public protocol TaskProtocol {
    associatedtype TaskResponse where TaskResponse: Response
    associatedtype Value = TaskResponse.Value
    associatedtype Error = TaskResponse.Error
    associatedtype TaskResult = TaskResponse.TaskResult
    
    var status: TaskStatus<TaskResponse> { get }
    var progress: Double { get }
    
    var isRunning: Bool { get }
    var didFinish: Bool { get }
    
    var configurations: TaskConfigurations { get }

    // MARK: Contructors
    
    init(_ contructor: (@escaping TaskResponse.ProgressCallback, @escaping TaskResponse.CompletionCallback, inout TaskConfigurations) -> Void)
    
    // MARK: Control
    
    func cancel()
    func resume()
    func pause()
    
    // MARK: Callbacks
    
    @discardableResult
    func onCompletion(_ handler: @escaping TaskResponse.CompletionCallback) -> CallbackCanceller
    @discardableResult
    func onProgress(_ handler: @escaping TaskResponse.ProgressCallback) -> CallbackCanceller
    @discardableResult
    func onSuccess(_ handler: @escaping TaskResponse.SuccessCallback) -> CallbackCanceller
    @discardableResult
    func onFailure(_ handler: @escaping TaskResponse.FailureCallback) -> CallbackCanceller
    
    // MARK: Maps
    
//    func mapResponse<NewTask: TaskProtocol>(_ mapResponse: @escaping (TaskResponse) -> NewTask.TaskResponse) -> NewTask
//    
//    func mapResult<NewTask: TaskProtocol>(_ mapResult: @escaping (TaskResponse.TaskResult) -> NewTask.TaskResult) -> NewTask
//    
//    func map<NewTask: TaskProtocol>(success successMap: @escaping (Value) -> NewTask.Value, failure failureMap: @escaping (Error) -> NewTask.Error) -> NewTask
//    
//    func mapSuccess<NewTask: TaskProtocol>(_ successMap: @escaping (Value) -> NewTask.Value) -> NewTask where NewTask.Error == Error
//    
//    func mapFailure<NewTask: TaskProtocol>(_ failureMap: @escaping (Error) -> NewTask.Error) -> NewTask where NewTask.Value == Value
//    
//    func flatMapSuccess<NewTask: TaskProtocol>(_ successMap: @escaping (Value) -> NewTask.TaskResult) -> NewTask where NewTask.Error == Error
//    
//    func flatMapFailure<NewTask: TaskProtocol>(_ failureMap: @escaping (Error) -> NewTask.TaskResult) -> NewTask where NewTask.Value == Value
    
}

extension TaskProtocol {
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
    
    public init(completedWith response: TaskResponse) {
        self.init { didProgressTo, fulfillWith, _ in
            didProgressTo(1)
            fulfillWith(response)
        }
    }
    
    public func `return`(in queue: DispatchQueue) -> Self {
        return Self.init { (updatedProgressTo, completeWith, configurations) in
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
            
            configurations = self.configurations
        }
    }
}
