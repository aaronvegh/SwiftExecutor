//
//  MoveObject.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-30.
//

import Vapor

struct MoveObject: Content {
    var from: String
    var to: String
    
    init(from: String, to: String) {
        self.from = from
        self.to = to
    }
    
    var fromURL: URL {
        let root = FileUtilities.baseURL
        return root.appendingPathComponent(from)
    }
    
    var toURL: URL {
        let root = FileUtilities.baseURL
        return root.appendingPathComponent(to)
    }
}
