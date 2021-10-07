//
//  HTTPBody.swift
//  HTTPServer
//
//  Created by Edward Wellbrook on 06/05/2020.
//  Copyright © 2020 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

public final class ResponseBody {

    enum Contents {
        case buffer(ByteBuffer)
    }

    let contents: Contents


    public var length: Int {
        switch self.contents {
        case .buffer(let buffer):
            return buffer.readableBytes
        }
    }


    init(buffer: ByteBuffer) {
        self.contents = .buffer(buffer)
    }

    public convenience init(data: Data) {
        self.init(buffer: ByteBuffer(data: data))
    }

}
