import Foundation
import ZIPFoundation // Added on macOS. Expected to not resolve during Windows compile phase.
import Combine

/// Enum representing the state of custom model access
public enum TokenStatus: Equatable {
    case none
    case validating
    case downloading(progress: Double)
    case unzipping
    case active(modelName: String)
    case error(String)
}

/// Service that coordinates validating access tokens, downloading models, unzipping them,
/// and verifying their local presence.
public final class TokenService: NSObject, ObservableObject {
    public static let shared = TokenService()
    
    @Published public var status: TokenStatus = .none
    
    // MARK: - Configuration
    // Developer: Replace this with your actual deployed Firebase Cloud Function URL.
    // e.g. "https://downloadmodel-xxxxxx-uc.a.run.app"
    private let backendUrlString = "https://downloadmodel-kel6gzqjiq-uc.a.run.app"
    
    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    
    private override init() {
        super.init()
        self.downloadSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        checkLocalModelStatus()
    }
    
    /// Inspects local filesystem and Keychain to establish the current status.
    /// This runs offline-first: if the local files are found, the app is active.
    public func checkLocalModelStatus() {
        if let modelDir = findModelDirectory() {
            // Find a friendly name from metadata or folder
            let modelName = modelDir.lastPathComponent
            DispatchQueue.main.async {
                self.status = .active(modelName: modelName)
            }
        } else {
            // Check if there is a saved token in Keychain
            if KeychainHelper.shared.loadToken() != nil {
                // Token exists but no model files exist (e.g. wiped cache or interrupted download)
                DispatchQueue.main.async {
                    self.status = .error("Token is saved, but model files are missing. Please re-enter or reactivate.")
                }
            } else {
                DispatchQueue.main.async {
                    self.status = .none
                }
            }
        }
    }
    
    /// Queries the backend API with the token to obtain the signed URL, then downloads and unzips.
    public func activateToken(_ token: String) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            self.status = .error("Token cannot be empty.")
            return
        }
        
        self.status = .validating
        
        guard let url = URL(string: backendUrlString) else {
            self.status = .error("Invalid backend URL configured.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        // Set short timeout for the token verification request
        request.timeoutInterval = 15.0
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.updateStatus(.error("Connection failed: \(error.localizedDescription)"))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.updateStatus(.error("Invalid response from server."))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self.updateStatus(.error("Invalid or expired access token."))
                } else if httpResponse.statusCode == 404 {
                    self.updateStatus(.error("Model file not found on server. Contact support."))
                } else {
                    self.updateStatus(.error("Server error (HTTP Status \(httpResponse.statusCode))."))
                }
                return
            }
            
            guard let data = data else {
                self.updateStatus(.error("Server returned an empty response."))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let downloadUrlString = json["downloadUrl"] as? String,
                   let downloadUrl = URL(string: downloadUrlString) {
                    
                    // Store valid token securely in the Keychain
                    KeychainHelper.shared.saveToken(trimmedToken)
                    
                    // Start downlading model archive
                    self.startModelDownload(from: downloadUrl)
                } else {
                    self.updateStatus(.error("Could not parse download URL from response."))
                }
            } catch {
                self.updateStatus(.error("Data parsing failed: \(error.localizedDescription)"))
            }
        }
        task.resume()
    }
    
    /// Starts downloading the ZIP file using the background-configured URLSession.
    private func startModelDownload(from url: URL) {
        updateStatus(.downloading(progress: 0.0))
        self.downloadTask = downloadSession?.downloadTask(with: url)
        self.downloadTask?.resume()
    }
    
    /// Cancels any active download and resets status.
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        checkLocalModelStatus()
    }
    
    /// Fully removes credentials and downloads, returning the app to a clean locked state.
    public func resetToken() {
        KeychainHelper.shared.deleteToken()
        deleteLocalModels()
        checkLocalModelStatus()
    }
    
    private func deleteLocalModels() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let whisperModelsURL = documentsURL.appendingPathComponent("WhisperModels")
        
        try? fileManager.removeItem(at: whisperModelsURL)
    }
    
    private func updateStatus(_ newStatus: TokenStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
        }
    }
    
    // MARK: - Model Folder Lookup
    
    /// Scans the Documents/WhisperModels/ folder for the WhisperKit configuration file `config.json`.
    /// - Returns: URL of the directory containing the model files, or nil if not found.
    public func findModelDirectory() -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let whisperModelsURL = documentsURL.appendingPathComponent("WhisperModels")
        
        guard fileManager.fileExists(atPath: whisperModelsURL.path) else { return nil }
        
        // Scenario A: Flattended structure directly in WhisperModels/
        if fileManager.fileExists(atPath: whisperModelsURL.appendingPathComponent("config.json").path) {
            return whisperModelsURL
        }
        
        // Scenario B: Wrapped in a subfolder inside WhisperModels/ (e.g. CustomDysarthriaModel/)
        if let contents = try? fileManager.contentsOfDirectory(at: whisperModelsURL, includingPropertiesForKeys: nil) {
            for item in contents {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    if fileManager.fileExists(atPath: item.appendingPathComponent("config.json").path) {
                        return item
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - URLSessionDownloadDelegate conformance
extension TokenService: URLSessionDownloadDelegate {
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        updateStatus(.downloading(progress: progress))
    }
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        updateStatus(.unzipping)
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let whisperModelsURL = documentsURL.appendingPathComponent("WhisperModels")
        
        do {
            // Wipe out any existing WhisperModels folder to avoid mixing components
            if fileManager.fileExists(atPath: whisperModelsURL.path) {
                try fileManager.removeItem(at: whisperModelsURL)
            }
            
            try fileManager.createDirectory(at: whisperModelsURL, withIntermediateDirectories: true)
            
            // Extract ZIP file using ZIPFoundation extension on FileManager
            try fileManager.unzipItem(at: location, to: whisperModelsURL)
            
            // Scan for the newly unzipped model configuration
            if let modelDir = findModelDirectory() {
                let modelName = modelDir.lastPathComponent
                updateStatus(.active(modelName: modelName))
            } else {
                updateStatus(.error("Archive extracted but could not locate config.json in files."))
            }
        } catch {
            updateStatus(.error("Extraction failed: \(error.localizedDescription)"))
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            let nsError = error as NSError
            // Ignore manual cancellation errors
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            updateStatus(.error("Download failed: \(error.localizedDescription)"))
        }
    }
}
