import Foundation
let bundlePath = "StarHubTH.app/Contents/Resources/th.lproj"
if let bundle = Bundle(path: bundlePath) {
    let filterAll = bundle.localizedString(forKey: "mods_filter_all", value: "__MISSING__", table: nil)
    print("mods_filter_all: \(filterAll)")
}
