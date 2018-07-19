//
//  CallbackHandler.swift
//  B2BUIModule
//
//  Created by Gustavo Vergara Garcia on 21/12/17.
//  Copyright © 2017 Mobfiq. All rights reserved.
//

import Foundation

class CallbackHandler<TaskResponse: Response> {
    
    typealias CompletionCallback = TaskResponse.CompletionCallback
    typealias ProgressCallback = TaskResponse.ProgressCallback
    
    private var completionHandlers: Handlers<CompletionCallback> = []
    private var progressHandlers: Handlers<ProgressCallback> = []
    
    var configurations: TaskConfigurations

    init() {
        self.configurations = TaskConfigurations()
    }
    
    func addCompletionHandler(_ handler: @escaping CompletionCallback) -> CallbackCanceller {
        let token = self.completionHandlers.append(handler)
        
        return CallbackCanceller { [weak self] in
            self?.completionHandlers.remove(token)
        }
    }
    
    func addProgressHandler(_ handler: @escaping ProgressCallback) -> CallbackCanceller {
        let token = self.progressHandlers.append(handler)
        
        return CallbackCanceller { [weak self] in
            self?.progressHandlers.remove(token)
        }
    }
    
    func progress(to newProgress: Double) {
        for progressHandler in self.progressHandlers {
            progressHandler(newProgress)
        }
    }
    
    func complete(with response: TaskResponse) {
        for completionHandler in self.completionHandlers {
            completionHandler(response)
        }
        
        self.clearCallbacks()
    }
    
    func cancel() {
        self.configurations.cancel?()
        
        self.clearCallbacks()
    }
    
    func resume() {
        self.configurations.resume?()
    }

    func pause() {
        self.configurations.pause?()
    }
    
    private func clearCallbacks() {
        self.completionHandlers.removeAll()
        self.progressHandlers.removeAll()
        
        self.configurations.cancel = nil
        self.configurations.resume = nil
        self.configurations.pause = nil
    }
    
}

public struct TaskConfigurations {
    public var cancel: (() -> Void)?
    public var resume: (() -> Void)?
    public var pause: (() -> Void)?
}

public struct CallbackCanceller {
    public let cancel: () -> Void
    
    public init(cancel: @escaping () -> Void) {
        self.cancel = cancel
    }
}

fileprivate typealias HandlerToken = Int
fileprivate struct Handlers<T>: Sequence, ExpressibleByArrayLiteral {
    
    fileprivate typealias KeyValue = (key: HandlerToken, value: T)
    
    private var currentKey: Int = 0
    private var elements = [KeyValue]()
    
    /// The type of the elements of an array literal.
    fileprivate typealias ArrayLiteralElement = T
    
    /// Creates an instance initialized with the given elements.
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        for element in elements {
            _ = self.append(element)
        }
    }
    
    fileprivate mutating func append(_ value: T) -> HandlerToken {
        self.currentKey = self.currentKey &+ 1
        
        self.elements.append((key: self.currentKey, value: value))
        
        return self.currentKey
    }
    
    @discardableResult
    fileprivate mutating func remove(_ token: HandlerToken) -> T? {
        for i in self.elements.indices where self.elements[i].key == token {
            return self.elements.remove(at: i).value
        }
        return nil
    }
    
    fileprivate mutating func removeAll(keepCapacity: Bool = false) {
        self.elements.removeAll(keepingCapacity: keepCapacity)
    }
    
    fileprivate func makeIterator() -> AnyIterator<T> {
        return AnyIterator(self.elements.map { $0.value }.makeIterator())
    }
}
