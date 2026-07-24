import Foundation
let bundlePath = "StarHubTH.app/Contents/Resources/th.lproj"
if let bundle = Bundle(path: bundlePath) {
    let tagOther = bundle.localizedString(forKey: "tag_other", value: "__MISSING__", table: nil)
    print("tag_other: \(tagOther)")
    let dateAll = bundle.localizedString(forKey: "mods_filter_date_all", value: "__MISSING__", table: nil)
    print("mods_filter_date_all: \(dateAll)")
} else {
    print("Bundle not found")
}
