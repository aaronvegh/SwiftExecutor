//
//  UserToken.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-31.
//

import Vapor
import JWT

struct User: JWTPayload {
    var id: Int
    var token: String
    
    func verify(using signer: JWTSigner) throws {
        // nothing to verify
    }
}
