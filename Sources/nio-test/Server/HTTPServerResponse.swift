//
//  HTTPServerResponse.swift
//  HTTPServer
//
//  Created by Edward Wellbrook on 06/05/2020.
//  Copyright © 2020 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

public final class HTTPServerResponse {

    public var status: HTTPResponseStatus
    public var headers: [(String, String)]
    public var body: ResponseBody?

    public init(status: HTTPResponseStatus, headers: [(String, String)], body: ResponseBody?) {
        self.status = status
        self.headers = headers
        self.body = body
    }

}
