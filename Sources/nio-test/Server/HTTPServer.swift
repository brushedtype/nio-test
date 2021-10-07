//
//  HTTPServer.swift
//  HTTPServer
//
//  Created by Edward Wellbrook on 06/05/2020.
//  Copyright © 2020 Brushed Type. All rights reserved.
//

import Foundation
import Network
import NIO
import NIOHTTP1
import NIOTransportServices


open class HTTPServer {

    public typealias ResponseBlock = (Result<HTTPServerResponse, Error>) -> Void
    public typealias RequestHandlerBlock = (Request, @escaping ResponseBlock) -> Void


    private var eventLoopGroup: NIOTSEventLoopGroup?
    private let threadPool = NIOThreadPool(numberOfThreads: 1)
    private let idleTimeout: TimeAmount

    private var serverChannel: Channel?


    public init(idleTimeout: TimeAmount = .seconds(60)) {
        self.idleTimeout = idleTimeout
    }

    open func listen(endpoint: NWEndpoint, handler: @escaping RequestHandlerBlock) throws {
        let eventLoopGroup = NIOTSEventLoopGroup()

        self.threadPool.start()

        let bootstrap = NIOTSListenerBootstrap(group: eventLoopGroup)
            .serverChannelOption(NIOTSChannelOptions.enablePeerToPeer, value: true)
            .serverChannelOption(NIOTSChannelOptions.allowLocalEndpointReuse, value: true)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(IdleStateHandler(allTimeout: self.idleTimeout)).flatMap {
                    channel.pipeline.configureHTTPServerPipeline(withPipeliningAssistance: true, withErrorHandling: true).flatMap {
                        channel.pipeline.addHandlers([
                            HTTPServerRequestDecoder(),
                            HTTPServerResponseEncoder(),
                            HTTPServerHandler(handler: handler)
                        ])
                    }
                }
            }
            .childChannelOption(ChannelOptions.autoRead, value: false)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)

        let chan = try bootstrap.bind(endpoint: endpoint).wait()
        self.serverChannel = chan
        debugPrint("listening on \(chan.localAddress?.description ?? endpoint.debugDescription)")

        self.eventLoopGroup = eventLoopGroup
    }

    open func stop() {
        self.eventLoopGroup?.shutdownGracefully({ _ in })

        if let channel = self.serverChannel {
            channel.close(promise: nil)
            do {
                try channel.closeFuture.wait()
            } catch {
                debugPrint(error)
            }
        }

        self.serverChannel = nil
    }

}
