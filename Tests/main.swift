import Foundation

print("Starting StarHubTH Test Suite...\n")

ModTagInferenceTests.run()
ModManifestParserTests.run()
SaveFileParserTests.run()
SmapiLogParserTests.run()
SmapiInstallerTests.run()
NXMParserTests.run()
NexusCollectionTests.run()

SimpleTestFramework.report()
