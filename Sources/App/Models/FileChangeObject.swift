//
//  FileChangeObject.swift
//  App
//
//  Created by Aaron Vegh on 2019-03-14.
//

import Vapor

struct FileChangeObject: Content {
    var path: String
    var flags: String
    
    init(path: String, flags: String) {
        self.path = path
        self.flags = flags
    }
}
