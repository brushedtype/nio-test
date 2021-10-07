//
//  HTTPServerRequestDecoder.swift
//  HTTPServer
//
//  Created by Edward Wellbrook on 06/05/2020.
//  Copyright © 2020 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

final class HTTPServerRequestDecoder: ChannelInboundHandler {

    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    /// Tracks current HTTP server state
    enum RequestState {
        case ready
        case awaitingBody(Request)
        case awaitingEnd(Request)
        case complete(Request)
    }

    var state: RequestState = .ready


    func channelActive(context: ChannelHandlerContext) {
        self.beginDecoding(context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }

    private var decodingStarted = false

    private func beginDecoding(context: ChannelHandlerContext) {
        precondition(self.decodingStarted == false)
        self.decodingStarted = true

        context.fireChannelActive()
        context.read()
    }

    func handlerAdded(context: ChannelHandlerContext) {
        if context.channel.isActive {
            self.beginDecoding(context: context)
        }
    }

    private func errorInvalidPartAndClose(part: HTTPRequestDecoder.InboundOut, context: ChannelHandlerContext) {
        print("invalid part \(part) for state \(self.state)")
        context.close(promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch part {
        case .head(let head):
            switch self.state {
            case .ready:
                let request = Request(head: head, eventloop: context.eventLoop)
                self.state = .awaitingBody(request)
                context.fireChannelRead(self.wrapInboundOut(request))
            default:
                self.errorInvalidPartAndClose(part: part, context: context)
            }

        case .body(_):
            fatalError("body part not supported")

        case .end(_):
            switch self.state {
            case .awaitingBody(let request):
                self.state = .complete(request)
            case .awaitingEnd(let request):
                self.state = .complete(request)
            default:
                self.errorInvalidPartAndClose(part: part, context: context)
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.read()
    }

}
