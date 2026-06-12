import Foundation

enum APIConfig {
    // Development server running on this Mac. Replace this with the public HTTPS
    // server URL before sharing builds with other phones.
    static let baseURL = "http://192.168.1.212:3000"

    static let identifyEndpoint = "\(baseURL)/api/identify"
    static let artworkEndpoint = "\(baseURL)/api/artwork"
}
