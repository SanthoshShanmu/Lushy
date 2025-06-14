import SwiftUI

struct TagManagerView: View {
    @StateObject private var viewModel = TagViewModel()
    @State private var showingAddTag = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.tags, id: \.self) { tag in
                    HStack {
                        Circle()
                            .fill(Color(tag.color ?? "blue"))
                            .frame(width: 16, height: 16)
                        Text(tag.name ?? "Unnamed Tag")
                        Spacer()
                        Button(action: { viewModel.deleteTag(tag) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.lushyPurple.opacity(0.06), radius: 3, x: 0, y: 2)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color.lushyBackground.opacity(0.2))
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTag = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.lushyPink)
                            .padding(8)
                            .background(Circle().fill(Color.lushyPink.opacity(0.12)))
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                AddTagSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.fetchTags()
            }
        }
    }
}

struct AddTagSheet: View {
    @ObservedObject var viewModel: TagViewModel
    @Environment(\.presentationMode) var presentationMode
    let colorOptions = ["lushyPink", "lushyPurple", "lushyMint", "lushyPeach", "blue", "green"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tag Details")) {
                    TextField("Tag Name", text: $viewModel.newTagName)
                    Picker("Color", selection: $viewModel.newTagColor) {
                        ForEach(colorOptions, id: \.self) { color in
                            Text(color.capitalized)
                        }
                    }
                }
                Section {
                    Button("Create Tag") {
                        viewModel.createTag()
                        presentationMode.wrappedValue.dismiss()
                    }.disabled(viewModel.newTagName.isEmpty)
                }
            }
            .navigationTitle("New Tag")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
