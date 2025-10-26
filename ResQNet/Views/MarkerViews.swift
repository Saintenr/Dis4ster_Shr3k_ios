import SwiftUI
import MapKit

struct AddMarkerView: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D
    @ObservedObject var markerStore: MapMarkerStore
    let onDismiss: () -> Void
    
    @State private var selectedType: MarkerType = .medAidNeed
    @State private var message: String = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Marker Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(MarkerType.allCases) { type in
                            Label(type.label, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section(header: Text("Details")) {
                    TextField("Message (optional)", text: $message, axis: .vertical)
                        .lineLimit(1...5)
                }
                
                Section {
                    Button(action: saveMarker) {
                        HStack {
                            Spacer()
                            Text("Save Marker")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Add Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func saveMarker() {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let newMarker = MapMarker(
            coordinate: coordinate,
            markerType: selectedType,
            message: trimmedMessage.isEmpty ? nil : trimmedMessage
        )
        
        markerStore.addMarker(newMarker)
        onDismiss()
    }
}

struct MarkerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerStore: MapMarkerStore
    @State private var showingDeleteAlert = false
    @State private var marker: MapMarker
    
    init(marker: MapMarker, markerStore: MapMarkerStore) {
        self.marker = marker
        self.markerStore = markerStore
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    HStack {
                        Label(marker.markerType.label, systemImage: marker.markerType.systemImage)
                            .foregroundColor(marker.markerType.color)
                        Spacer()
                        Text(marker.timestamp.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let message = marker.message, !message.isEmpty {
                        Text(message)
                            .padding(.vertical, 8)
                    }
                    
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text("\(String(format: "%.6f", marker.coordinate.latitude)), \(String(format: "%.6f", marker.coordinate.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Marker", systemImage: "trash")
                            ProgressView()
                        }
                    }
                }
            }
            .navigationTitle("Marker Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Marker", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    markerStore.removeMarker(marker)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this marker? This action cannot be undone.")
            }
        }
    }
}


