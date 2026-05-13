import SwiftUI
import UniformTypeIdentifiers

struct ModelSelectionView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @Environment(\.dismiss) var dismiss
    @AppStorage("use_ai_simulation") var useSimulation: Bool = false
    @AppStorage("caregiver_phone_number") var caregiverNumber: String = ""
    @AppStorage("user_name") var userName: String = "User"
    
    @ObservedObject var contactManager = ContactManager.shared
    @State private var newContactName: String = ""
    @State private var newContactNumber: String = ""
    
    var body: some View {
        List {
            // 1. AI Model Management (Top Priority)
            Section(header: Text("AI Brain (Model Management)")) {
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
            
            // 2. Caregiver & Contacts (Collapsible)
            Section(header: Text("Contacts")) {
                DisclosureGroup("Manage Contacts") {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Primary Caregiver (Fallback)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            TextField("Phone Number", text: $caregiverNumber)
                                .keyboardType(.phonePad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Divider()
                        
                        Text("Other Contacts (Mention in shorthand)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(contactManager.contacts) { contact in
                            HStack {
                                Text(contact.name).font(.headline)
                                Spacer()
                                Text(contact.phoneNumber).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            contactManager.deleteContact(at: indexSet)
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                TextField("Name", text: $newContactName)
                                TextField("Number", text: $newContactNumber)
                                    .keyboardType(.phonePad)
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: {
                                guard !newContactName.isEmpty && !newContactNumber.isEmpty else { return }
                                contactManager.addContact(name: newContactName, number: newContactNumber)
                                newContactName = ""
                                newContactNumber = ""
                            }) {
                                Label("Add", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // 3. Testing & Debug (Collapsible)
            Section(header: Text("Advanced")) {
                DisclosureGroup("Developer Settings") {
                    VStack(alignment: .leading, spacing: 20) {
                        // User Profile
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User Profile")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            TextField("User Name", text: $userName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Divider()
                        
                        // Simulation Toggle
                        Toggle(isOn: $useSimulation) {
                            VStack(alignment: .leading) {
                                Text("Simulate AI Model")
                                    .font(.headline)
                                Text("Bypasses LLM loading for testing.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            
            Section {
                Button(role: .destructive, action: {
                    modelManager.clearAllModels()
                }) {
                    Label("Clear Cache", systemImage: "trash.fill")
                        .foregroundColor(.red)
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
