
import CoreData
import Combine
import UIKit

extension CodingUserInfoKey {
   public static let context = CodingUserInfoKey(rawValue: "context")
}

open class SAPODataClient: NSObject {
    
    public enum Error: Swift.Error {
        case requestFailed(URLError)
        case redirection(HTTPURLResponse)
        case client(response: HTTPURLResponse, payload: SAPODataErrorPayload?)
        case server(HTTPURLResponse)
        case unknown
        case parsing(Swift.Error)
        case context(Swift.Error)
        
        init(_ error: Swift.Error) {
            switch error {
            case is URLError:
                self = .requestFailed(error as! URLError)
            case is DecodingError:
                self = .parsing(error)
            case is Error:
                self = error as! Error
            default:
                if (error as NSError).domain == NSCocoaErrorDomain {
                    self = .context(error)
                } else {
                    self = .unknown
                }
            }
        }
    }
    
    // Public Properties
    public var persitentContainer: NSPersistentContainer?
    public lazy var jsonDecoder: JSONDecoder = { JSONDecoder() }()
    public lazy var jsonEncoder: JSONEncoder = { JSONEncoder() }()
    
    private(set) public lazy var session: URLSession = {
        let sessionConfiguration: URLSessionConfiguration
        
        if let configuration = self.sessionConfiguration {
            sessionConfiguration = configuration
        } else {
            let language = Locale.preferredLanguages.first!
            
            sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.timeoutIntervalForRequest = 45
            sessionConfiguration.httpAdditionalHeaders = ["Accept" : "application/json", "Content-Type" : "application/json", "sap-language" : language.uppercased()]
        }

        return URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }()
    
    // Private Properties
    private let credential: URLCredential
    private var sessionConfiguration: URLSessionConfiguration?
    private var subscriptions = Set<AnyCancellable>()

    // MARK: Init
    public init(credential: URLCredential, sessionConfiguration: URLSessionConfiguration? = nil) {
        self.credential = credential
        self.sessionConfiguration = sessionConfiguration

        super.init()
    }
}

// MARK: - Public API
public extension SAPODataClient {
        
    func getEntitySet<T: Decodable>(for url: URL, type: T.Type) -> AnyPublisher<[T], Error> {
        return session.dataTaskPublisher(for: url)
            .tryMap(mapResponseToEntitySet)
            .mapError(Error.init)
            .eraseToAnyPublisher()
    }
    
    func getEntitySet<T: Decodable>(for request: URLRequest, type: T.Type) -> AnyPublisher<[T], Error> {
        return session.dataTaskPublisher(for: request)
            .tryMap(mapResponseToEntitySet)
            .mapError(Error.init)
            .eraseToAnyPublisher()
    }
    
    func getEntity<T: Decodable>(for url: URL, type: T.Type) -> AnyPublisher<T, Error> {
        return session.dataTaskPublisher(for: url)
            .tryMap(mapResponseToEntity)
            .mapError(Error.init)
            .eraseToAnyPublisher()
    }
    
    func getEntity<T: Decodable>(for request: URLRequest, type: T.Type) -> AnyPublisher<T, Error> {
        return session.dataTaskPublisher(for: request)
            .tryMap(mapResponseToEntity)
            .mapError(Error.init)
            .eraseToAnyPublisher()
    }
    
    func getImage(for url: URL) -> AnyPublisher<UIImage, Error> {
        return session.dataTaskPublisher(for: url)
            .tryMap(mapResponseToImage)
            .mapError(Error.init)
            .eraseToAnyPublisher()
    }
    
    func getImage(for request: URLRequest) -> AnyPublisher<UIImage, Error> {
        return session.dataTaskPublisher(for: request)
            .tryMap(mapResponseToImage)
            .mapError(Error.init)
            .eraseToAnyPublisher()
    }
    
    func logout() {
        // Delete cache
        URLCache.shared.removeAllCachedResponses()
        
        // Delete cookies
        let cookieStorage = HTTPCookieStorage.shared
        
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }
}

