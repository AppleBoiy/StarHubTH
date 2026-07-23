import Foundation

enum NexusDownloaderError: Error, LocalizedError {
    case noValidFile
    case noDownloadLink
    case downloadFailed(String)
    case moveFailed(String)
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noValidFile: return "Could not find a valid file to download."
        case .noDownloadLink: return "Could not obtain download link."
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .moveFailed(let msg): return "File move error: \(msg)"
        case .fetchFailed(let msg): return "Failed to fetch mod files: \(msg)"
        }
    }
}

struct NexusDownloader {
    static func downloadUpdate(nexusId: Int, apiKey: String, completion: @escaping (Result<URL, NexusDownloaderError>) -> Void) {
        guard !apiKey.isEmpty else { return }
        
        // Step 1: get files list to find latest file ID
        NexusAPIService.shared.getModFiles(modId: nexusId, apiKey: apiKey) { result in
            switch result {
            case .success(let fileList):
                let targetFile = fileList.files.first { $0.categoryId == 1 } ?? fileList.files.first
                guard let fileId = targetFile?.fileId else {
                    completion(.failure(.noValidFile))
                    return
                }
                
                // Step 2: get download link
                NexusAPIService.shared.getDownloadLink(modId: nexusId, fileId: fileId, apiKey: apiKey) { linkResult in
                    switch linkResult {
                    case .success(let links):
                        guard let downloadLink = links.first?.URI, let url = URL(string: downloadLink) else {
                            completion(.failure(.noDownloadLink))
                            return
                        }
                        
                        // Step 3: download the file
                        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
                        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
                            if let error = error {
                                completion(.failure(.downloadFailed(error.localizedDescription)))
                                return
                            }
                            guard let localURL = localURL else { return }
                            
                            do {
                                try FileManager.default.moveItem(at: localURL, to: tempZipURL)
                                completion(.success(tempZipURL))
                            } catch {
                                completion(.failure(.moveFailed(error.localizedDescription)))
                            }
                        }
                        task.resume()
                        
                    case .failure(let error):
                        completion(.failure(.downloadFailed(error.localizedDescription)))
                    }
                }
            case .failure(let error):
                completion(.failure(.fetchFailed(error.localizedDescription)))
            }
        }
    }
}
