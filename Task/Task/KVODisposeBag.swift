//
//  KVODisposeBag.swift
//  MobfiqKit
//
//  Created by Gustavo Vergara Garcia on 12/12/17.
//  Copyright © 2017 Mobfiq. All rights reserved.
//

import Foundation

public class KVODisposeBag {
    
    private var observations: [NSKeyValueObservation]
    
    public init() {
        self.observations = []
    }
    
    deinit {
        self.clear()
    }
    
    public func add(_ observation: NSKeyValueObservation) {
        self.observations.append(observation)
    }
    
    public func clear() {
        self.observations.forEach { $0.invalidate() }
        self.observations = []
    }
    
}

public extension NSKeyValueObservation {
    
    func dispose(in disposeBag: KVODisposeBag) {
        disposeBag.add(self)
    }
    
}
