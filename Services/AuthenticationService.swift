//
//  AuthService.swift
//  Vitesse
//
//  Created by Perez William on 30/06/2025.
//

import Foundation

// MARK: Implementation
class AuthService: APIService, AuthenticationServiceProtocol {
        
        func login(credentials: AuthRequestDTO) async throws -> AuthResponseDTO {
                do {
                        return try await performRequest(
                                to: "user/auth",
                                method: .POST,
                                payload: credentials,
                                needsAuth: false
                        )
                } catch let error as APIServiceError {
                        if case .unexpectedStatusCode(401) = error { throw APIServiceError.invalidCredentials }
                        if case .unexpectedStatusCode(403) = error { throw APIServiceError.invalidCredentials }
                        throw error
                }
        }
        
        func register(with details: UserRegisterRequestDTO) async throws {
                try await performRequest(
                        to: "user/register",
                        method: .POST,
                        payload: details,
                        needsAuth: false
                )
        }
}

