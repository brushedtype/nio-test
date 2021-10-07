//
//  File.swift
//
//
//  Created by Edward Wellbrook on 24/07/2021.
//

import Foundation
import XCTest
import Network
import NIO
import NIOTransportServices
@testable import nio_test

final class NIOTSTestClient: ConnectClient {

    let endpoint: NWEndpoint


    public init(endpoint: NWEndpoint) {
        self.endpoint = endpoint

        super.init(eventLoopGroup: NIOTSEventLoopGroup())
    }


    public override func configurePipeline() -> PipelineSetup {
        ConnectClient.standardPipeline()
    }

    public override func connect() -> EventLoopFuture<Channel> {
        NIOTSConnectionBootstrap(group: self.eventLoopGroup)
            .channelOption(NIOTSChannelOptions.allowLocalEndpointReuse, value: true)
            .channelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .channelOption(ChannelOptions.autoRead, value: false)
            .connectTimeout(.seconds(1))
            .connect(endpoint: self.endpoint)
    }

}

final class PlainTestClient: ConnectClient {

    let endpoint: String


    public init(endpoint: String) {
        self.endpoint = endpoint

        super.init(eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))
    }

    public override func connect() -> EventLoopFuture<Channel> {
        ClientBootstrap(group: self.eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .channelOption(ChannelOptions.autoRead, value: false)
            .connectTimeout(.seconds(1))
            .connect(unixDomainSocketPath: self.endpoint)
    }

}

class ServerTests: XCTestCase {

    func testLargeResponseTS() throws {
        let payloadResponse = try Data(contentsOf: Bundle.module.url(forResource: "response-payload", withExtension: "json")!)

        let (endpoint, closeEndpoint) = try self.createEndpoint()
        defer {
            closeEndpoint()
        }

        let server = HTTPServer()
        try server.listen(endpoint: .unix(path: endpoint), handler: { request, response in
            response(.success(.init(status: .ok, headers: [], body: .init(data: payloadResponse))))
        })


        let client = NIOTSTestClient(endpoint: .unix(path: endpoint))

        var request = URLRequest(url: URL(string: "/payload")!)
        request.httpMethod = "GET"

        let expectation = XCTestExpectation(description: "Make request")
        client.request(.standard(request)) { head, data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, payloadResponse)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 30)
    }

    func testLargeResponsePlain() throws {
        let payloadResponse = try Data(contentsOf: Bundle.module.url(forResource: "response-payload", withExtension: "json")!)

        let (endpoint, closeEndpoint) = try self.createEndpoint()
        defer {
            closeEndpoint()
        }

        let server = HTTPServer()
        try server.listen(endpoint: .unix(path: endpoint), handler: { request, response in
            response(.success(.init(status: .ok, headers: [], body: .init(data: payloadResponse))))
        })


        let client = PlainTestClient(endpoint: endpoint)

        var request = URLRequest(url: URL(string: "/payload")!)
        request.httpMethod = "GET"

        let expectation = XCTestExpectation(description: "Make request")
        client.request(.standard(request)) { head, data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, payloadResponse)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 30)
    }

}

extension ServerTests {

//    func createEndpoint() throws -> (NWEndpoint, () -> Void) {
//        let unixPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sock").path
//        try unlinkEndpointIfNeeded(path: unixPath)
//
//        return (.unix(path: unixPath), { try? unlinkEndpointIfNeeded(path: unixPath) })
//    }

    func createEndpoint() throws -> (String, () -> Void) {
        let unixPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sock").path
        try unlinkEndpointIfNeeded(path: unixPath)

        return (unixPath, { try? unlinkEndpointIfNeeded(path: unixPath) })
    }

}

func unlinkEndpointIfNeeded(path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
        return
    }

    guard unlink(path) == 0 else {
        throw NSError(domain: "co.brushedtype.doppler-macos.connect", code: -1144, userInfo: nil)
    }
}
