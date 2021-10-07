//
//  HTTPHandler.swift
//  usb-connect
//
//  Created by Edward Wellbrook on 26/03/2021.
//  Copyright © 2021 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

final class HTTPClientHandler: ChannelInboundHandler {

    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart


    private enum ResponseState {
        case awaitingResponse
        case head(HTTPResponseHead)
        case body(HTTPResponseHead, Data)
        case error(Error)
        case complete
    }


    private let request: ClientRequest
    private let completionHandler: RequestCompletionHandler

    private var responseState: ResponseState = .awaitingResponse


    init(request: ClientRequest, completion: @escaping RequestCompletionHandler) {
        self.request = request
        self.completionHandler = completion
    }


    func channelActive(context: ChannelHandlerContext) {
        self.beginRequest(context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.close(promise: nil)
    }

    func handlerAdded(context: ChannelHandlerContext) {
        if context.channel.isActive {
            self.beginRequest(context: context)
        }
    }

    private var requestHasStarted = false

    private func beginRequest(context: ChannelHandlerContext) {
        precondition(self.requestHasStarted == false)
        self.requestHasStarted = true

        switch self.request {
        case .standard(let request):
            self.makeRequest(channel: context.channel, request: request)
        }
    }

    func channelUnregistered(context: ChannelHandlerContext) {
        print("channel unregistered")

        switch self.responseState {
        case .awaitingResponse:
            self.completionHandler(nil, nil, .handlerRemovedBeforeResponse)
            self.responseState = .complete
        case .head(let head):
            self.completionHandler(head, nil, nil)
            self.responseState = .complete
        case .body(let head, let body):
            self.completionHandler(head, body, nil)
            self.responseState = .complete
        case .error(let error):
            self.completionHandler(nil, nil, .connectionError(error))
            self.responseState = .complete
        case .complete:
            fatalError("already removed")
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let clientResponse = self.unwrapInboundIn(data)

        switch clientResponse {
        case .head(let responseHead):
            self.responseState = .head(responseHead)

            self.scheduleDelayedRead(context: context)

        case .body(let byteBuffer):
            switch self.responseState {
            case .awaitingResponse:
                self.responseState = .error(RequestError.readBodyBadInternalState)
                context.close(promise: nil)

            case .head(let head):
                self.responseState = .body(head, Data(byteBuffer.readableBytesView))

            case .body(let head, let body):
                var newBody = body
                newBody.append(contentsOf: byteBuffer.readableBytesView)
                self.responseState = .body(head, newBody)

            case .error, .complete:
                preconditionFailure("invalid state")
            }

            self.scheduleDelayedRead(context: context)

        case .end:
            print("read end")
            context.close(promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Swift.Error) {
        print("errorCaught:", error)
        self.responseState = .error(error)
        context.close(promise: nil)
    }


    private func scheduleDelayedRead(context: ChannelHandlerContext) {
        context.eventLoop.scheduleTask(in: .milliseconds(100)) {
            context.read()
        }
    }

    private func makeRequest(channel: Channel, request: URLRequest) {
        var headers = HTTPHeaders()
        headers.add(contentsOf: Array(request.allHTTPHeaderFields ?? [:]))

        var uri = "/"

        if let url = request.url {
            uri = url.path

            if let query = url.query {
                uri += "?" + query
            }
        }

        let requestMethod = HTTPMethod(rawValue: request.httpMethod ?? "GET")
        let requestHead = HTTPRequestHead(version: .http1_1,  method: requestMethod, uri: uri, headers: headers)
        channel.write(self.wrapOutboundOut(.head(requestHead)), promise: nil)

        if let data = request.httpBody {
            channel.write(self.wrapOutboundOut(.body(.byteBuffer(.init(data: data)))), promise: nil)
        }

        channel.writeAndFlush(self.wrapOutboundOut(.end(nil))).whenComplete { _ in
            print("request written")

            print("start reading response")
            channel.read()
        }
    }

}
