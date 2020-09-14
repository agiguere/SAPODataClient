//
//  File.swift
//  
//
//  Created by Alexandre Giguere on 2020-09-14.
//

import Foundation

public struct EntitySetPayload<T: Decodable>: Decodable {
    public let entities: [T]
    
    private enum CodingKeys: String, CodingKey {
        case d
    }
    
    private enum EntitySetCodingKeys: String, CodingKey {
        case results
    }
}

extension EntitySetPayload {
    public init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        let container = try rootContainer.nestedContainer(keyedBy: EntitySetCodingKeys.self, forKey: .d)
        
        let entities = try container.decode([T].self, forKey: .results)
        
        self.init(entities: entities)
    }
}
