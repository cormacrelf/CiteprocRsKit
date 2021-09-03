//
//  CslJson.swift
//
//
//  Created by Cormac Relf on 31/8/21.
//

import Foundation

// If anyone needs this to be Decodable, there's https://paul-samuels.com/blog/2019/01/02/swift-heterogeneous-codable-array/
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
            if let key = CodingKeys.init(stringValue: key) {
                guard case .variable = key else {
                    continue
                }
                try container.encode(variable, forKey: key)
            }
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
            case "id":
                self = .id
                break
            case "type":
                self = .type
                break
            default:
                self = .variable(stringValue)
                break
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

    public init(
        family: String? = nil, given: String? = nil,
        droppingParticle: String? = nil, nonDroppingParticle: String? = nil
    ) {
        self.family = family
        self.given = given
        self.droppingParticle = droppingParticle
        self.nonDroppingParticle = nonDroppingParticle
    }

    public init(
        literal: String? = nil
    ) {
        self.literal = literal
    }

    public var family: String? = nil
    public var given: String? = nil
    public var literal: String? = nil
    public var droppingParticle: String? = nil
    public var nonDroppingParticle: String? = nil

    enum CodingKeys: String, CodingKey {
        case family, given, literal
        case droppingParticle = "dropping-particle"
        case nonDroppingParticle = "non-dropping-particle"
    }
}

public enum CslDate: Encodable {

    // enable when supported
    // case edtf(String)
    case v1(V1)

    public struct V1: Encodable {

        public var dateParts: [[Int]]? = nil
        public var raw: String? = nil
        public var literal: String? = nil
        // enable when supported
        // public var edtf: String?

        public var circa: Bool? = nil
        public var season: NumString? = nil

        public init(
            dateParts: [[Int]],
            circa: Bool? = nil, season: NumString? = nil
        ) {
            self.dateParts = dateParts
            self.circa = circa
            self.season = season
        }

        public init(
            raw: String,
            circa: Bool? = nil, season: NumString? = nil
        ) {
            self.raw = raw
            self.circa = circa
            self.season = season
        }

        public init(
            literal: String,
            circa: Bool? = nil, season: NumString? = nil
        ) {
            self.literal = literal
            self.circa = circa
            self.season = season
        }

        // A Foundation.Date is pretty annoying for us, because it has no timezone information
        // and hence we cannot know which zone to render it in. It always includes a time, and this
        // will end up with off-by-one-day errors.

        // So this kind of method is no good.
        // /// Make sure you're creating date objects using GMT. Otherwise the rendered date will be wrong.
        // @available(macOS 10.12, *)
        // public init(rawFrom date: Date) {
        //     let fmt = ISO8601DateFormatter()
        //     fmt.timeZone = .init(secondsFromGMT: 0)
        //     fmt.formatOptions.remove(.withFullTime)
        //     let iso = fmt.string(from: date)
        //     self = V1(raw: iso)
        // }

        enum CodingKeys: String, CodingKey {
            case dateParts = "date-parts"
            case circa, season, literal, raw
            // case edtf
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        // case .edtf(let edtf): return try edtf.encode(to: encoder)
        case .v1(let v1): return try v1.encode(to: encoder)
        }
    }
}

public enum CslTitle: Encodable {
    case string(String)
    case object(TitleObject)

    public struct TitleObject: Encodable {
        public init(
            full: String? = nil, main: String? = nil, sub: [String]? = nil, short: String? = nil
        ) {
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
