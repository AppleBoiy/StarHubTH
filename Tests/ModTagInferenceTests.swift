import Foundation

struct ModTagInferenceTests {
    static func run() {
        print("Running ModTagInferenceTests...")
        
        let t1 = Mod.inferTag(name: "UI Info Suite", uniqueId: "cd.uiinfosuite", description: "Adds UI elements")
        SimpleTestFramework.assertEqual(t1, "UI", "Should infer UI tag")
        
        let t2 = Mod.inferTag(name: "Content Patcher", uniqueId: "Pathoschild.ContentPatcher", description: "Core framework")
        SimpleTestFramework.assertEqual(t2, "Framework", "Should infer Framework tag")
        
        let t3 = Mod.inferTag(name: "Farm Type Manager", uniqueId: "esc.ftm", description: "API and framework for spawns")
        SimpleTestFramework.assertEqual(t3, "Framework", "Should infer Framework tag")
        
        let t4 = Mod.inferTag(name: "Thai Translation", uniqueId: "some.thai", description: "Language pack")
        SimpleTestFramework.assertEqual(t4, "Translation", "Should infer Translation tag")
        
        let t5 = Mod.inferTag(name: "Cute Animals", uniqueId: "cute.animals", description: "Texture replacement")
        SimpleTestFramework.assertEqual(t5, "Cosmetic", "Should infer Cosmetic tag")
    }
}
