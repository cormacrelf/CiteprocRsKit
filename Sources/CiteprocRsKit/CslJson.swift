//
//  CslJson.swift
//  
//
//  Created by Cormac Relf on 31/8/21.
//

import Foundation

// If anyone needs this to be Decodable (unlikely), there's https://paul-samuels.com/blog/2019/01/02/swift-heterogeneous-codable-array/
// TODO: make this Equatable and Hashable
public struct CslReference: Encodable {
    public var id: String
    public var type: String
    public var variables: [String: CslVariable]

    public init(id: String, type: String, variables: [String: CslVariable]) {
        self.id = id
        self.type = type
        self.variables = variables
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: CodingKeys.id)
        try container.encode(self.type, forKey: CodingKeys.type)
        for (key, variable) in self.variables {
            try container.encode(variable, forKey: CodingKeys.init(stringValue: key)!)
        }
    }
    
    enum CodingKeys: CodingKey {
        var intValue: Int? {
            return nil
        }
        
        init?(intValue: Int) {
            return nil
        }
        
        var stringValue: String {
            switch self {
            case .id: return "id"
            case .type: return "type"
            case .variable(let s): return s
            }
        }
        
        init?(stringValue: String) {
            switch stringValue {
            case "id": self = .id; break
            case "type": self = .type; break
            default: self = .variable(stringValue); break
            }
        }
        
        case id
        case type
        case variable(String)
    }
}

public enum CslVariable: Encodable {
    
    case string(String)
    case number(NumString)
    case names([CslName])
    case date(CslDate)
    /// CSL 1.1
    case title(CslTitle)
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let s): try s.encode(to: encoder)
        case .number(let n): try n.encode(to: encoder)
        case .names(let n): try n.encode(to: encoder)
        case .date(let d): try d.encode(to: encoder)
        case .title(let t): try t.encode(to: encoder)
        }
    }
}

public enum NumString: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .int(let i): try i.encode(to: encoder)
        case .string(let s): try s.encode(to: encoder)
        }
    }
    case int(Int)
    case string(String)
}

public struct CslName: Encodable {
    public var family: String?
    public var given: String?
    
    public init(family: String? = nil, given: String? = nil) {
        self.family = family
        self.given = given
    }
}

public enum CslDate: Encodable {
    case edtf(String)
    case legacy(Legacy)
    
    public struct Legacy: Encodable {
        public var dateParts: [[Int]]?
        public var circa: Bool?
        // TODO: more fields, also circa is called approximate now?
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .edtf(let edtf): return try edtf.encode(to: encoder)
        case .legacy(let legacy): return try legacy.encode(to: encoder)
        }
    }
}

public enum CslTitle: Encodable {
    case string(String)
    case object(TitleObject)
    
    public struct TitleObject: Encodable {
        public init(full: String? = nil, main: String? = nil, sub: [String]? = nil, short: String? = nil) {
            self.full = full
            self.main = main
            self.sub = sub
            self.short = short
        }
        /// "The full title string for the item; should generally be redundant, as it's simply the main + the sub titles and/or alternate title"
        public var full: String?
        public var main: String?
        public var sub: [String]?
        public var short: String?
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let s): return try s.encode(to: encoder)
        case .object(let o): return try o.encode(to: encoder)
        }
    }
}
