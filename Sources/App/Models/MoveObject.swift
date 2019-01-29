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
        guard let from = from.removingPercentEncoding else { return root }
        return root.appendingPathComponent(from)
    }
    
    var toURL: URL {
        let root = FileUtilities.baseURL
        guard let to = to.removingPercentEncoding else { return root }
        return root.appendingPathComponent(to)
    }
}
