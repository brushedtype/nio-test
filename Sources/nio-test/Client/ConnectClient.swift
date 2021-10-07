//
//  ConnectClient.swift
//  DopplerTransfer macOS
//
//  Created by Edward Wellbrook on 20/04/2021.
//  Copyright © 2021 Brushed Type. All rights reserved.
//

import Foundation
import NIO
import NIOHTTP1

// requests
public typealias RequestCompletionHandler = (HTTPResponseHead?, Data?, RequestError?) -> Void

// configuration / setup
public typealias RequestConfigurationHandler = (_ configureRequestPipeline: (ChannelPipeline) -> EventLoopFuture<Void>) -> Void
public typealias ConfigurationResultHandler = (Result<RequestConfigurationHandler, RequestError>) -> Void
public typealias PipelineSetup = (_ pipeline: ChannelPipeline) -> EventLoopFuture<Void>


public enum ClientRequest {
    case standard(URLRequest)

    var timeout: TimeAmount {
        switch self {
        case .standard(let req):
            return .seconds(Int64(max(0, req.timeoutInterval)))
        }
    }
}

public enum RequestError: Error {
    case connectionError(Error)
    case internalError(Error)
    case invalidResponse
    case handlerRemovedBeforeResponse
    case readBodyBadInternalState
    case timeout
}

open class ConnectClient {

    public let eventLoopGroup: EventLoopGroup


    public init(eventLoopGroup: EventLoopGroup) {
        self.eventLoopGroup = eventLoopGroup
    }

    deinit {
        self.eventLoopGroup.shutdownGracefully({ _ in })
    }


    open func configurePipeline() -> PipelineSetup {
        ConnectClient.standardPipeline()
    }

    open func connect() -> EventLoopFuture<Channel> {
        preconditionFailure("must override method")
    }


    @discardableResult
    public func request(_ request: ClientRequest, completion: @escaping RequestCompletionHandler) -> ClientTask {
        return ClientTask(
            client: self,
            configurePipeline: self.configurePipeline(),
            request: request,
            completion: completion
        )
    }

    public static func standardPipeline() -> PipelineSetup {
        return { pipeline in
            return pipeline.eventLoop.makeSucceededVoidFuture()
        }
    }

}
