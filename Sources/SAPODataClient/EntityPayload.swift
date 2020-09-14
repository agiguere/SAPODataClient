//
//  File.swift
//  
//
//  Created by Alexandre Giguere on 2020-09-14.
//

import Foundation

public struct EntityPayload<T: Decodable>: Decodable {
    public let entity: T
    
    private enum CodingKeys: String, CodingKey {
        case d
    }
}

extension EntityPayload {
    public init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        let entity = try rootContainer.decode(T.self, forKey: .d)
        
        self.init(entity: entity)
    }
}