// MARK: - NSURLSessionTaskDelegate
extension SAPODataClient: URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authMethod = challenge.protectionSpace.authenticationMethod

        guard authMethod == NSURLAuthenticationMethodHTTPBasic else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, credential)
    }
}

// MARK: - Private API
private extension SAPODataClient {
    
    func mapResponseToEntitySet<T: Decodable>(transform: (data: Data, response: URLResponse)) throws -> [T] {
        guard let httpResponse = transform.response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 2XX Success
        if 200...299 ~= httpResponse.statusCode {
            return try decodeEntitySet(data: transform.data)
         
        // 3XX Redirection
        } else if 300...399 ~= httpResponse.statusCode {
            throw Error.redirection(httpResponse)
        
        // 4XX Client Errors
        } else if 400...499 ~= httpResponse.statusCode {
            throw Error.client(response: httpResponse, payload: decodeResponse(data: transform.data))
           
        // 5XX Server Errors
        } else if 500...599 ~= httpResponse.statusCode {
            throw Error.server(httpResponse)
            
        } else {
            throw Error.unknown
        }
    }
    
    func mapResponseToEntity<T: Decodable>(transform: (data: Data, response: URLResponse)) throws -> T {
        guard let httpResponse = transform.response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 2XX Success
        if 200...299 ~= httpResponse.statusCode {
            return try decodeEntity(data: transform.data)
         
        // 3XX Redirection
        } else if 300...399 ~= httpResponse.statusCode {
            throw Error.redirection(httpResponse)
        
        // 4XX Client Errors
        } else if 400...499 ~= httpResponse.statusCode {
            throw Error.client(response: httpResponse, payload: decodeResponse(data: transform.data))
           
        // 5XX Server Errors
        } else if 500...599 ~= httpResponse.statusCode {
            throw Error.server(httpResponse)
            
        } else {
            throw Error.unknown
        }
    }
    
    func mapResponseToImage(transform: (data: Data, response: URLResponse)) throws -> UIImage {
        guard let httpResponse = transform.response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 2XX Success
        if 200...299 ~= httpResponse.statusCode {
            return UIImage(data: transform.data)!
         
        // 3XX Redirection
        } else if 300...399 ~= httpResponse.statusCode {
            throw Error.redirection(httpResponse)
        
        // 4XX Client Errors
        } else if 400...499 ~= httpResponse.statusCode {
            throw Error.client(response: httpResponse, payload: decodeResponse(data: transform.data))
           
        // 5XX Server Errors
        } else if 500...599 ~= httpResponse.statusCode {
            throw Error.server(httpResponse)
            
        } else {
            throw Error.unknown
        }
    }
    
    func decodeResponse(data: Data) -> SAPODataErrorPayload? {
        try? JSONDecoder().decode(SAPODataErrorPayload.self, from: data)
    }
    
    func decodeEntity<T: Decodable>(data: Data) throws -> T {
        guard let persitentContainer = self.persitentContainer else {
            return try jsonDecoder.decode(EntityPayload<T>.self, from: data).entity
        }
        
        guard let codingUserInfoKeyContext = CodingUserInfoKey.context else { fatalError() }

        let context = persitentContainer.newBackgroundContext()

        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        jsonDecoder.userInfo[codingUserInfoKeyContext] = context

        let entity = try jsonDecoder.decode(EntityPayload<T>.self, from: data).entity

        try context.save()

        return entity
    }
    
    func decodeEntitySet<T: Decodable>(data: Data) throws -> [T] {
        guard let persitentContainer = self.persitentContainer else {
            return try jsonDecoder.decode(EntitySetPayload<T>.self, from: data).entities
        }
        
        guard let codingUserInfoKeyContext = CodingUserInfoKey.context else { fatalError() }

        let context = persitentContainer.newBackgroundContext()

        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        jsonDecoder.userInfo[codingUserInfoKeyContext] = context

        let entities = try jsonDecoder.decode(EntitySetPayload<T>.self, from: data).entities

        try context.save()

        return entities
    }
}

// MARK: - Internal API
extension SAPODataClient { }
