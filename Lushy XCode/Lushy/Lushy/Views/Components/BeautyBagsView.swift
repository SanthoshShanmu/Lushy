import SwiftUI
import CoreData

struct BeautyBagsView: View {
    @StateObject private var viewModel = BeautyBagViewModel()
    @State private var showingAddBag = false
    @State private var showingEditBag = false
    @State private var bagToEdit: BeautyBag?
    @State private var showEditHint = false
    @State private var hasShownEditHint = false

    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.08),
                        Color.lushyPurple.opacity(0.04),
                        Color.lushyCream.opacity(0.3),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if viewModel.bags.isEmpty {
                    // Empty state with beautiful design
                    VStack(spacing: 32) {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.lushyPink.opacity(0.15), Color.lushyPurple.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "bag.badge.plus")
                                    .font(.system(size: 50, weight: .medium))
                                    .foregroundColor(.lushyPink)
                            }
                            
                            VStack(spacing: 12) {
                                Text("Create Your First Beauty Bag ✨")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.lushyPink)
                                
                                Text("Organize your beauty collection by creating custom bags for different occasions, routines, or product types.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                        
                        Button(action: { showingAddBag = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Create Beauty Bag")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.lushyPink, Color.lushyPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: Color.lushyPink.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                    }
                    .padding(.horizontal, 24)
                } else {
                    // Grid layout for bags
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("💄 Beauty Bags")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.lushyPink, .lushyPurple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        
                                        HStack(spacing: 12) {
                                            Text("\(viewModel.bags.count) beautiful collection\(viewModel.bags.count == 1 ? "" : "s")")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            // Edit hint button/indicator
                                            if !hasShownEditHint && viewModel.bags.count > 0 {
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                        showEditHint = true
                                                    }
                                                    
                                                    // Auto-hide after 4 seconds
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                            showEditHint = false
                                                            hasShownEditHint = true
                                                        }
                                                    }
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "questionmark.circle.fill")
                                                            .font(.caption)
                                                        Text("How to edit?")
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                    }
                                                    .foregroundColor(.lushyPink)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.lushyPink.opacity(0.1))
                                                    .cornerRadius(12)
                                                }
                                                .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                    }
                                    Spacer()
                                    
                                    Button(action: { showingAddBag = true }) {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.lushyPink, Color.lushyPurple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Circle())
                                            .shadow(color: Color.lushyPink.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 20)
                            }
                            
                            // Beautiful bag grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 20) {
                                ForEach(viewModel.bags, id: \.self) { bag in
                                    NavigationLink(destination: BeautyBagDetailView(bag: bag)) {
                                        ModernBagCard(bag: bag)
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            bagToEdit = bag
                                            showingEditBag = true
                                        }) {
                                            Label("Edit Bag", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            withAnimation(.spring()) {
                                                viewModel.deleteBag(bag)
                                            }
                                        }) {
                                            Label("Delete Bag", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                
                // Edit hint overlay
                if showEditHint {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showEditHint = false
                                hasShownEditHint = true
                            }
                        }
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            // Animated icon
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.lushyPink)
                                .scaleEffect(showEditHint ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showEditHint)
                            
                            VStack(spacing: 12) {
                                Text("💡 How to Edit Bags")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.lushyPink)
                                
                                VStack(spacing: 8) {
                                    Text("**Long press** any bag to see edit options:")
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                    
                                    HStack(spacing: 16) {
                                        Label("Edit", systemImage: "pencil")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        
                                        Label("Delete", systemImage: "trash")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.top, 4)
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showEditHint = false
                                hasShownEditHint = true
                            }
                        }) {
                            Text("Got it! ✨")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.lushyPink, Color.lushyPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                                .shadow(color: Color.lushyPink.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddBag) {
                ModernAddBagSheet(viewModel: viewModel)
            }
            .sheet(item: $bagToEdit) { bag in
                ModernEditBagSheet(viewModel: viewModel, bag: bag, isPresented: $showingEditBag)
            }
            .onAppear {
                viewModel.fetchBags()
                
                // Show hint automatically for first-time users after a brief delay
                if !hasShownEditHint && viewModel.bags.count > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if !hasShownEditHint { // Double-check in case user already triggered it
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showEditHint = true
                            }
                            
                            // Auto-hide after 4 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showEditHint = false
                                    hasShownEditHint = true
                                }
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissEditBagSheet"))) { _ in
                bagToEdit = nil
            }
        }
    }
}

