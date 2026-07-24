import Foundation

class SmapiInstallerTests {
    static func run() {
        print("Running SmapiInstallerTests...")
        testLastMeaningfulLine()
        testResolveLatestSmapiInstallerURL()
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
    
    static func testResolveLatestSmapiInstallerURL() {
        let expectation = DispatchSemaphore(value: 0)
        
        SmapiInstaller.resolveLatestSmapiInstallerURL { result in
            switch result {
            case .success(let url, let version):
                SimpleTestFramework.assertTrue(url.absoluteString.contains("SMAPI-"), "URL should contain SMAPI-")
                SimpleTestFramework.assertTrue(url.absoluteString.contains("-installer.zip"), "URL should contain -installer.zip")
                SimpleTestFramework.assertFalse(url.absoluteString.contains("double-zipped"), "URL should NOT contain double-zipped")
                SimpleTestFramework.assertTrue(version.count > 0, "Version should not be empty")
            case .failure(let msg, let detail):
                SimpleTestFramework.assertTrue(false, "API resolution failed: \(msg) - \(detail ?? "")")
            }
            expectation.signal()
        }
        
        let waitResult = expectation.wait(timeout: .now() + 10.0)
        SimpleTestFramework.assertTrue(waitResult == .success, "API resolution should complete within 10 seconds")
    }
}
