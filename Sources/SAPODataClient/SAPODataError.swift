//
//  File.swift
//  
//
//  Created by Alexandre Giguere on 2020-09-14.
//

import Foundation

// MARK: - ODataErrorPayload
public struct SAPODataErrorPayload: Decodable {
    private enum CodingKeys: String, CodingKey {
        case error
    }
    
    public let error: SAPODataError
}

// MARK: - ODataError
public struct SAPODataError: Decodable {
    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case inner = "innererror"
    }
    
    public let code: String
    public let message: SAPODataErrorMessage
    public let inner: SAPODataInnerError
}

// MARK: - ODataErrorMessage
public struct SAPODataErrorMessage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case language = "lang"
        case value
    }
    
    public let language: String
    public let value: String
}

// MARK: - ODataInnerError
public struct SAPODataInnerError: Decodable {
    private enum CodingKeys: String, CodingKey {
        case application
        case transactionId = "transactionid"
        case timestamp
        case resolution = "Error_Resolution"
        case details = "errordetails"
    }
    
    public let application: SAPODataErrorApplication
    public let transactionId: String
    public let timestamp: String
    public let resolution: SAPODataErrorResolution
    public let details: [SAPODataErrorDetails]
}

// MARK: - ODataErrorApplication
public struct SAPODataErrorApplication: Decodable {
    private enum CodingKeys: String, CodingKey {
        case componentId = "component_id"
        case serviceNamespace = "service_namespace"
        case serviceId = "service_id"
        case serviceVersion = "service_version"
    }
    
    public let componentId: String
    public let serviceNamespace: String
    public let serviceId: String
    public let serviceVersion: String
}

// MARK: - ODataErrorResolution
public struct SAPODataErrorResolution: Decodable {
    private enum CodingKeys: String, CodingKey {
        case transaction = "SAP_Transaction"
        case note = "SAP_Note"
    }
    
    public let transaction: String
    public let note: String
}

// MARK: - ODataErrorDetails
public struct SAPODataErrorDetails: Decodable {
    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case propertyRef = "propertyref"
        case severity
        case transition
        case target
    }
    
    public let code: String
    public let message: String
    public let propertyRef: String
    public let severity: String
    public let transition: Bool
    public let target: String
}
