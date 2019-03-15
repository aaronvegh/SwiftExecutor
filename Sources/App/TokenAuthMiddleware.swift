//
//  TokenAuthMiddleware.swift
//  App
//
//  Created by Aaron Vegh on 2019-01-01.
//

import Vapor

public final class TokenAuthMiddleware: Middleware, ServiceType {
    
    enum TokenError: Error, Debuggable {
        var identifier: String {
            switch self {
            case .ServerError(_): return "Server Error"
            case .AuthenticationError(_): return "Authentication Error"
            }
        }
        
        var reason: String {
            switch self {
            case .ServerError(let reason): return reason
            case .AuthenticationError(let reason): return reason
            }
        }
        
        case ServerError(String)
        case AuthenticationError(String)
    }
    
    public static func makeService(for container: Container) throws -> Self {
        return .init()
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        let path = request.http.url.absoluteString.removingPercentEncoding ?? ""
        if !path.contains("filesChanged") {
            if let bearer = request.http.headers.bearerAuthorization {
                
                let ownerToken = FileUtilities.shell("sudo curl -s --unix-socket /dev/lxd/sock http://x/1.0/config/user.token")
//                    let ownerToken = "c0336726-4a6d-4dc4-9450-64f52fb908aa"
                
                let httpRequest = HTTPRequest(method: .GET, url: "/users/valid", headers: ["Authorization": "Bearer \(bearer.token)"])
                
                return HTTPClient.connect(scheme: .https, hostname: "codewerks.app", port: 81, on: request).flatMap(to: Response.self, { client in
                    return client.send(httpRequest).flatMap(to: Response.self) { response in
                        if response.body.description == ownerToken {
                            return try next.respond(to: request)
                        } else {
                            return request.eventLoop.newFailedFuture(error: TokenError.AuthenticationError("Failed to get auth response from upstream."))
                        }
                    }
                })
            } else {
                return request.eventLoop.newFailedFuture(error: TokenError.ServerError("Client didn't send auth header."))
            }
        } else {
            return try next.respond(to: request)
        }
    }
}
