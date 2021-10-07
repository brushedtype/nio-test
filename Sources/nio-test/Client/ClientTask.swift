//
//  File.swift
//  
//
//  Created by Edward Wellbrook on 07/10/2021.
//

import Foundation
import NIO

public class ClientTask {

    private let client: ConnectClient

    private var isCancelled = false
    private weak var channel: Channel?


    init(
        client: ConnectClient,
        configurePipeline: @escaping PipelineSetup,
        request: ClientRequest,
        completion: @escaping RequestCompletionHandler
    ) {
        self.client = client

        self.connect(configurePipeline: configurePipeline, request: request, completion: completion)
    }


    private func connect(configurePipeline: @escaping PipelineSetup, request: ClientRequest, completion: @escaping RequestCompletionHandler) {
        do {
            let channel = try self.client.connect().wait()
            self.channel = channel

            try channel.pipeline.addHandler(IdleStateHandler(allTimeout: request.timeout), name: "IdleStateHandler").flatMap {
                configurePipeline(channel.pipeline).flatMap {
                    channel.pipeline.addHTTPClientHandlers().flatMap {
                        channel.pipeline.addHandler(HTTPClientHandler(request: request, completion: completion), name: "HTTPClientHandler")
                    }
                }
            }.flatMap {
                channel.closeFuture
            }.wait()
        } catch {
            completion(nil, nil, .connectionError(error))
        }
    }

}
