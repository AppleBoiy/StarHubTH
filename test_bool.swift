import Foundation

let jsonStr = "{\"isTrue\": true, \"zero\": 0, \"one\": 1}"
let data = jsonStr.data(using: .utf8)!
let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

for (k, v) in json {
    if let num = v as? NSNumber {
        if CFGetTypeID(num) == CFBooleanGetTypeID() {
            print("\(k) is Bool: \(num.boolValue)")
        } else {
            print("\(k) is Number: \(num.doubleValue)")
        }
    }
}
