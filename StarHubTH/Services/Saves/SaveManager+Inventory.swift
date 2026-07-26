import Foundation

/// Inventory editing (§ file-size convention split, see SaveManager.swift's header
/// comment).
extension SaveManager {
    func fetchInventory(for info: SaveGameInfo) throws(SaveStorageError) -> [InventoryItem] {
        // No `.documentTidyXML` — that's libxml's HTML-tidy-style repair mode for
        // malformed input, and it can reformat/normalize content it considers invalid.
        // Stardew's save XML is always well-formed (produced by .NET's XmlSerializer),
        // so plain parsing avoids passing SMAPI mods' own <modData> content through a
        // "repair" pass it was never meant for.
        guard let data = try? Data(contentsOf: info.fileURL),
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement() else {
            throw .inventoryUnreadable
        }

        var inventory: [InventoryItem] = []

        // Find /SaveGame/player/items
        let player = root.elements(forName: "player").first
        let itemsElement = player?.elements(forName: "items").first

        guard let itemsNode = itemsElement else { throw .inventoryUnreadable }

        let itemNodes = itemsNode.elements(forName: "Item")

        for (index, itemNode) in itemNodes.enumerated() {
            let xsiType = itemNode.attribute(forName: "xsi:type")?.stringValue ?? ""

            if xsiType == "Object" {
                let name = itemNode.elements(forName: "name").first?.stringValue ?? "Unknown"
                let itemId = itemNode.elements(forName: "itemId").first?.stringValue ?? "Unknown"
                let stack = Int(itemNode.elements(forName: "stack").first?.stringValue ?? "1") ?? 1

                inventory.append(InventoryItem(slotIndex: index, itemId: itemId, name: name, stack: stack, isObject: true))
            } else if itemNode.attribute(forName: "xsi:nil")?.stringValue == "true" {
                // Empty slot
                inventory.append(InventoryItem.empty(slot: index))
            } else {
                // Other items like weapons, rings, etc.
                let name = itemNode.elements(forName: "name").first?.stringValue ?? xsiType
                let itemId = itemNode.elements(forName: "itemId").first?.stringValue ?? ""
                let displayName = name.isEmpty ? (xsiType.isEmpty ? "Unknown Item" : xsiType) : name
                inventory.append(InventoryItem(slotIndex: index, itemId: itemId, name: displayName, stack: 1, isObject: false))
            }
        }

        return inventory
    }

    func updateInventory(info: SaveGameInfo, items: [InventoryItem]) throws(SaveStorageError) {
        // Backup first
        try backupSave(info: info)

        // Same reasoning as `fetchInventory`: no `.documentTidyXML` on the way in.
        guard let data = try? Data(contentsOf: info.fileURL),
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement() else {
            throw .inventoryUnreadable
        }

        // Find /SaveGame/player/items
        guard let player = root.elements(forName: "player").first,
              let itemsElement = player.elements(forName: "items").first else {
            throw .inventoryUnreadable
        }

        let itemNodes = itemsElement.elements(forName: "Item")

        for updatedItem in items {
            guard updatedItem.slotIndex >= 0 && updatedItem.slotIndex < itemNodes.count else { continue }
            let nodeToUpdate = itemNodes[updatedItem.slotIndex]

            // Only update if it's an Object
            if updatedItem.isObject {
                // Stack
                if let stackNode = nodeToUpdate.elements(forName: "stack").first {
                    stackNode.stringValue = "\(updatedItem.stack)"
                } else {
                    let newStack = XMLElement(name: "stack", stringValue: "\(updatedItem.stack)")
                    nodeToUpdate.addChild(newStack)
                }

                // Item ID (if needed, but usually we just update stack for safety)
                if let idNode = nodeToUpdate.elements(forName: "itemId").first {
                    idNode.stringValue = updatedItem.itemId
                }
            } else if updatedItem.name.isEmpty {
                // Delete the item (make it an empty slot)
                nodeToUpdate.setChildren(nil)
                if let nilAttr = XMLNode.attribute(withName: "xsi:nil", stringValue: "true") as? XMLNode {
                    nodeToUpdate.attributes = [nilAttr]
                }
            }
        }

        do {
            // No `.nodePrettyPrint` — that reformats the entire document's whitespace,
            // not just the nodes this function actually changed.
            let updatedXMLData = document.xmlData
            try updatedXMLData.write(to: info.fileURL, options: .atomic)
        } catch {
            throw .fileWriteFailed(underlying: error)
        }
    }
}
