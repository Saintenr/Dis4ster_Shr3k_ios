import SwiftUI
import MapKit

struct MarkerDetailSheetView: View {
    let marker: MapMarker
    @ObservedObject var markerStore: MapMarkerStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header mit Marker-Icon und Typ
                VStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(marker.markerType.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: marker.markerType.systemImage)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(marker.markerType.color)
                    }
                    
                    // Titel und Zeitstempel
                    VStack(spacing: 8) {
                        Text(marker.markerType.label)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(marker.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                
                // Content
                VStack(spacing: 20) {
                    // Nachricht
                    if let message = marker.message, !message.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Nachricht", systemImage: "message.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(message)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                    
                    // Koordinaten
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Koordinaten", systemImage: "mappin.and.ellipse")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Breitengrad: \(String(format: "%.6f", marker.coordinate.latitude))")
                            Text("Längengrad: \(String(format: "%.6f", marker.coordinate.longitude))")
                        }
                        .font(.body)
                        .fontDesign(.monospaced)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    
                    // Aktionen
                    VStack(spacing: 12) {
                        // Apple Maps Navigation Button
                        Button(action: openInAppleMaps) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("In Apple Maps öffnen")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.blue)
                            )
                        }
                        
                        // Koordinaten teilen
                        Button(action: shareCoordinates) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Koordinaten teilen")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.blue.opacity(0.1))
                            )
                        }
                        
                        // Löschen Button
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Marker löschen")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.red.opacity(0.1))
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Marker löschen", isPresented: $showingDeleteAlert) {
            Button("Löschen", role: .destructive) {
                markerStore.removeMarker(marker)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchten Sie diesen Marker wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
    
    private func openInAppleMaps() {
        let coordinate = marker.coordinate.clLocationCoordinate2D
        
        // Use the new iOS 26.0+ APIs
        let mapItem: MKMapItem
        if #available(iOS 26.0, *) {
            // Use the new location-based initializer
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            mapItem = MKMapItem(location: location, address: nil)
        } else {
            // Fallback for older iOS versions
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        }
        
        mapItem.name = marker.markerType.label
        
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    private func shareCoordinates() {
        let coordinate = marker.coordinate.clLocationCoordinate2D
        let coordinateString = "\(coordinate.latitude), \(coordinate.longitude)"
        let textToShare = "ResQNet Marker: \(marker.markerType.label)\nKoordinaten: \(coordinateString)"
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let activityViewController = UIActivityViewController(
                activityItems: [textToShare],
                applicationActivities: nil
            )
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

#Preview {
    MarkerDetailSheetView(
        marker: MapMarker(
            coordinate: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
            markerType: .medAidNeed,
            message: "Notfall - Erste Hilfe benötigt!"
        ),
        markerStore: MapMarkerStore()
    )
}