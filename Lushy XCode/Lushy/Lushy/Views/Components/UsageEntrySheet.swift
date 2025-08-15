import SwiftUI

struct UsageEntrySheet: View {
    @ObservedObject var viewModel: UsageTrackingViewModel
    @Binding var customAmount: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Usage Type Selection
                usageTypeSection
                
                // Custom Amount Input (if custom selected)
                if viewModel.selectedUsageType == "custom" {
                    customAmountSection
                }
                
                // Notes Section
                notesSection
                
                Spacer()
                
                // Action Buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Track Usage")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveUsage()
                }
                .disabled(!canSave)
            )
        }
    }
    
    private var usageTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Amount")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(viewModel.usageTypes.keys.sorted()), id: \.self) { key in
                    UsageTypeCard(
                        type: key,
                        description: viewModel.usageTypes[key]?.description ?? "",
                        amount: viewModel.usageTypes[key]?.amount ?? 0,
                        isSelected: viewModel.selectedUsageType == key,
                        action: {
                            viewModel.selectedUsageType = key
                        }
                    )
                }
            }
        }
    }
    
    private var customAmountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Percentage")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                TextField("Enter amount", text: $customAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Enter the percentage of product you used (0-100)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lushyPink.opacity(0.1))
        )
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Add any notes about this usage...", text: $viewModel.usageNotes, axis: .vertical)
                .lineLimit(3)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveUsage) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Track Usage")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: canSave ? [.mossGreen, .lushyPeach] : [.gray.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!canSave)
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var canSave: Bool {
        if viewModel.selectedUsageType == "custom" {
            return Double(customAmount) != nil && !customAmount.isEmpty
        }
        return !viewModel.selectedUsageType.isEmpty
    }
    
    private func saveUsage() {
        let customAmountValue = viewModel.selectedUsageType == "custom" ? Double(customAmount) : nil
        viewModel.addUsageEntry(type: viewModel.selectedUsageType, customAmount: customAmountValue)
        presentationMode.wrappedValue.dismiss()
    }
}

struct UsageTypeCard: View {
    let type: String
    let description: String
    let amount: Double
    let isSelected: Bool
    let action: () -> Void
    
    private var cardColor: Color {
        switch type {
        case "light": return .mossGreen
        case "medium": return .lushyPeach
        case "heavy": return .lushyPink
        case "custom": return .lushyPurple
        default: return .gray
        }
    }
    
    private var iconName: String {
        switch type {
        case "light": return "drop"
        case "medium": return "drop.fill"
        case "heavy": return "drop.triangle.fill"
        case "custom": return "slider.horizontal.3"
        default: return "circle"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : cardColor)
                
                Text(description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                if type != "custom" {
                    Text("-\(Int(amount))%")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? cardColor : cardColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(cardColor, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
