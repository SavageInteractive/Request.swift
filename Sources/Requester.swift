//
//  Requester.swift
//  RequestSwift
//
//  Created by Orkhan Alikhanov on 7/12/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation
import Dispatch
import SocketSwift

public typealias ResponseHandler = (Response?, Error?) -> Void
open class Requester {
    open var timeout: Int
    open var queue: DispatchQueue
    open var request: Request
    open var response: Response?
    open var error: Error?
    open var handler: ResponseHandler? = nil
    
    
    public init(request: Request, queue: DispatchQueue, timeout: Int) {
        self.request = request
        self.queue = queue
        self.timeout = timeout
    }
    
    open func startAsync() {
        queue.async {
            self.start()
        }
    }
    
    open func start() {
        do {
            let socket = try Socket(.inet)
            let (hostname, portString) = request.hostnameAndPort
            var port: SocketSwift.Port = 80
            if let p = portString {
                port = Port(p)!
            }
            
            let address = try hostToIp(hostname)
            
            try socket.connect(port: port, address: address)
            
            let bytes = RequestWriter.write(request: request)
            try socket.write(bytes)
            
            try wait(socket)
            
            self.response = try ResponseParser.parse(socket: socket)
            socket.close()
        } catch {
            self.error = error
        }
        handler?(response, error)
    }
    
    open func response(_ handler: @escaping ResponseHandler) {
        self.handler = handler
        if response != nil || error != nil {
            handler(response, error)
        }
    }
    
    
    open func hostToIp( _ hostname: String) throws -> String {
        if let a = gethostbyname(hostname) {
            let b = withUnsafePointer(to: &(a.pointee.h_addr_list.pointee)) {
                UnsafePointer<UnsafePointer<in_addr>>(OpaquePointer($0)).pointee.pointee
            }
            let c = inet_ntoa(b)!
            
            return String(cString: c)
        }
        
        throw Request.Error.couldntResolveHost
    }
    
    open func wait(_ socket: Socket) throws {
        var fd = pollfd()
        memset(&fd, 0, MemoryLayout<pollfd>.stride)
        fd.fd = socket.fileDescriptor
        fd.events = Int16(POLLIN)
        if (try ing { poll(&fd, 1, Int32(timeout)) }) == 0 {
            throw Request.Error.timeout
        }
    }
}
