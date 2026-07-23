import Foundation

class SimpleTestFramework {
    static var passed = 0
    static var failed = 0
    
    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
        if actual == expected {
            passed += 1
            print("✅ PASS: \(message)")
        } else {
            failed += 1
            print("❌ FAIL: \(message) - Expected \(expected), got \(actual) at \(file):\(line)")
        }
    }
    
    static func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if condition {
            passed += 1
            print("✅ PASS: \(message)")
        } else {
            failed += 1
            print("❌ FAIL: \(message) - Expected true, got false at \(file):\(line)")
        }
    }
    
    static func assertFalse(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if !condition {
            passed += 1
            print("✅ PASS: \(message)")
        } else {
            failed += 1
            print("❌ FAIL: \(message) - Expected false, got true at \(file):\(line)")
        }
    }
    
    static func report() {
        print("\n=== Test Results ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        if failed > 0 {
            exit(1)
        }
    }
}
