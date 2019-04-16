import Vapor

/// Creates an instance of Application. This is called from main.swift in the run target.
public func app(_ env: Environment) throws -> Application {
    var config = Config.default()
    var env = env
    var services = Services.default()
    services.register(NIOServerConfig.default(hostname: "0.0.0.0", port: 8080, maxBodySize: 100_000_000))
    try configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)
    try boot(app)
    return app
}

struct ExecutorEnvironment {
//    static let mode = "development"
    let mode = "production"
}
