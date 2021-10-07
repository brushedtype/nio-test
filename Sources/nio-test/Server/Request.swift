//
//  File.swift
//  
//
//  Created by Edward Wellbrook on 07/10/2021.
//

import Foundation
import NIO
import NIOHTTP1

private enum Error: Swift.Error {
    case closingChannelWithoutReadingBody
}

public class Request {

    enum ReadBodyError: Swift.Error {
        case missingContentType
        case invalidContentType
    }

    public let id = UUID()

    public let uri: String
    public let pathComponents: [String]
    public let method: HTTPMethod
    public internal(set) var headers: HTTPHeaders
    public internal(set) var queryItems: [URLQueryItem] = []


    init(head: HTTPRequestHead, eventloop: EventLoop) {
        self.uri = head.uri
        self.method = head.method
        self.headers = head.headers

        if let urlComponents = URLComponents(string: self.uri) {
            self.pathComponents = Array(urlComponents.path.components(separatedBy: "/").dropFirst())
            self.queryItems = urlComponents.queryItems ?? []
        } else {
            self.pathComponents = Array(self.uri.components(separatedBy: "/").dropFirst())
        }
    }

}
