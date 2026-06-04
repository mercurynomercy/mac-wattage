import Foundation

/// Console logging utility. No external dependencies — prints to stdout/stderr.
enum Logger {
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("[MacWattage WARNING] \(fileName):\(line) \(function) - \(message)")
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("[MacWattage ERROR] \(fileName):\(line) \(function) - \(message)")
    }
}
