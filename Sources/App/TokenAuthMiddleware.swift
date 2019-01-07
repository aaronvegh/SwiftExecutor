//
//  TokenAuthMiddleware.swift
//  App
//
//  Created by Aaron Vegh on 2019-01-01.
//

import Vapor

public final class TokenAuthMiddleware: Middleware, ServiceType {
    
    enum TokenError: Error {
        case ServerError
        case AuthenticationError
    }
    
    public static func makeService(for container: Container) throws -> Self {
        return .init()
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
//        let env = try Environment.detect()
//        if env.isRelease {
            if let bearer = request.http.headers.bearerAuthorization {
                
                let ownerToken = FileUtilities.shell("sudo curl -s --unix-socket /dev/lxd/sock http://x/1.0/config/user.token")
                
                let httpRequest = HTTPRequest(method: .GET, url: "/users/valid", headers: ["Authorization": "Bearer \(bearer.token)"])
                
                return HTTPClient.connect(hostname: "codewerks.app", port: 81, on: request).flatMap(to: Response.self, { client in
                    return client.send(httpRequest).flatMap(to: Response.self, { response in
                        if let remoteData = response.body.data, let remoteToken = String(data: remoteData, encoding: String.Encoding.utf8), remoteToken == ownerToken {
                            return try next.respond(to: request)
                        } else {
                            return request.eventLoop.newFailedFuture(error: TokenError.AuthenticationError)
                        }
                    })
                })
            } else {
                return request.eventLoop.newFailedFuture(error: TokenError.ServerError)
            }
//        } else {
//            return try next.respond(to: request)
//        }
    }
}
