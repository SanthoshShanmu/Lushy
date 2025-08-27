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
                ModernEditBagSheet(viewModel: viewModel, bag: bag)
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
            // Large image/icon section - inspired by collection covers
            ZStack {
                // Background for the image area
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(bag.color ?? "lushyPink").opacity(0.2),
                                Color(bag.color ?? "lushyPink").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                
                // Image or icon content
                if let imageData = bag.imageData, let customImage = UIImage(data: imageData) {
                    // Custom image from camera/photo library - large and prominent
                    Image(uiImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    // Icon overlay when no custom image
                    VStack(spacing: 8) {
                        if let icon = bag.icon, icon.count == 1 {
                            // Emoji icon - larger for prominence
                            Text(icon)
                                .font(.system(size: 40))
                        } else {
                            // System icon with bag color - larger and more prominent
                            Image(systemName: bag.icon ?? "bag.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                        }
                        
                        // Product count badge
                        let productCount = viewModel.products(in: bag).count
                        if productCount > 0 {
                            Text("\(productCount) item\(productCount == 1 ? "" : "s")")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Bottom section with name and description - more compact
            VStack(spacing: 6) {
                Text(bag.name ?? "Unnamed Bag")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Show description if available - smaller and more subtle
                if let description = bag.bagDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
                
                // Privacy indicator - more subtle
                if bag.isPrivate {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Private")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(height: 180) // Consistent height for grid layout
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(bag.color ?? "lushyPink").opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(bag.color ?? "lushyPink").opacity(0.15), lineWidth: 1)
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
    
    @State private var showingIconSelector = false
    @State private var showingImagePicker = false
    @State private var bagImage: UIImage? = nil
    @State private var imageSource: ImageSourceType = .none
    
    enum ImageSourceType {
        case none, camera, library
    }
    
    private let colorOptions = ["lushyPink", "lushyPurple", "mossGreen", "lushyPeach"]

    var body: some View {
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
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Button("Cancel") { 
                        presentationMode.wrappedValue.dismiss() 
                    }
                    .foregroundColor(.lushyPink)
                    .font(.body)
                    
                    Spacer()
                    
                    Text("Create New Bag")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Save") {
                        viewModel.createBag(with: bagImage)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(viewModel.newBagName.isEmpty ? .gray : .lushyPink)
                    .font(.body)
                    .fontWeight(.medium)
                    .disabled(viewModel.newBagName.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.95))
                
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
                                    
                                    // Show custom image if available, otherwise show icon
                                    if let bagImage = bagImage {
                                        Image(uiImage: bagImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 70, height: 70)
                                            .clipShape(Circle())
                                    } else if viewModel.newBagIcon.count == 1 {
                                        // Emoji icon
                                        Text(viewModel.newBagIcon)
                                            .font(.system(size: 32))
                                    } else {
                                        // System icon
                                        Image(systemName: viewModel.newBagIcon)
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(Color(viewModel.newBagColor))
                                    }
                                }
                                
                                VStack(spacing: 4) {
                                    Text(viewModel.newBagName.isEmpty ? "Bag Name" : viewModel.newBagName)
                                        .font(.headline)
                                        .foregroundColor(viewModel.newBagName.isEmpty ? .secondary : .primary)
                                    
                                    if !viewModel.newBagDescription.isEmpty {
                                        Text(viewModel.newBagDescription)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
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
                            
                            // Description input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Add a description for your bag...", text: $viewModel.newBagDescription, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(2...4)
                                    .font(.body)
                            }
                            
                            // Image selection section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bag Image (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        imageSource = .camera
                                        showingImagePicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 16))
                                            Text("Take Photo")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [.lushyPink, .lushyPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        imageSource = .library
                                        showingImagePicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 16))
                                            Text("Choose Photo")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.lushyPink)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.lushyPink, lineWidth: 1.5)
                                                .background(Color.lushyPink.opacity(0.05))
                                        )
                                    }
                                    
                                    if bagImage != nil {
                                        Button(action: {
                                            bagImage = nil
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.red, lineWidth: 1.5)
                                                        .background(Color.red.opacity(0.05))
                                                )
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            // Icon selection with enhanced picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Icon")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Button(action: { showingIconSelector = true }) {
                                    HStack {
                                        if viewModel.newBagIcon.count == 1 {
                                            // Emoji icon
                                            Text(viewModel.newBagIcon)
                                                .font(.system(size: 24))
                                        } else {
                                            // System icon
                                            Image(systemName: viewModel.newBagIcon)
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundColor(Color(viewModel.newBagColor))
                                        }
                                        
                                        Text("Tap to choose icon")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
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
                            
                            // Privacy toggle
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Privacy Setting")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Private bags are only visible to you")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $viewModel.newBagIsPrivate)
                                        .toggleStyle(SwitchToggleStyle(tint: .lushyPink))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showingIconSelector) {
            IconSelectorView(selectedIcon: $viewModel.newBagIcon, icons: [
                "bag.fill", "case.fill", "suitcase.fill", "backpack.fill",
                "sparkles", "star.fill", "heart.fill", "leaf.fill",
                "💄", "✨", "🌸", "💅", "🎀", "💖", "🌺", "🦋"
            ], onIconSelected: { _ in })
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $bagImage, sourceType: imageSource == .camera ? .camera : .photoLibrary)
        }
    }
}

