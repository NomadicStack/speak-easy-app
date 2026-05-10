import SwiftUI
import UniformTypeIdentifiers

struct ModelSelectionView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            if let error = modelManager.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                        Button("Dismiss") {
                            modelManager.errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Available AI Models")) {
                ForEach(modelManager.availableModels) { model in
                    ModelRow(model: model, modelManager: modelManager)
                        .swipeActions(edge: .trailing) {
                            if model.localURL != nil {
                                Button(role: .destructive) {
                                    modelManager.deleteModel(model)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            
            Section {
                Text("These models run entirely on your device. No data ever leaves your iPad/iPhone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button(role: .destructive, action: {
                    modelManager.clearAllModels()
                }) {
                    Label("Clear All Models & Cache", systemImage: "trash.fill")
                }
            }
        }
        .navigationTitle("Select AI Brain")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .disabled(modelManager.selectedModelId == nil)
            }
        }
    }
}

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var modelManager: ModelManager
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "cpu")
                    .foregroundColor(.purple)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(model.sizeDisplay)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Action Buttons
            if model.localURL != nil {
                HStack(spacing: 10) {
                    if modelManager.selectedModelId == model.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Button("Select") {
                            modelManager.selectModel(model)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    
                    Button(action: {
                        modelManager.deleteModel(model)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            } else if let progress = modelManager.downloadingModels[model.id] {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: {
                    modelManager.downloadModel(model)
                }) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
