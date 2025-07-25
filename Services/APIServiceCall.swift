//
//  APIServiceCall.swift
//  Vitesse
//
//  Created by Perez William on 04/07/2025.
//

import Foundation

class APIService {
    
    // des protocoles pour pouvoir injecter des mocks lors des tests
    let urlSession: URLSessionProtocol
    private let tokenManager: AuthTokenPersistenceProtocol
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoderProtocol // Utilise le protocole
    
    let baseURL = URL(string: "http://127.0.0.1:8080")!
    
    init(
        urlSession: URLSessionProtocol = URLSession.shared,
        tokenManager: AuthTokenPersistenceProtocol = AuthTokenPersistence(),
        jsonEncoder: JSONEncoderProtocol = JSONEncoder() // Accepte le protocole
    ) {
        self.urlSession = urlSession
        self.tokenManager = tokenManager
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = jsonEncoder
    }
    
    // POUR les appels qui attendent une réponse à décoder.
    func performRequest<T: Decodable>(
        to endpoint: String,
        method: HTTPMethod,
        payload: (any Encodable)? = nil,
        needsAuth: Bool = true
    ) async throws -> T {
        // Le coeur de la logique est dans la méthode privée.
        let (data, _) = try await performBaseRequest(to: endpoint, method: method, payload: payload, needsAuth: needsAuth)
        
        do {
            // On décode la réponse en type T.
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw APIServiceError.responseDecodingFailed(error)
        }
    }
    
    // POur les appels qui n'attendent PAS de réponse à décoder (DELETE, ou POST comme `register`).
    func performRequest(
        to endpoint: String,
        method: HTTPMethod,
        payload: (any Encodable)? = nil,
        needsAuth: Bool = true
    ) async throws {
        
        _ = try await performBaseRequest(to: endpoint, method: method, payload: payload, needsAuth: needsAuth)
    }
    
    //  CŒUR DE LA LOGIQUE PARTAGÉE
    private func performBaseRequest(
        to endpoint: String,
        method: HTTPMethod,
        payload: (any Encodable)?,
        needsAuth: Bool
    ) async throws -> (Data, URLResponse) {
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if needsAuth {
            guard let token = try tokenManager.retrieveToken() else {
                throw APIServiceError.tokenInvalidOrExpired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let payload {
            do {
                request.httpBody = try jsonEncoder.encode(payload)
            } catch {
                throw APIServiceError.requestEncodingFailed(error)
            }
        }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIServiceError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            // cas est très peu probable
            throw APIServiceError.unexpectedStatusCode(-1)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Le serveur a répondu avec un code d'erreur (4xx, 5xx)
            throw APIServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }
        
        return (data, response)
    }
}


enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}
