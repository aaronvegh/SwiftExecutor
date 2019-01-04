//
//  FileUtils.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-28.
//

import Foundation
import CoreServices
import Crypto
import Random

struct FileAttributes {
    let name: String
    let fileSize: String
    let isHidden: Bool
    let isDirectory: Bool
    let lastUpdated: Date
    let lastUpdatedAgo: String
}

struct FileUtilities {
    
    static let baseURL = URL(fileURLWithPath: "/home/codewerks/project")
    
    /// The resource keys we want to grab for each file
    static let propertyKeys: [URLResourceKey] = [kCFURLNameKey as URLResourceKey,
                                                 kCFURLFileSizeKey as URLResourceKey,
                                                 kCFURLIsHiddenKey as URLResourceKey,
                                                 kCFURLIsDirectoryKey as URLResourceKey,
                                                 kCFURLContentAccessDateKey as URLResourceKey]
    
    /// Return the attributes for the given file, which should've been cached when initializing
    static func attributes(for file: URL) -> FileAttributes? {
        do {
            let propertyKeySet: Set<URLResourceKey> = Set(FileUtilities.propertyKeys.map { $0 })
            let resourceKeys = try file.resourceValues(forKeys: propertyKeySet)
            let isDirectory = resourceKeys.isDirectory ?? false
            let fileName = resourceKeys.name ?? ""
            let fileSize = resourceKeys.fileSize ?? 0
            let isHidden = resourceKeys.isHidden ?? false
            let lastUpdated = resourceKeys.contentAccessDate ?? Date()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            let lastModAgo = timeAgoSince(lastUpdated)
            
            return FileAttributes(name: fileName, fileSize: fileSizeWithUnit, isHidden: isHidden, isDirectory: isDirectory, lastUpdated: lastUpdated, lastUpdatedAgo: lastModAgo)
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
                    try digest.update(data: url.absoluteString)
                    let digest = try digest.finish()
                    return digest.hexEncodedString()
                } else {
                    let modDate = Int(attributes.lastUpdated.timeIntervalSince1970)
                    let remotePath = FileUtilities.remotePath(for: url, from: FileUtilities.baseURL)
                    try digest.update(data: "\(remotePath)/\(modDate)")
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
