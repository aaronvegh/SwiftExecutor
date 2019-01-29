//
//  FileUtils.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-28.
//

import Foundation
import CoreFoundation
import Crypto
import Random
import Vapor

struct FileAttributes {
    let name: String
    let fileSize: String
    let isHidden: Bool
    let isDirectory: Bool
    let lastUpdated: Date
}

struct FileUtilities {
    
    static let baseURL = URL(fileURLWithPath: "/home/codewerks/project")
//    static let baseURL = URL(fileURLWithPath: "/Users/aaron/Developer/CodewerksProjects/SwiftExecutor")

    static let ignoreFiles = [".build", ".git", "tmp"]
    
    /// The resource keys we want to grab for each file
    static let propertyKeys: [URLResourceKey] = [.nameKey, .fileSizeKey, .isHiddenKey, .isDirectoryKey, .contentAccessDateKey]
    
    /// Return the attributes for the given file, which should've been cached when initializing
    static func attributes(for file: URL) -> FileAttributes? {
        do {
            let resourceKeys: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: file.path)
            guard let fileType = resourceKeys[.type] as? FileAttributeType,
                  let fileSize = resourceKeys[.size] as? Int64,
                  let lastUpdated = resourceKeys[.modificationDate] as? Date else { return nil }
            let fileName = file.lastPathComponent
            let isHidden = file.lastPathComponent.first == "."
            let isDirectory = fileType == FileAttributeType.typeDirectory
            
            let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            
            return FileAttributes(name: fileName, fileSize: fileSizeWithUnit, isHidden: isHidden, isDirectory: isDirectory, lastUpdated: lastUpdated)
        } catch {
            return nil
        }
    }

    static func md5(for url: URL) -> String? {
        if let attributes = FileUtilities.attributes(for: url) {
            do {
                let digest = Digest(algorithm: .sha256)
                try digest.reset()
                if attributes.isDirectory {
                    let remotePath = FileUtilities.remotePath(for: url, from: FileUtilities.baseURL)
                    try digest.update(data: remotePath)
                    let digest = try digest.finish()
                    return digest.hexEncodedString()
                } else {
                    let data = try Data(contentsOf: url)
                    try digest.update(data: data)
                    let digest = try digest.finish()
                    return digest.hexEncodedString()
                }
            } catch {
                return ""
            }
        } else {
            return ""
        }
    }
    
    /// Return whether file is binary by seeing if we can read the text
    static func isBinary(_ url: URL) -> Bool {
        do {
            _ = try String(contentsOf: url, encoding: String.Encoding.utf8)
            return false
        } catch {
            return true
        }
    }
    
    /// Return the URL minus the root, which represents the remote file path
    static func remotePath(for url: URL, from root: URL) -> String {
        let rootString = root.absoluteString
        let urlString = url.absoluteString
        return urlString.replacingOccurrences(of: rootString, with: "")
    }
    
    static func shell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        
        return output
    }

}
