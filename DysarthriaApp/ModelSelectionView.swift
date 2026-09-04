import SwiftUI
import UniformTypeIdentifiers

struct ModelSelectionView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var tokenService = TokenService.shared
    @Environment(\.dismiss) var dismiss
    @AppStorage("use_ai_simulation") var useSimulation: Bool = false
    @AppStorage("caregiver_phone_number") var caregiverNumber: String = ""
    @AppStorage("user_name") var userName: String = "User"
    @AppStorage("feedback_recipient") var feedbackRecipient: String = "developer@example.com"
    @AppStorage("caregiver_cc_email") var caregiverCCEmail: String = ""
    
    @ObservedObject var contactManager = ContactManager.shared
    @State private var newContactName: String = ""
    @State private var newContactNumber: String = ""
    
    @ObservedObject var chipManager = QuickChipManager.shared
    @State private var newChipLabel: String = ""
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    var body: some View {
        List {
            // 1. AI Model Management (Top Priority)
            Section(header: Text("AI Brain (Model Management)").font(isPad ? .title3.bold() : .caption.bold())) {
                ForEach(modelManager.availableModels) { model in
                    ModelRow(model: model, modelManager: modelManager, isPad: isPad)
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
            Section(header: Text("Contacts").font(isPad ? .title3.bold() : .caption.bold())) {
                DisclosureGroup("Manage Contacts") {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Primary Caregiver (Fallback)")
                                .font(isPad ? .headline : .caption.bold())
                                .foregroundColor(.secondary)
                            TextField("Phone Number", text: $caregiverNumber)
                                .keyboardType(.phonePad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(isPad ? .title3 : .body)
                        }
                        
                        Divider()
                        
                        Text("Other Contacts (Mention in shorthand)")
                            .font(isPad ? .headline : .caption.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(contactManager.contacts) { contact in
                            HStack {
                                Text(contact.name).font(isPad ? .title3.bold() : .headline)
                                Spacer()
                                Text(contact.phoneNumber).font(isPad ? .headline : .subheadline).foregroundColor(.secondary)
                            }
                            .padding(.vertical, isPad ? 10 : 5)
                        }
                        .onDelete { indexSet in
                            contactManager.deleteContact(at: indexSet)
                        }
                        
                        VStack(spacing: 15) {
                            HStack(spacing: 15) {
                                TextField("Name", text: $newContactName)
                                TextField("Number", text: $newContactNumber)
                                    .keyboardType(.phonePad)
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(isPad ? .title3 : .body)
                            
                            Button(action: {
                                guard !newContactName.isEmpty && !newContactNumber.isEmpty else { return }
                                contactManager.addContact(name: newContactName, number: newContactNumber)
                                newContactName = ""
                                newContactNumber = ""
                            }) {
                                Label("Add Contact", systemImage: "plus.circle.fill")
                                    .font(isPad ? .title3.bold() : .headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(isPad ? 15 : 10)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .font(isPad ? .title3.bold() : .headline)
            }
            
            // 3. Quick Chips Management (Collapsible)
            Section(header: Text("Smart Speak Shortcuts").font(isPad ? .title3.bold() : .caption.bold())) {
                DisclosureGroup("Manage Quick Chips") {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Edit your shorthand shortcuts (e.g. '💧 thirsty')")
                            .font(isPad ? .headline : .caption.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(chipManager.chips) { chip in
                            HStack(spacing: 15) {
                                TextField("Shortcut Label", text: Binding(
                                    get: { chip.label },
                                    set: { newValue in
                                        if let index = chipManager.chips.firstIndex(where: { $0.id == chip.id }) {
                                            chipManager.updateChip(at: index, newLabel: newValue)
                                        }
                                    }
                                ))
                                .font(isPad ? .title3 : .body)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    if let index = chipManager.chips.firstIndex(where: { $0.id == chip.id }) {
                                        chipManager.deleteChip(at: IndexSet(integer: index))
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(isPad ? .title3 : .body)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, isPad ? 10 : 5)
                        }
                        .onDelete { indexSet in
                            chipManager.deleteChip(at: indexSet)
                        }
                        
                        VStack(spacing: 15) {
                            TextField("New Shortcut (e.g. '🍎 hungry')", text: $newChipLabel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(isPad ? .title3 : .body)
                            
                            Button(action: {
                                guard !newChipLabel.isEmpty else { return }
                                chipManager.addChip(label: newChipLabel)
                                newChipLabel = ""
                            }) {
                                Label("Add Shortcut", systemImage: "plus.circle.fill")
                                    .font(isPad ? .title3.bold() : .headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(isPad ? 15 : 10)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .font(isPad ? .title3.bold() : .headline)
                .accentColor(.purple)
            }
            
            // 4. Voice Training & Data Export
            Section(header: Text("Voice Training & Data Export").font(isPad ? .title3.bold() : .caption.bold()),
                    footer: Text("Audio recordings are stored strictly on-device. When exported from Voice Studio, data is packaged and sent directly to these email addresses.").font(isPad ? .body : .caption)) {
                DisclosureGroup("Email Configuration") {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Developer / Trainer Recipient Email")
                                .font(isPad ? .headline : .caption.bold())
                                .foregroundColor(.secondary)
                            TextField("developer@example.com", text: $feedbackRecipient)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(isPad ? .title3 : .body)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caregiver Email (CC on Export)")
                                .font(isPad ? .headline : .caption.bold())
                                .foregroundColor(.secondary)
                            TextField("caregiver@example.com (optional)", text: $caregiverCCEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(isPad ? .title3 : .body)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .font(isPad ? .title3.bold() : .headline)
                .accentColor(.blue)
            }
            
            // 5. Testing & Debug (Collapsible)
            Section(header: Text("Advanced").font(isPad ? .title3.bold() : .caption.bold())) {
                DisclosureGroup("Developer Settings") {
                    VStack(alignment: .leading, spacing: 25) {
                        // User Profile
                        VStack(alignment: .leading, spacing: 10) {
                            Text("User Profile")
                                .font(isPad ? .headline : .caption.bold())
                                .foregroundColor(.secondary)
                            
                            TextField("User Name", text: $userName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(isPad ? .title3 : .body)
                        }
                        
                        Divider()
                        
                        // Simulation Toggle
                        Toggle(isOn: $useSimulation) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Simulate AI Model")
                                    .font(isPad ? .title3.bold() : .headline)
                                Text("Bypasses LLM loading for testing.")
                                    .font(isPad ? .headline : .caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 15)
                }
                .font(isPad ? .title3.bold() : .headline)
            }
            
            // Speech Recognition Model Management
            Section(header: Text("Speech Recognition Model").font(isPad ? .title3.bold() : .caption.bold()),
                    footer: Text("SpeakEasy maintains only one speech model on device at a time to minimize storage usage.").font(isPad ? .body : .caption)) {
                if case .active(let modelName) = tokenService.status {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .foregroundColor(.purple)
                            .font(isPad ? .title3 : .body)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active: \(modelName)")
                                .font(isPad ? .title3.bold() : .headline)
                            Text("Personalized custom model is active (Base cache cleared)")
                                .font(isPad ? .headline : .caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, isPad ? 10 : 5)
                    
                    Button(role: .destructive, action: {
                        tokenService.resetToken()
                    }) {
                        Label("Revert to Base Model (Whisper Small)", systemImage: "arrow.counterclockwise")
                            .font(isPad ? .title3 : .headline)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(isPad ? .title3 : .body)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active: Whisper Small (Default)")
                                .font(isPad ? .title3.bold() : .headline)
                            Text("Standard open-source model")
                                .font(isPad ? .headline : .caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, isPad ? 10 : 5)
                    
                    NavigationLink {
                        TokenEntryView()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                                .font(isPad ? .title3 : .body)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import Custom Model")
                                    .font(isPad ? .title3.bold() : .headline)
                                Text("Use an access token to swap in a personalized model")
                                    .font(isPad ? .headline : .caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, isPad ? 10 : 5)
                    }
                }
            }

            Section {
                Button(role: .destructive, action: {
                    modelManager.clearAllModels()
                }) {
                    Label("Clear Cache", systemImage: "trash.fill")
                        .font(isPad ? .title3.bold() : .headline)
                        .foregroundColor(.red)
                }
                .padding(.vertical, isPad ? 10 : 0)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(isPad ? .title3.bold() : .headline.bold())
            }
        }
    }
}

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var modelManager: ModelManager
    var isPad: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: isPad ? 80 : 50, height: isPad ? 80 : 50)
                
                Image(systemName: "cpu")
                    .foregroundColor(.purple)
                    .font(isPad ? .largeTitle : .title3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(model.name)
                    .font(isPad ? .title2.bold() : .headline)
                Text(model.description)
                    .font(isPad ? .title3 : .caption)
                    .foregroundColor(.secondary)
                Text(model.sizeDisplay)
                    .font(.system(size: isPad ? 16 : 10, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Action Buttons
            if model.localURL != nil {
                HStack(spacing: 20) {
                    if modelManager.selectedModelId == model.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: isPad ? 40 : 24))
                    } else {
                        Button("Select") {
                            modelManager.selectModel(model)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .font(isPad ? .title3.bold() : .body)
                    }
                    
                    Button(action: {
                        modelManager.deleteModel(model)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: isPad ? 30 : 20))
                    }
                    .buttonStyle(.borderless)
                }
            } else if let progress = modelManager.downloadingModels[model.id] {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: isPad ? 120 : 60)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: isPad ? 16 : 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: {
                    modelManager.downloadModel(model)
                }) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: isPad ? 40 : 28))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, isPad ? 15 : 8)
    }
}
