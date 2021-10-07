//
//  HTTPServerHandler.swift
//  HTTPServer
//
//  Created by Edward Wellbrook on 06/05/2020.
//  Copyright © 2020 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

final class HTTPServerHandler: ChannelInboundHandler {

    typealias InboundIn = Request
    typealias OutboundOut = HTTPServerResponse

    let handler: HTTPServer.RequestHandlerBlock

    init(handler: @escaping HTTPServer.RequestHandlerBlock) {
        self.handler = handler
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = self.unwrapInboundIn(data)
        self.handleBasicRequest(context: context, request: request, handler: self.handler)
    }

    func handleBasicRequest(context: ChannelHandlerContext, request: Request, handler: HTTPServer.RequestHandlerBlock) {
        let promise = context.eventLoop.makePromise(of: HTTPServerResponse.self)
        handler(request, promise.completeWith(_:))

        promise.futureResult.flatMap { response -> EventLoopFuture<Void> in
            print("start response write")
            return context.writeAndFlush(self.wrapOutboundOut(response))
        }.flatMap { _ -> EventLoopFuture<Void> in
            print("response written, closing")
            return context.close() // close the channel immediately after writing response
        }.whenComplete { result in
            print("server channel closed")
        }
    }

}