// MARK: - Modern Bag Card Component
struct ModernBagCard: View {
    let bag: BeautyBag
    @StateObject private var viewModel = BeautyBagViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with icon and product count
            VStack(spacing: 12) {
                ZStack {
                    // Background circle for the icon
                    Circle()
                        .fill(Color(bag.color ?? "lushyPink").opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: bag.icon ?? "bag.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color(bag.color ?? "lushyPink"))
                }
                
                // Product count badge
                let productCount = viewModel.products(in: bag).count
                Text("\(productCount) product\(productCount == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(bag.color ?? "lushyPink"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(bag.color ?? "lushyPink").opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Bottom section with name
            VStack(spacing: 6) {
                Text(bag.name ?? "Unnamed Bag")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Subtle accent line
                Rectangle()
                    .fill(Color(bag.color ?? "lushyPink").opacity(0.3))
                    .frame(width: 24, height: 2)
                    .cornerRadius(1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white, location: 0),
                            .init(color: Color(bag.color ?? "lushyPink").opacity(0.04), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(bag.color ?? "lushyPink").opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(
            color: Color(bag.color ?? "lushyPink").opacity(0.1),
            radius: 12,
            x: 0,
            y: 6
        )
        .overlay(
            // Subtle highlight at the top
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.8),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.overlay)
        )
        .onAppear {
            viewModel.fetchBags()
        }
    }
}

// MARK: - Modern Add Bag Sheet
struct ModernAddBagSheet: View {
    @ObservedObject var viewModel: BeautyBagViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let iconOptions = ["bag.fill", "shippingbox.fill", "case.fill", "suitcase.fill", "heart.fill", "star.fill"]
    let colorOptions = ["lushyPink", "lushyPurple", "lushyMint", "lushyPeach"]

    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.06),
                        Color.lushyPurple.opacity(0.03),
                        Color.lushyCream.opacity(0.2),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with preview
                        VStack(spacing: 20) {
                            Text("Create New Beauty Bag")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.lushyPink, .lushyPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Live preview
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(viewModel.newBagColor).opacity(0.15))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: viewModel.newBagIcon)
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(Color(viewModel.newBagColor))
                                }
                                
                                Text(viewModel.newBagName.isEmpty ? "Bag Name" : viewModel.newBagName)
                                    .font(.headline)
                                    .foregroundColor(viewModel.newBagName.isEmpty ? .secondary : .primary)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.9))
                                    .shadow(color: Color(viewModel.newBagColor).opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        VStack(spacing: 24) {
                            // Name input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bag Name")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter bag name...", text: $viewModel.newBagName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            // Icon selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Icon")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                    ForEach(iconOptions, id: \.self) { icon in
                                        let isSelected = icon == viewModel.newBagIcon
                                        Button(action: { viewModel.newBagIcon = icon }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: icon)
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(isSelected ? .white : Color(viewModel.newBagColor))
                                                
                                                Text(icon.replacingOccurrences(of: ".fill", with: ""))
                                                    .font(.caption)
                                                    .foregroundColor(isSelected ? .white : .secondary)
                                            }
                                            .frame(height: 70)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(isSelected ? Color(viewModel.newBagColor) : Color.white)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(Color(viewModel.newBagColor).opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                                                    )
                                            )
                                            .shadow(color: isSelected ? Color(viewModel.newBagColor).opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Color selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Color")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 16) {
                                    ForEach(colorOptions, id: \.self) { colorName in
                                        let isSelected = colorName == viewModel.newBagColor
                                        Button(action: { viewModel.newBagColor = colorName }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(colorName))
                                                    .frame(width: 50, height: 50)
                                                
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                                            )
                                            .shadow(color: Color(colorName).opacity(0.4), radius: isSelected ? 8 : 4, x: 0, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Create button
                        Button(action: {
                            viewModel.createBag()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Create Beauty Bag")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: viewModel.newBagName.isEmpty ? [Color.gray.opacity(0.3)] : [Color.lushyPink, Color.lushyPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: viewModel.newBagName.isEmpty ? Color.clear : Color.lushyPink.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.newBagName.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        presentationMode.wrappedValue.dismiss() 
                    }
                    .foregroundColor(.lushyPink)
                }
            }
        }
    }
}

