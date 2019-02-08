import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    let fmController = FileManagerController()
    router.get("ls", use: fmController.index)
    router.get(["ls", all], use: fmController.index)
    
    router.get("mkdir", use: fmController.mkdir)
    router.get(["mkdir", all], use: fmController.mkdir)
    
    router.get("touch", use: fmController.touch)
    router.get(["touch", all], use: fmController.touch)
    
    router.post("mv", use: fmController.mv)
    
    router.get("read", use: fmController.read)
    router.get(["read", all], use: fmController.read)
    
    router.get("binaryread", use: fmController.binaryRead)
    router.get(["binaryread", all], use: fmController.binaryRead)
    
    router.post("write", use: fmController.write)
    router.post(["write", all], use: fmController.write)
    
    router.post("upload", use: fmController.upload)
    router.post(["upload", all], use: fmController.upload)
    
    router.get("rm", use: fmController.rm)
    router.get(["rm", all], use: fmController.rm)
    
    router.get("rmdir", use: fmController.rm)
    router.get(["rmdir", all], use: fmController.rm)
    
    router.get("isDirty", use: fmController.isDirty)
}
