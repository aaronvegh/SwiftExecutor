//
//  FileItem.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-23.
//

import FluentSQLite
import Vapor

final class FileItem: Content {
    /// The unique identifier for this `FileItem`.
    var id: UUID?
    
    /// A URL string for the file item
    var name: String?
    
    /// Has been deleted
    var isDeleted: Bool?
    
    /// is Directory
    var isDirectory: Bool?
    
    /// parent directory
    var parentDir: String?
    
    /// is Binary
    var isBinary: Bool?
    
    /// The file's current md5 hash
    var md5: String?
    
    /// the file's modified date
//    var modDate: Date?
    
    /// Creates a new `Todo`.
    init(name: String, isDeleted: Bool, isDirectory: Bool, isBinary: Bool, md5: String, parentDir: String) {
        self.name = name
        self.isDeleted = isDeleted
        self.isDirectory = isDirectory
        self.isBinary = isBinary
        self.md5 = md5
        self.parentDir = parentDir
    }
}

extension FileItem: SQLiteUUIDModel { }

/// Allows `FileItem` to be used as a dynamic migration.
extension FileItem: Migration { }

/// Allows `FileItem` to be used as a dynamic parameter in route definitions.
extension FileItem: Parameter { }
