import Foundation

struct SaveFileParserTests {
    static func run() {
        print("Running SaveFileParserTests...")
        
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <SaveGame xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <player>
            <name>FarmBoi</name>
            <spouse>Abigail</spouse>
            <money>5000</money>
            <totalMoneyEarned>12000</totalMoneyEarned>
            <maxHealth>150</maxHealth>
            <maxStamina>300</maxStamina>
          </player>
          <farmName>Sunshine</farmName>
          <favoriteThing>Apples</favoriteThing>
          <yearForSaveGame>2</yearForSaveGame>
          <seasonForSaveGame>1</seasonForSaveGame>
          <dayOfMonthForSaveGame>15</dayOfMonthForSaveGame>
          <whichFarm>2</whichFarm>
          <goldenWalnuts>10</goldenWalnuts>
          <qiGems>5</qiGems>
          <clubCoins>100</clubCoins>
        </SaveGame>
        """
        
        let url = URL(fileURLWithPath: "/tmp/save1")
        if let save = SaveFileParser.parse(xml: xml, url: url, folderName: "save1", lastModified: Date()) {
            SimpleTestFramework.assertEqual(save.playerName, "FarmBoi", "Player name should match")
            SimpleTestFramework.assertEqual(save.farmName, "Sunshine", "Farm name should match")
            SimpleTestFramework.assertEqual(save.spouse, "Abigail", "Spouse should match")
            SimpleTestFramework.assertEqual(save.money, 5000, "Money should match")
            SimpleTestFramework.assertEqual(save.totalMoneyEarned, 12000, "Total money earned should match")
            SimpleTestFramework.assertEqual(save.year, 2, "Year should match")
            SimpleTestFramework.assertEqual(save.season, 1, "Season should match")
            SimpleTestFramework.assertEqual(save.day, 15, "Day should match")
            SimpleTestFramework.assertEqual(save.whichFarm, 2, "Farm type should match")
            SimpleTestFramework.assertEqual(save.goldenWalnuts, 10, "Walnuts should match")
            SimpleTestFramework.assertEqual(save.qiGems, 5, "Qi gems should match")
        } else {
            SimpleTestFramework.assertTrue(false, "Save file failed to parse")
        }
    }
}
