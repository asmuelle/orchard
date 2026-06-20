#if canImport(Network)
    import Foundation

    // Length-prefixed message framing: a 4-byte big-endian length followed by a JSON body. Both sides
    // agree on the frame so a reader knows exactly how many bytes to pull off the stream. JSON keeps
    // the skeleton simple; a production build would swap in a compact binary tensor encoding.

    enum WireFrame {
        static func encode(_ message: some Encodable) throws -> Data {
            let body = try JSONEncoder().encode(message)
            var length = UInt32(body.count).bigEndian
            var framed = Data(bytes: &length, count: 4)
            framed.append(body)
            return framed
        }

        static func read<Message: Decodable>(from channel: TCPChannel) async throws -> Message {
            let header = try await [UInt8](channel.receive(exactly: 4))
            let length = Int(header[0]) << 24 | Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            let body = try await channel.receive(exactly: length)
            return try JSONDecoder().decode(Message.self, from: body)
        }
    }
#endif
