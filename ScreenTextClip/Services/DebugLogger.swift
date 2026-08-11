import Foundation

enum DebugLogger {
    static func log(_ message: String, category: String) {
        #if DEBUG
        let line = "\(Date()) \(category): \(message)\n"
        print("[ScreenTextClip][\(category)] \(message)")

        guard let data = line.data(using: .utf8) else { return }

        let url = URL(fileURLWithPath: "/tmp/ScreenTextClip-debug.log")
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
        #endif
    }
}
