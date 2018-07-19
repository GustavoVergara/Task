//
//  ResponseError.swift
//  TaskTests
//
//  Created by Gustavo Vergara Garcia on 16/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import Foundation

open class ResponseError: NSObject {
    
    open var code: Int = 500
    open var message: String = "Ocorreu uma instabilidade, por favor tente novamente mais tarde"//NSLocalizedString("alert.systemUnstable", comment: "Erro Genérico")
    open var status: Status = .error
    
    public init(code: Int = 500, message: String = "Ocorreu uma instabilidade, por favor tente novamente mais tarde", status: ResponseError.Status? = nil) {
        self.code = code
        self.message = message
    }
    
    public init(fromDictionary dictionary: NSDictionary) {
        if let code = dictionary["Code"] as? Int {
            self.code = code
        }
        
        if let message = dictionary["Message"] as? String {
            self.message = message
        }
        
        if let statusString = dictionary["Status"] as? String, let status = Status(rawValue: statusString) {
            self.status = status
        }
    }
    
    public init(fromDictionary dictionary: [String: Any]) {
        if let code = dictionary["Code"] as? Int {
            self.code = code
        }
        
        if let message = dictionary["Message"] as? String {
            self.message = message
        }
        
        if let statusString = dictionary["Status"] as? String, let status = Status(rawValue: statusString) {
            self.status = status
        }
    }
    
    open func toDictionary() -> NSDictionary {
        let dictionary = NSMutableDictionary()
        
        dictionary["Code"] = self.code
        dictionary["Message"] = self.message
        dictionary["Status"] = self.status.rawValue
        
        return dictionary
    }
    
    public enum Status: String {
        case error
        case info
        case warning
        case fatal
    }
    
    // MARK: Equatable
    
    static func ==(lhs: ResponseError, rhs: ResponseError) -> Bool {
        return lhs.code == rhs.code
            && lhs.message == rhs.message
            && lhs.status == rhs.status
    }
}
