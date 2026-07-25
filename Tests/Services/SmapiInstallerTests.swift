import Foundation

class SmapiInstallerTests {
    static func run() {
        print("Running SmapiInstallerTests...")
        testLastMeaningfulLine()
    }

    static func testLastMeaningfulLine() {
        // Normal error message
        let errorOutput = """
        Extracting install files...
        Unhandled exception: System.Exception: failed to find the payload
          at SMAPI.Installer.Program.Main()
        """
        let msg = SmapiInstaller.lastMeaningfulLine(of: errorOutput)
        SimpleTestFramework.assertTrue(msg.contains("failed to find the payload"), "Should extract the exception line")

        // Single line output
        let singleLine = "unknown error occurred"
        let msg2 = SmapiInstaller.lastMeaningfulLine(of: singleLine)
        SimpleTestFramework.assertEqual(msg2, "unknown error occurred", "Should return the only line")
    }
}
