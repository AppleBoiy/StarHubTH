import Foundation

class NexusCollectionTests {
    static func run() async {
        print("Running NexusCollectionTests...")
        await testFetchCollectionWithRealData()
    }

    static func testFetchCollectionWithRealData() async {
        let defaults = UserDefaults(suiteName: "com.appleboiy.StarHubTH")
        let apiKey = defaults?.string(forKey: "nexusApiKey") ?? ""

        if apiKey.isEmpty {
            print("⚠️ SKIPPING testFetchCollectionWithRealData: No Nexus API Key found in com.appleboiy.StarHubTH defaults.")
            SimpleTestFramework.assertTrue(true, "Skipped due to missing API key")
            return
        }

        let slug = "tckf0m"

        do {
            let collection = try await LiveNexusAPIClient.shared.getCollectionGraph(slug: slug, apiKey: apiKey)
            SimpleTestFramework.assertEqual(collection.slug, slug, "Slug should match")
            SimpleTestFramework.assertEqual(collection.game?.domainName, "stardewvalley", "Game domain should be stardewvalley")
            SimpleTestFramework.assertTrue(collection.latestPublishedRevision != nil, "Should have a latest revision")

            if let modFiles = collection.latestPublishedRevision?.modFiles {
                SimpleTestFramework.assertTrue(modFiles.count > 0, "Collection should contain mods")
                if let firstMod = modFiles.first?.file?.mod {
                    SimpleTestFramework.assertTrue(firstMod.modId > 0, "Mods should have a valid modId")
                }
            } else {
                SimpleTestFramework.assertTrue(false, "Collection modFiles were nil")
            }
        } catch {
            print("DECODING ERROR DETAILED: \(error)")
            SimpleTestFramework.assertTrue(false, "Failed to fetch actual collection data: \(error.localizedDescription)")
        }
    }
}
