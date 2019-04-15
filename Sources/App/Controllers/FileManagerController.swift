//
//  LSController.swift
//  App
//
//  Created by Aaron Vegh on 2018-12-23.
//

import Vapor
import Foundation
import Fluent

class FileManagerController {
    
    enum FileManagerErrors: Error {
        case ServerError
    }
    
    func alive(_ req: Request) throws -> HTTPResponseStatus {
        return HTTPResponseStatus.init(statusCode: 200)
    }
    
    func index(_ req: Request) throws -> Future<[FileItem]> {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return req.eventLoop.newFailedFuture(error: FileManagerErrors.ServerError) }
        let requestedPath = path.replacingOccurrences(of: "/ls", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        let promise: EventLoopPromise<[FileItem]> = req.eventLoop.newPromise()
        DispatchQueue.global().async {
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: workingPath.path)
                for item in items {
                    if !FileUtilities.ignoreFiles.contains(item) {
                        let itemURL = workingPath.appendingPathComponent(item)
                        let remotePath = FileUtilities.remotePath(for: itemURL, from: FileUtilities.baseURL)
                        guard let itemMD5 = FileUtilities.md5(for: itemURL),
                              let attributes = FileUtilities.attributes(for: itemURL) else { continue }
                        let modDate = attributes.lastUpdated
                        let isBinary = FileUtilities.isBinary(itemURL)
                        let isDirectory = attributes.isDirectory
                        
                        let existingItem = try FileItem.query(on: req)
                            .filter(\FileItem.name == remotePath)
                            .first()
                            .wait()
                        
                        if existingItem == nil {
                            _ = try FileItem(name: remotePath, isDeleted: false, isDirectory: isDirectory, isBinary: isBinary, md5: itemMD5, modDate: modDate, parentDir: requestedPath)
                                .create(on: req)
                                .wait()
                        }
                    }
                }
                
                let flattenedResults = try FileItem.contentsOfDirectory(using: req, directory: requestedPath).wait()
                promise.succeed(result: flattenedResults)
            } catch (let error) {
                logger?.info("500 Failure: \(error.localizedDescription)")
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    func filesChanged(_ req: Request) throws -> Future<HTTPResponseStatus> {
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        return try req.content.decode(FileChangeObject.self).flatMap { changeObject in
            switch changeObject.flags {
            case "IN_MOVED_FROM", "IN_DELETE":
                logger?.info("Acting on \(changeObject.flags)")
                // set is_deleted to true for this file
                let workingPath = URL(fileURLWithPath: changeObject.path)
                let remotePath = FileUtilities.remotePath(for: workingPath, from: FileUtilities.baseURL)
                let promise: EventLoopPromise<HTTPResponseStatus> = req.eventLoop.newPromise()
                DispatchQueue.global().async {
                    do {
                        logger?.info("Looking for match on \(remotePath)")
                        let existingItem = try FileItem.query(on: req)
                            .filter(\FileItem.name == remotePath)
                            .first()
                            .wait()
                        
                        logger?.info("Found existing item: \(String(describing: existingItem))")
                        if let fileItem = existingItem {
                            fileItem.isDeleted = true
                            _ = try fileItem.update(on: req).wait()
                        }
                        
                        logger?.info("Touching .is_dirty...")
                        let checkPath = URL(fileURLWithPath: "/home/codewerks/.is_dirty")
                        FileManager.default.createFile(atPath: checkPath.path, contents: nil, attributes: nil)
                        self.setOwnership(for: checkPath)
                        promise.succeed(result: HTTPResponseStatus.init(statusCode: 200))
                    } catch (let error) {
                        logger?.info("Crapped out!")
                        promise.fail(error: error)
                    }
                }
                return promise.futureResult
            default:
                // touch .is_dirty
                logger?.info("Touching .is_dirty...")
                let checkPath = URL(fileURLWithPath: "/home/codewerks/.is_dirty")
                if FileManager.default.createFile(atPath: checkPath.path, contents: nil, attributes: nil) {
                    self.setOwnership(for: checkPath)
                    logger?.info("Success")
                    return Future.map(on: req) { HTTPResponseStatus.init(statusCode: 200) }
                } else {
                    logger?.info("Failed!")
                    return Future.map(on: req) { HTTPResponseStatus.init(statusCode: 500) }
                }
            }
        }        
    }
    
    func mkdir(_ req: Request) throws -> HTTPResponseStatus {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return HTTPResponseStatus.init(statusCode: 500) }
        let requestedPath = path.replacingOccurrences(of: "/mkdir", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        do {
            try FileManager.default.createDirectory(at: workingPath, withIntermediateDirectories: true, attributes: nil)
            setOwnership(for: workingPath)
            logger?.info("200 Success")
            return HTTPResponseStatus.init(statusCode: 200)
        } catch (let error) {
            logger?.info("500 Failure: \(error.localizedDescription)")
            return HTTPResponseStatus.init(statusCode: 500)
        }
    }
    
    func touch(_ req: Request) throws -> HTTPResponseStatus {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return HTTPResponseStatus.init(statusCode: 500) }
        let requestedPath = path.replacingOccurrences(of: "/touch", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        if FileManager.default.createFile(atPath: workingPath.path, contents: nil, attributes: nil) {
            setOwnership(for: workingPath)
            logger?.info("200 Success")
            return HTTPResponseStatus.init(statusCode: 200)
        } else {
            logger?.info("500 Failure: Can't create file at path: \(workingPath.path)")
            return HTTPResponseStatus.init(statusCode: 500)
        }
    }
    
    func mv(_ req: Request) throws -> Future<HTTPResponseStatus> {
        let logger = try? req.sharedContainer.make(Logger.self)
        
        let from = req.query[String.self, at: "from"]?.removingPercentEncoding ?? ""
        let to = req.query[String.self, at: "to"]?.removingPercentEncoding ?? ""
        
        logger?.info(req.http.url.path)
        
        let moveObject = MoveObject(from: from, to: to)
        let fromPath = FileUtilities.remotePath(for: moveObject.fromURL, from: FileUtilities.baseURL)
        let toPath = FileUtilities.remotePath(for: moveObject.toURL, from: FileUtilities.baseURL)
        do {
            try FileManager.default.moveItem(at: moveObject.fromURL, to: moveObject.toURL)
        } catch (_) {
            return Future.map(on: req) { HTTPResponseStatus.init(statusCode: 500) }
        }
        
        let promise: EventLoopPromise<HTTPResponseStatus> = req.eventLoop.newPromise()
        DispatchQueue.global().async {
            do {
                let fileItem = try FileItem.query(on: req)
                    .filter(\FileItem.name == fromPath)
                    .first()
                    .wait()
                if let fromItem = fileItem {
                    fromItem.isDeleted = true
                    _ = try fromItem.update(on: req).wait()
                }
                
                let toItem = try FileItem.query(on: req)
                    .filter(\FileItem.name == toPath)
                    .first()
                    .wait()
                if let toItem = toItem {
                    toItem.isDeleted = false
                    _ = try toItem.update(on: req).wait()
                }
                promise.succeed(result: HTTPResponseStatus.init(statusCode: 200))
            } catch (let error) {
                logger?.info("500 Failure: \(error.localizedDescription)")
                promise.fail(error: error)
            }
        }
        logger?.info("200 Success")
        return promise.futureResult
    }
    
    func read(_ req: Request) throws -> Future<String> {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return req.eventLoop.newFailedFuture(error: NotFound()) }
        let requestedPath = path.replacingOccurrences(of: "/read", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        do {
            if FileManager.default.fileExists(atPath: workingPath.path) {
                let contents = try String(contentsOf: workingPath)
                logger?.info("200 Success")
                return req.eventLoop.newSucceededFuture(result: contents)
            } else {
                logger?.info("500 Failure: File not available at \(workingPath.path)")
                return req.eventLoop.newFailedFuture(error: NotFound())
            }
        } catch (let error) {
            logger?.info("500 Failure: \(error.localizedDescription)")
            return req.eventLoop.newFailedFuture(error: NotFound())
        }
    }
    
    func binaryRead(_ req: Request) throws -> Future<Response> {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return req.eventLoop.newFailedFuture(error: NotFound()) }
        let requestedPath = path.replacingOccurrences(of: "/binaryread", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
    
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workingPath.path, isDirectory: &isDir), !isDir.boolValue else {
            logger?.info("500 Failure: File doesn't exist at \(workingPath.path)")
            return req.eventLoop.newFailedFuture(error: NotFound())
        }
        
        // stream the file
        logger?.info("200 Success")
        return try req.streamFile(at: workingPath.path)
    }
    
