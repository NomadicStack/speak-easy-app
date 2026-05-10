import Foundation
import Combine

struct ModelInfo: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let url: URL
    let filename: String
    let sizeDisplay: String
    
    var localURL: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("Models", isDirectory: true).appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        // Basic validation: model files should be larger than 1MB
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64,
           fileSize > 1024 * 1024 {
            return url
        }
        return nil
    }
}

class ModelManager: NSObject, ObservableObject {
    @Published var availableModels: [ModelInfo] = [
        ModelInfo(
            id: "gemma-4-e2b-it",
            name: "Gemma 4 E2B IT",
            description: "New Gemma 4 model optimized for LiteRTLM-Swift.",
            url: URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm")!,
            filename: "gemma-4-E2B-it.litertlm",
            sizeDisplay: "2.6 GB"
        )
    ]
    
    @Published var downloadingModels: [String: Double] = [:] // modelId: progress
    @Published var selectedModelId: String?
    @Published var errorMessage: String?
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dysarthriaapp.modeldownload")
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    
    static let shared = ModelManager()
    
    private override init() {
        super.init()
        self.selectedModelId = UserDefaults.standard.string(forKey: "selected_model_id")
        
        ensureModelsDirectoryExists()
    }
    
    private func ensureModelsDirectoryExists() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docs.appendingPathComponent("Models", isDirectory: true)
        
        do {
            if !FileManager.default.fileExists(atPath: modelsDir.path) {
                try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            }
            excludeFromBackup(url: modelsDir)
        } catch {
            print("Failed to create models directory: \(error)")
            self.errorMessage = "Storage Error: Could not create models directory. \(error.localizedDescription)"
        }
    }
    
    private func excludeFromBackup(url: URL) {
        var resourceURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try resourceURL.setResourceValues(resourceValues)
        } catch {
            print("Failed to exclude from backup: \(error)")
        }
    }
    
    func downloadModel(_ model: ModelInfo) {
        guard downloadTasks[model.id] == nil else { return }
        
        let task = urlSession.downloadTask(with: model.url)
        task.taskDescription = model.id
        downloadTasks[model.id] = task
        downloadingModels[model.id] = 0.0
        task.resume()
    }
    
    func cancelDownload(_ model: ModelInfo) {
        downloadTasks[model.id]?.cancel()
        downloadTasks.removeValue(forKey: model.id)
        downloadingModels.removeValue(forKey: model.id)
    }
    
    func deleteModel(_ model: ModelInfo) {
        if let url = model.localURL {
            try? FileManager.default.removeItem(at: url)
            // If the model was unzipped into a folder, delete the folder too
            let folderURL = url.deletingPathExtension()
            try? FileManager.default.removeItem(at: folderURL)
            
            if selectedModelId == model.id {
                selectedModelId = nil
                UserDefaults.standard.removeObject(forKey: "selected_model_id")
            }
            objectWillChange.send()
        }
    }
    
    func clearAllModels() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docs.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.removeItem(at: modelsDir)
        ensureModelsDirectoryExists()
        
        selectedModelId = nil
        UserDefaults.standard.removeObject(forKey: "selected_model_id")
        objectWillChange.send()
    }
    
    func selectModel(_ model: ModelInfo) {
        guard model.localURL != nil else { return }
        selectedModelId = model.id
        UserDefaults.standard.set(model.id, forKey: "selected_model_id")
    }
    
    var selectedModel: ModelInfo? {
        availableModels.first { $0.id == selectedModelId }
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let modelId = task.taskDescription else { return }
        
        if let error = error {
            print("Download failed: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Download Error: \(error.localizedDescription)"
                self.downloadingModels.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelId = downloadTask.taskDescription,
              let model = availableModels.first(where: { $0.id == modelId }) else { return }
        
        // Check HTTP response
        if let response = downloadTask.response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to download model: HTTP \(response.statusCode)"
                self.downloadingModels.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
            }
            return
        }
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docs.appendingPathComponent("Models", isDirectory: true)
        let destinationURL = modelsDir.appendingPathComponent(model.filename)
        
        do {
            // Ensure directory exists again just in case
            if !FileManager.default.fileExists(atPath: modelsDir.path) {
                try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            }
            
            try? FileManager.default.removeItem(at: destinationURL)
            
            // Validate source file exists before moving
            guard FileManager.default.fileExists(atPath: location.path) else {
                throw NSError(domain: "ModelManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Download success but temporary file not found."])
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            // If it's a zip, unzip it
            if model.filename.hasSuffix(".zip") || model.url.pathExtension == "zip" {
                unzip(fileURL: destinationURL, to: modelsDir)
            }
            
            excludeFromBackup(url: destinationURL)
            
            DispatchQueue.main.async {
                self.errorMessage = nil
                self.downloadingModels.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
                if self.selectedModelId == nil {
                    self.selectModel(model)
                }
                self.objectWillChange.send()
            }
        } catch {
            print("Failed to move model: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Installation Error: \(error.localizedDescription)"
                self.downloadingModels.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
            }
        }
    }
    
    private func unzip(fileURL: URL, to destinationURL: URL) {
        // Process is not available on iOS. 
        // For production, use a library like ZIPFoundation.
        // For now, we print a warning.
        print("Warning: Unzipping is not implemented for iOS in this demo.")
        print("Please ensure the model files are placed directly in the Models folder.")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let modelId = downloadTask.taskDescription else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadingModels[modelId] = progress
        }
    }
}
