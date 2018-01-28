//
//  ChatRoom.swift
//  DogeChat
//
//  Created by Alican Özer on 27.01.2018.
//  Copyright © 2018 Alican Özer. All rights reserved.
//

import UIKit

protocol ChatRoomDelegate: class {
    func receivedMessage(message: Message)
}

class ChatRoom: NSObject {
    
    var inputStream: InputStream!
    var outputStream: OutputStream!
    
    var username = ""
    var roomname = ""
    let maxReadLength = 4096
    
    weak var delegate: ChatRoomDelegate?
    
    func setupNetworkCommunication() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, "localhost" as CFString, 80, &readStream, &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        inputStream.delegate = self
        
        inputStream.schedule(in: .current, forMode: .commonModes)
        outputStream.schedule(in: .current, forMode: .commonModes)
        
        inputStream.open()
        outputStream.open()
        print("connected")
    }
    
    func joinChat(roomname: String, username: String) {
        
        let data = "iam:\(username) from:\(roomname)".data(using: .utf8)!
        
        self.username = username
        self.roomname = roomname
        
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count)}
    }

    //neden private yapınca olmadı
    func readAvaliableBytes(stream: InputStream) {
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        var numberOfBytesRead  = 0
        while stream.hasBytesAvailable {
            
            numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if(numberOfBytesRead < 0){
                if let _ = stream.streamError {
                    break;
                }
            }
        }
        
        if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
            //Notify interested parties
            delegate?.receivedMessage(message: message)            
        }
    }
    
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Message? {
        
        guard let stringArray = String(bytesNoCopy: buffer, length: length, encoding: .utf8, freeWhenDone: true)?.components(separatedBy: ":")[2] else{
            return nil
        }
        
        let roomname = stringArray[0]
        let username = stringArray[1]
        let message = stringArray[2]/*.popLast(),
        let username = stringArray.last else{
            return nil
        }*/
        if(roomname.isEmpty||username.isEmpty||message.isEmpty){
            return nil
        }
        
        let messageSender:MessageSender = (username == self.username && roomname == self.roomname) ? .ourself : .someoneElse
        
        return Message(message: message, messageSender: messageSender, username: username, roomname: roomname)
    }
    
    func sendMessage(message: String) {
        let data = "msg:\(message)".data(using: .utf8)!
        
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
    
    func stopChatSession() {
        inputStream.close()
        outputStream.close()
    }
}

extension ChatRoom: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("new message received")
            readAvaliableBytes(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            print("new message received")
            stopChatSession()
        case Stream.Event.errorOccurred:
            print("error occurred")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event...")
            break
        }
    }
}




