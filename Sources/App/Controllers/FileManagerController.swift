//
//  LSController.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-23.
//

import Vapor
import CoreFoundation

class FileManagerController {
    
    enum FileManagerErrors: Error {
        case ServerError
    }
    
    func index(_ req: Request) throws -> Future<[FileItem]> {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/ls", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        do {
            var lsResult = [FileItem]()
            let items = try FileManager.default.contentsOfDirectory(atPath: workingPath.path)
            for item in items {
                let itemURL = workingPath.appendingPathComponent(item)
                guard let itemMD5 = FileUtilities.md5(for: itemURL),
                      let attributes = FileUtilities.attributes(for: itemURL) else { continue }
                let modDate = attributes.lastUpdated
                let remotePath = FileUtilities.remotePath(for: itemURL, from: FileUtilities.baseURL)
                let isBinary = FileUtilities.isBinary(itemURL)
                let isDirectory = attributes.isDirectory
                let fileItem = FileItem(name: remotePath, isDeleted: false, isDirectory: isDirectory, isBinary: isBinary, md5: itemMD5, modDate: modDate, parentDir: requestedPath)
                lsResult.append(fileItem)
            }
            return req.eventLoop.newSucceededFuture(result: lsResult)
        } catch {
            return req.eventLoop.newFailedFuture(error: FileManagerErrors.ServerError)
        }
    }
    
    func mkdir(_ req: Request) throws -> HTTPResponseStatus {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/mkdir", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        do {
            try FileManager.default.createDirectory(at: workingPath, withIntermediateDirectories: true, attributes: nil)
            return HTTPResponseStatus.init(statusCode: 200)
        } catch {
            return HTTPResponseStatus.init(statusCode: 500)
        }
    }
    
    func touch(_ req: Request) throws -> HTTPResponseStatus {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/touch", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        if FileManager.default.createFile(atPath: workingPath.path, contents: nil, attributes: nil) {
            return HTTPResponseStatus.init(statusCode: 200)
        } else {
            return HTTPResponseStatus.init(statusCode: 500)
        }
    }
    
    func mv(_ req: Request) throws -> HTTPResponseStatus {
        do {
            guard let from = req.query[String.self, at: "from"],
                  let to = req.query[String.self, at: "to"] else { return HTTPResponseStatus.init(statusCode: 500) }
            
            let moveObject = MoveObject(from: from, to: to)
            try FileManager.default.moveItem(at: moveObject.fromURL, to: moveObject.toURL)
            return HTTPResponseStatus.init(statusCode: 200)
        } catch {
            return HTTPResponseStatus.init(statusCode: 500)
        }
    }
    
    func read(_ req: Request) throws -> Future<String> {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/read", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        do {
            if FileManager.default.fileExists(atPath: workingPath.path) {
                let contents = try String(contentsOf: workingPath)
                return req.eventLoop.newSucceededFuture(result: contents)
            } else {
                return req.eventLoop.newFailedFuture(error: NotFound())
            }
        } catch {
            return req.eventLoop.newSucceededFuture(result: "")
        }
    }
    
    func binaryRead(_ req: Request) throws -> Future<Response> {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/binaryread", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
    
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workingPath.path, isDirectory: &isDir), !isDir.boolValue else {
            return req.eventLoop.newFailedFuture(error: NotFound())
        }
        
        // stream the file
        return try req.streamFile(at: workingPath.path)
    }
    
    func write(_ req: Request) throws -> HTTPResponseStatus {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/write", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        
        let contentType = req.http.headers["Content-Type"]
        if contentType.contains("text/plain"), let bytes = req.http.body.data {
            let content = String(data: bytes, encoding: String.Encoding.utf8)
            do {
                try content?.write(to: workingPath, atomically: true, encoding: String.Encoding.utf8)
                return HTTPResponseStatus.init(statusCode: 200)
            } catch {
                return HTTPResponseStatus.init(statusCode: 403)
            }
        }
        return HTTPResponseStatus.init(statusCode: 500)
    }
    
    func upload(_ req: Request) throws -> HTTPResponseStatus {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/upload", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        do {
            guard let payload = req.http.body.data else { return HTTPResponseStatus.init(statusCode: 500) }
            try payload.write(to: workingPath)
            return HTTPResponseStatus.init(statusCode: 200)
        } catch {
            return HTTPResponseStatus.init(statusCode: 200)
        }
    }
    
    func rm(_ req: Request) throws -> HTTPResponseStatus {
        let path = req.http.url.absoluteString
        let requestedPath = path.replacingOccurrences(of: "/rmdir", with: "").replacingOccurrences(of: "/rm", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        do {
            try FileManager.default.removeItem(at: workingPath)
            return HTTPResponseStatus.init(statusCode: 200)
        } catch {
            return HTTPResponseStatus.init(statusCode: 403)
        }
    }
    
}
