//
//  TaskStatus.swift
//  Task
//
//  Created by Gustavo Vergara Garcia on 12/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

public enum TaskStatus<TaskResponse: Response> {
    case completed(TaskResponse)
    case running
    case cancelled
    case paused
}

public extension TaskStatus where TaskResponse.Value: Equatable, TaskResponse.Error: Equatable {
    
    public static func ==(lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.running, .running):
            return true
        case (.completed(let lhsResponse), .completed(let rhsResponse)):
            return lhsResponse == rhsResponse
        case (.cancelled, .cancelled):
            return true
        case (.paused, .paused):
            return true
        default:
            return false
        }
    }
    
    public static func !=(lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        return !(lhs == rhs)
    }
    
}

public extension TaskStatus {
    
    public static func ==(lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.running, .running):
            return true
        case (.completed, .completed):
            return true
        case (.cancelled, .cancelled):
            return true
        case (.paused, .paused):
            return true
        default:
            return false
        }
    }
    
    public static func !=(lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        return !(lhs == rhs)
    }
    
}