// MARK: - Modern Edit Bag Sheet
struct ModernEditBagSheet: View {
    @ObservedObject var viewModel: BeautyBagViewModel
    let bag: BeautyBag
    @Binding var isPresented: Bool
    
    @State private var editName: String = ""
    @State private var editIcon: String = ""
    @State private var editColor: String = ""
    
    let iconOptions = ["bag.fill", "shippingbox.fill", "case.fill", "suitcase.fill", "heart.fill", "star.fill"]
    let colorOptions = ["lushyPink", "lushyPurple", "lushyMint", "lushyPeach"]

    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.06),
                        Color.lushyPurple.opacity(0.03),
                        Color.lushyCream.opacity(0.2),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with preview
                        VStack(spacing: 20) {
                            Text("Edit Beauty Bag")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.lushyPink, .lushyPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Live preview
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(editColor).opacity(0.15))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: editIcon)
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(Color(editColor))
                                }
                                
                                Text(editName.isEmpty ? "Bag Name" : editName)
                                    .font(.headline)
                                    .foregroundColor(editName.isEmpty ? .secondary : .primary)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.9))
                                    .shadow(color: Color(editColor).opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        VStack(spacing: 24) {
                            // Name input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bag Name")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter bag name...", text: $editName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            // Icon selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Icon")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                    ForEach(iconOptions, id: \.self) { icon in
                                        let isSelected = icon == editIcon
                                        Button(action: { editIcon = icon }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: icon)
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(isSelected ? .white : Color(editColor))
                                                
                                                Text(icon.replacingOccurrences(of: ".fill", with: ""))
                                                    .font(.caption)
                                                    .foregroundColor(isSelected ? .white : .secondary)
                                            }
                                            .frame(height: 70)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(isSelected ? Color(editColor) : Color.white)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(Color(editColor).opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                                                    )
                                            )
                                            .shadow(color: isSelected ? Color(editColor).opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Color selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Color")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 16) {
                                    ForEach(colorOptions, id: \.self) { colorName in
                                        let isSelected = colorName == editColor
                                        Button(action: { editColor = colorName }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(colorName))
                                                    .frame(width: 50, height: 50)
                                                
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                                            )
                                            .shadow(color: Color(colorName).opacity(0.4), radius: isSelected ? 8 : 4, x: 0, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Save button
                        Button(action: {
                            viewModel.updateBag(bag, name: editName, color: editColor, icon: editIcon)
                            // Clear bagToEdit to dismiss the sheet since it's presented with .sheet(item:)
                            DispatchQueue.main.async {
                                // Reset the bagToEdit to nil in the parent view to dismiss the sheet
                                NotificationCenter.default.post(name: NSNotification.Name("DismissEditBagSheet"), object: nil)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                Text("Save Changes")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: editName.isEmpty ? [Color.gray.opacity(0.3)] : [Color.lushyPink, Color.lushyPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: editName.isEmpty ? Color.clear : Color.lushyPink.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(editName.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        // Clear bagToEdit to dismiss the sheet
                        NotificationCenter.default.post(name: NSNotification.Name("DismissEditBagSheet"), object: nil)
                    }
                    .foregroundColor(.lushyPink)
                }
            }
        }
        .onAppear {
            editName = bag.name ?? ""
            editIcon = bag.icon ?? "bag.fill"
            editColor = bag.color ?? "lushyPink"
        }
    }
}

struct BeautyBagDetailView: View {
    let bag: BeautyBag
    @StateObject private var viewModel = BeautyBagViewModel()
    @State private var showHowToAdd = false
    @State private var showAddFromProducts = false
    @State private var showEditBag = false
    @State private var selectedTag: ProductTag?
    @State private var allTags: [ProductTag] = []
    @State private var allUserProducts: [UserProduct] = []
    @State private var selectedProductsToAdd: Set<NSManagedObjectID> = []
    @EnvironmentObject private var tabSelection: TabSelection
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder private var headerView: some View {
        VStack(spacing: 20) {
            // Custom header with bag info and edit button
            HStack {
                Button("Back") { dismiss() }
                    .foregroundColor(.lushyPink)
                Spacer()
                Button("Edit") { showEditBag = true }
                    .foregroundColor(.lushyPink)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal)
            
            // Bag preview section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(bag.color ?? "lushyPink").opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: bag.icon ?? "bag.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color(bag.color ?? "lushyPink"))
                }
                
                VStack(spacing: 8) {
                    Text(bag.name ?? "Unnamed Bag")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Content overview
                    let productCount = viewModel.products(in: bag).count
                    Text("\(productCount) product\(productCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Quick stats
                    if productCount > 0 {
                        let favoriteCount = viewModel.products(in: bag).filter { $0.favorite }.count
                        let openCount = viewModel.products(in: bag).filter { $0.openDate != nil }.count
                        
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text("\(favoriteCount)")
                                    .font(.headline)
                                    .foregroundColor(.lushyPink)
                                Text("Favorites")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(openCount)")
                                    .font(.headline)
                                    .foregroundColor(.lushyMint)
                                Text("Opened")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }

    @ViewBuilder private var filterSection: some View {
        if !allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // All tags button
                    Button(action: { selectedTag = nil }) {
                        Text("All")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTag == nil ? .white : .lushyPink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedTag == nil ? Color.lushyPink : Color.lushyPink.opacity(0.1))
                            )
                    }
                    
                    ForEach(allTags, id: \.self) { tag in
                        Button(action: { selectedTag = selectedTag == tag ? nil : tag }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 8, height: 8)
                                Text(tag.name ?? "Tag")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedTag == tag ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedTag == tag ? Color(tag.color ?? "lushyPink") : Color(tag.color ?? "lushyPink").opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: { showAddFromProducts = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                    Text("Add from Products")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.lushyPink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.lushyPink, lineWidth: 1)
                        .background(Color.lushyPink.opacity(0.05))
                )
            }
            
            Button(action: {
                withAnimation { tabSelection.selected = .scan }
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 16))
                    Text("Scan Product")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.lushyPink, .lushyPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder private var emptyStateView: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.lushyPink.opacity(0.15), .lushyPurple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                Image(systemName: "bag.badge.plus")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundColor(.lushyPink)
            }
            
            VStack(spacing: 12) {
                Text("This bag is feeling a little empty ✨")
                    .font(.title3).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Add products to start building your collection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            
            actionButtonsSection
            
            Button(action: { showHowToAdd = true }) {
                Label("How to Add Products", systemImage: "questionmark.circle")
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.lushyPink.opacity(0.08))
                    .foregroundColor(.lushyPink)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    var filteredProducts: [UserProduct] {
        var products = viewModel.products(in: bag)
        if let selectedTag = selectedTag {
            products = products.filter { product in
                guard let tags = product.tags as? Set<ProductTag> else { return false }
                return tags.contains(selectedTag)
            }
        }
        return products.sorted { ($0.productName ?? "") < ($1.productName ?? "") }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.06),
                        Color.lushyPurple.opacity(0.03),
                        Color.lushyCream.opacity(0.2),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                let products = filteredProducts
                
                if products.isEmpty && selectedTag == nil {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerView
                            
                            if !products.isEmpty {
                                VStack(spacing: 16) {
                                    // Filter section
                                    filterSection
                                    
                                    // Always show action buttons
                                    actionButtonsSection
                                    
                                    // Products list
                                    LazyVStack(spacing: 12) {
                                        ForEach(products, id: \.self) { product in
                                            NavigationLink(destination: ProductDetailView(viewModel: ProductDetailViewModel(product: product))) {
                                                PrettyProductRow(product: product)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .fill(Color.white.opacity(0.9))
                                                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                                    )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } else if selectedTag != nil {
                                // Filtered empty state
                                VStack(spacing: 20) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundColor(.lushyPink.opacity(0.6))
                                    
                                    VStack(spacing: 8) {
                                        Text("No products found")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("No products match the selected tag in this bag.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.top, 60)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditBag) {
            ModernEditBagSheet(viewModel: viewModel, bag: bag, isPresented: $showEditBag)
        }
        .sheet(isPresented: $showAddFromProducts) {
            AddFromProductsSheet(
                bag: bag,
                allProducts: allUserProducts,
                selectedProducts: $selectedProductsToAdd,
                isPresented: $showAddFromProducts,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showHowToAdd) {
            VStack(spacing: 24) {
                Text("Adding Products")
                    .font(.title2).fontWeight(.bold)
                VStack(alignment: .leading, spacing: 16) {
                    Label("Tap Scan tab to scan a barcode and auto‑fill details.", systemImage: "barcode.viewfinder")
                    Label("Or use Manual Entry from the scanner for products without barcodes.", systemImage: "square.and.pencil")
                    Label("Use 'Add from Products' to add existing products to this bag.", systemImage: "plus.circle")
                }
                .font(.callout)
                .foregroundColor(.secondary)
                Button("Got it") { showHowToAdd = false }
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.lushyPink))
                    .foregroundColor(.white)
            }
            .padding(30)
            .presentationDetents([.medium])
        }
        .onAppear {
            viewModel.fetchBags()
            SyncService.shared.fetchRemoteProducts()
            fetchAllTags()
            fetchAllUserProducts()
        }
    }
    
    private func fetchAllTags() {
        let bagProducts = viewModel.products(in: bag)
        var tagSet = Set<ProductTag>()
        
        for product in bagProducts {
            if let tags = product.tags as? Set<ProductTag> {
                tagSet.formUnion(tags)
            }
        }
        
        allTags = Array(tagSet).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    private func fetchAllUserProducts() {
        allUserProducts = CoreDataManager.shared.fetchUserProducts()
            .filter { product in
                // Filter out products already in this bag and finished products
                guard product.value(forKey: "isFinished") as? Bool != true else { return false }
                guard let bags = product.bags as? Set<BeautyBag> else { return true }
                return !bags.contains(bag)
            }
    }
}

// MARK: - Add From Products Sheet
struct AddFromProductsSheet: View {
    let bag: BeautyBag
    let allProducts: [UserProduct]
    @Binding var selectedProducts: Set<NSManagedObjectID>
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: BeautyBagViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Add Products to \(bag.name ?? "Bag")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Select products from your collection to add to this bag")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                if allProducts.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.lushyPink.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("No products available")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Add some products to your collection first, then you can organize them into bags.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Products list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(allProducts, id: \.self) { product in
                                Button(action: {
                                    if selectedProducts.contains(product.objectID) {
                                        selectedProducts.remove(product.objectID)
                                    } else {
                                        selectedProducts.insert(product.objectID)
                                    }
                                }) {
                                    HStack {
                                        PrettyProductRow(product: product)
                                        
                                        Spacer()
                                        
                                        Image(systemName: selectedProducts.contains(product.objectID) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedProducts.contains(product.objectID) ? .lushyPink : .gray)
                                    }
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(selectedProducts.contains(product.objectID) ? 
                                                  Color.lushyPink.opacity(0.08) : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(selectedProducts.contains(product.objectID) ? 
                                                           Color.lushyPink : Color.clear, lineWidth: 2)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.lushyPink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(selectedProducts.count))") {
                        addSelectedProducts()
                        isPresented = false
                    }
                    .foregroundColor(.lushyPink)
                    .fontWeight(.semibold)
                    .disabled(selectedProducts.isEmpty)
                }
            }
        }
    }
    
    private func addSelectedProducts() {
        let context = CoreDataManager.shared.viewContext
        for productID in selectedProducts {
            if let product = try? context.existingObject(with: productID) as? UserProduct {
                viewModel.addProduct(product, to: bag)
            }
        }
        selectedProducts.removeAll()
    }
}
