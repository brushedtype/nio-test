//
//  HTTPServerResponseEncoder.swift
//  HTTPServer
//
//  Created by Edward Wellbrook on 06/05/2020.
//  Copyright © 2020 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

final class HTTPServerResponseEncoder: ChannelOutboundHandler {

    typealias OutboundIn = HTTPServerResponse
    typealias OutboundOut = HTTPServerResponsePart


    private func writeHead(context: ChannelHandlerContext, response: HTTPServerResponse) -> EventLoopFuture<Void> {
        context.eventLoop.assertInEventLoop()

        let contentLength = response.body?.length ?? 0

        var headers = HTTPHeaders(response.headers)
        headers.add(name: "Content-Length", value: "\(contentLength)")

        let head = HTTPResponseHead(
            version: .http1_1,
            status: response.status,
            headers: headers
        )

        return context.write(self.wrapOutboundOut(.head(head)))
    }

    private func writeHead(context: ChannelHandlerContext, response: HTTPServerResponse, promise: EventLoopPromise<Void>?) {
        context.eventLoop.assertInEventLoop()

        let contentLength = response.body?.length ?? 0

        var headers = HTTPHeaders(response.headers)
        headers.add(name: "Content-Length", value: "\(contentLength)")

        let head = HTTPResponseHead(
            version: .http1_1,
            status: response.status,
            headers: headers
        )

        context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    }

    private func writeBody(context: ChannelHandlerContext, body: ResponseBody) -> EventLoopFuture<Void> {
        context.eventLoop.assertInEventLoop()

        switch body.contents {
        case .buffer(let buffer):
            return context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))))
        }
    }

    private func writeBody(context: ChannelHandlerContext, body: ResponseBody, promise: EventLoopPromise<Void>?) {
        context.eventLoop.assertInEventLoop()

        switch body.contents {
        case .buffer(let buffer):
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
        }
    }

    private func writeEnd(context: ChannelHandlerContext) -> EventLoopFuture<Void> {
        context.eventLoop.assertInEventLoop()
        return context.writeAndFlush(self.wrapOutboundOut(.end(nil)))
    }

    private func writeEnd(context: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        context.eventLoop.assertInEventLoop()
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
    }


    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.eventLoop.assertInEventLoop()

        print("writing response!")

        let response = self.unwrapOutboundIn(data)

        self.writeHead(context: context, response: response, promise: nil)

        if let body = response.body {
            self.writeBody(context: context, body: body, promise: nil)
        }

        self.writeEnd(context: context).cascade(to: promise)
    }

}