// MARK: - Modern Edit Bag Sheet
struct ModernEditBagSheet: View {
    @ObservedObject var viewModel: BeautyBagViewModel
    let bag: BeautyBag
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingIconSelector = false
    @State private var showingImagePicker = false
    @State private var bagImage: UIImage? = nil
    @State private var imageSource: ImageSourceType = .none
    
    enum ImageSourceType {
        case none, camera, library
    }
    
    private let colorOptions = ["lushyPink", "lushyPurple", "mossGreen", "lushyPeach"]
    
    var body: some View {
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
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Button("Cancel") { 
                        presentationMode.wrappedValue.dismiss() 
                    }
                    .foregroundColor(.lushyPink)
                    .font(.body)
                    
                    Spacer()
                    
                    Text("Edit Bag")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Save") {
                        viewModel.updateBag(bag, with: bagImage)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(viewModel.editBagName.isEmpty ? .gray : .lushyPink)
                    .font(.body)
                    .fontWeight(.medium)
                    .disabled(viewModel.editBagName.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.95))
                
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
                                        .fill(Color(viewModel.editBagColor).opacity(0.15))
                                        .frame(width: 80, height: 80)
                                    
                                    // Show custom image if available, otherwise show icon
                                    if let bagImage = bagImage {
                                        Image(uiImage: bagImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 70, height: 70)
                                            .clipShape(Circle())
                                    } else if viewModel.editBagIcon.count == 1 {
                                        // Emoji icon
                                        Text(viewModel.editBagIcon)
                                            .font(.system(size: 32))
                                    } else {
                                        // System icon
                                        Image(systemName: viewModel.editBagIcon)
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(Color(viewModel.editBagColor))
                                    }
                                }
                                
                                VStack(spacing: 4) {
                                    Text(viewModel.editBagName.isEmpty ? "Bag Name" : viewModel.editBagName)
                                        .font(.headline)
                                        .foregroundColor(viewModel.editBagName.isEmpty ? .secondary : .primary)
                                    
                                    if !viewModel.editBagDescription.isEmpty {
                                        Text(viewModel.editBagDescription)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.9))
                                    .shadow(color: Color(viewModel.editBagColor).opacity(0.1), radius: 8, x: 0, y: 4)
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
                                
                                TextField("Enter bag name...", text: $viewModel.editBagName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            // Description input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Add a description for your bag...", text: $viewModel.editBagDescription, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(2...4)
                                    .font(.body)
                            }
                            
                            // Image selection section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bag Image (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        imageSource = .camera
                                        showingImagePicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 16))
                                            Text("Take Photo")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [.lushyPink, .lushyPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        imageSource = .library
                                        showingImagePicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 16))
                                            Text("Choose Photo")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.lushyPink)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.lushyPink, lineWidth: 1.5)
                                                .background(Color.lushyPink.opacity(0.05))
                                        )
                                    }
                                    
                                    if bagImage != nil {
                                        Button(action: {
                                            bagImage = nil
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.red, lineWidth: 1.5)
                                                        .background(Color.red.opacity(0.05))
                                                )
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            // Icon selection with enhanced picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Icon")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Button(action: { showingIconSelector = true }) {
                                    HStack {
                                        if viewModel.editBagIcon.count == 1 {
                                            // Emoji icon
                                            Text(viewModel.editBagIcon)
                                                .font(.system(size: 24))
                                        } else {
                                            // System icon
                                            Image(systemName: viewModel.editBagIcon)
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundColor(Color(viewModel.editBagColor))
                                        }
                                        
                                        Text("Tap to choose icon")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Color selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Color")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 16) {
                                    ForEach(colorOptions, id: \.self) { colorName in
                                        let isSelected = colorName == viewModel.editBagColor
                                        Button(action: { viewModel.editBagColor = colorName }) {
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
                            
                            // Privacy toggle
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Privacy Setting")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Private bags are only visible to you")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $viewModel.editBagIsPrivate)
                                        .toggleStyle(SwitchToggleStyle(tint: .lushyPink))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            viewModel.prepareForEditing(bag: bag)
        }
        .sheet(isPresented: $showingIconSelector) {
            IconSelectorView(selectedIcon: $viewModel.editBagIcon, icons: [
                "bag.fill", "case.fill", "suitcase.fill", "backpack.fill",
                "sparkles", "star.fill", "heart.fill", "leaf.fill",
                "💄", "✨", "🌸", "💅", "🎀", "💖", "🌺", "🦋"
            ], onIconSelected: { _ in })
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $bagImage, sourceType: imageSource == .camera ? .camera : .photoLibrary)
        }
    }
}