    func write(_ req: Request) throws -> HTTPResponseStatus {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return HTTPResponseStatus.init(statusCode: 500) }
        let requestedPath = path.replacingOccurrences(of: "/write", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        let contentType = req.http.headers["Content-Type"]
        if contentType.contains("text/plain"), let bytes = req.http.body.data {
            let content = String(data: bytes, encoding: String.Encoding.utf8)
            do {
                try content?.write(to: workingPath, atomically: true, encoding: String.Encoding.utf8)
                setOwnership(for: workingPath)
                logger?.info("200 Success")
                return HTTPResponseStatus.init(statusCode: 200)
            } catch (let error) {
                logger?.info("500 Failure: \(error.localizedDescription)")
                return HTTPResponseStatus.init(statusCode: 403)
            }
        }
        logger?.info("500 Failure: File is not plain text")
        return HTTPResponseStatus.init(statusCode: 500)
    }
    
    func upload(_ req: Request) throws -> HTTPResponseStatus {
        guard let path = req.http.url.absoluteString.removingPercentEncoding else { return HTTPResponseStatus.init(statusCode: 500) }
        let requestedPath = path.replacingOccurrences(of: "/upload", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        do {
            guard let payload = req.http.body.data else { return HTTPResponseStatus.init(statusCode: 500) }
            try payload.write(to: workingPath)
            setOwnership(for: workingPath)
            logger?.info("200 Success")
            return HTTPResponseStatus.init(statusCode: 200)
        } catch (let error) {
            logger?.info("500 Failure: \(error.localizedDescription)")
            return HTTPResponseStatus.init(statusCode: 200)
        }
    }
    
    func rm(_ req: Request) throws -> Future<HTTPResponseStatus> {
        let path = req.http.url.absoluteString.removingPercentEncoding ?? ""
        let requestedPath = path.replacingOccurrences(of: "/rmdir", with: "").replacingOccurrences(of: "/rm", with: "")
        let workingPath = requestedPath.count > 0 ? FileUtilities.baseURL.appendingPathComponent(requestedPath) : FileUtilities.baseURL
        
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        let promise: EventLoopPromise<HTTPResponseStatus> = req.eventLoop.newPromise()
        DispatchQueue.global().async {
            do {
                let remotePath = FileUtilities.remotePath(for: workingPath, from: FileUtilities.baseURL)
                
                logger?.info("Find deleting item at \(remotePath)")
                let fileItem = try FileItem.query(on: req)
                    .filter(\FileItem.name == remotePath)
                    .first()
                    .wait()
                
                if let rmItem = fileItem {
                    logger?.info("Marking deleted: \(remotePath)")
                    rmItem.isDeleted = true
                    _ = try rmItem.update(on: req).wait()
                }
                
                try FileManager.default.removeItem(at: workingPath)
                logger?.info("200 Success")

                promise.succeed(result: .ok)
            } catch (let error) {
                logger?.info("500 Failure: \(error.localizedDescription)")
                promise.fail(error: error)
            }
        }
        return promise.futureResult
    }
    
    func isDirty(_ req: Request) throws -> HTTPResponseStatus {
        let logger = try? req.sharedContainer.make(Logger.self)
        logger?.info(req.http.url.path)
        
        let checkPath = URL(fileURLWithPath: "/home/codewerks/.is_dirty")
        if FileManager.default.fileExists(atPath: checkPath.path) {
            try? FileManager.default.removeItem(at: checkPath)
            logger?.info("200 Success")
            return HTTPResponseStatus.init(statusCode: 200)
        } else {
            logger?.info("403 File not found")
            return HTTPResponseStatus.init(statusCode: 403)
        }
    }
    
    private func setOwnership(for file: URL) {
        guard let path = file.path.removingPercentEncoding else { return }
        let task = Process()
        task.launchPath = "/bin/chown"
        task.arguments = ["codewerks:codewerks", path]
        task.launch()
    }
    
}
