import Foundation

struct InventoryItem: Identifiable, Equatable {
    let id = UUID()
    var slotIndex: Int
    var itemId: String
    var name: String
    var stack: Int
    var isObject: Bool
    
    // For empty slots
    static func empty(slot: Int) -> InventoryItem {
        InventoryItem(slotIndex: slot, itemId: "", name: "", stack: 0, isObject: false)
    }
}
