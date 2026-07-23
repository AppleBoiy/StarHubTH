#!/usr/bin/env python3
import os
import subprocess

def run_tests():
    print("[INFO] Starting tests...")
    
    # 1. Find all Swift source files
    swift_files = []
    for root, dirs, files in os.walk("StarHubTH"):
        for file in files:
            if file.endswith(".swift") and file != "StarHubTHApp.swift":
                swift_files.append(os.path.join(root, file))
                
    # Find all test files
    for root, dirs, files in os.walk("Tests"):
        for file in files:
            if file.endswith(".swift"):
                swift_files.append(os.path.join(root, file))
                
    if not swift_files:
        print("[ERROR] No Swift files found.")
        return
        
    os.makedirs(".build", exist_ok=True)
    test_executable = os.path.join(".build", "Tests")
    
    # 2. Compile tests
    print(f"[INFO] Compiling {len(swift_files)} files for testing...")
    swiftc_cmd = ["swiftc"] + swift_files + [
        "-o", test_executable,
        "-target", "arm64-apple-macos13.0",
    ]
    
    result = subprocess.run(swiftc_cmd)
    if result.returncode != 0:
        print("[ERROR] Test compilation failed.")
        return
        
    # 3. Run tests
    print("[INFO] Running tests...\n")
    subprocess.run([test_executable])
    
if __name__ == "__main__":
    run_tests()
