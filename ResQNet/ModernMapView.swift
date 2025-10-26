import SwiftUI
import MapKit
import CoreLocation

struct ModernMapView: View {
    @ObservedObject var comboManager: BLEComboManager
    @ObservedObject var markerStore: MapMarkerStore
    @StateObject private var locationManager = LocationManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    @State private var selectedMarker: MapMarker?
    @State private var showingAddMarker = false
    @State private var newMarkerType: MarkerType = .medAidNeed
    @State private var bottomSheetHeight: CGFloat = 150
    @State private var isDragging = false
    @State private var filterByType: MarkerType? = nil
    @State private var currentFilteredIndex = 0
    
    private let quickMarkers: [MarkerType] = [.medAidNeed, .medAidOffer, .water, .danger]
    
    private var filteredMarkers: [MapMarker] {
        if let filter = filterByType {
            return markerStore.markers.filter { $0.markerType == filter }
        }
        return markerStore.markers
    }
    
    var body: some View {
        ZStack {
            ModernMapViewRepresentable(
                region: $region,
                markers: filteredMarkers,
                selectedMarker: $selectedMarker
            )
            .ignoresSafeArea(.all)
            
            VStack {
                HStack {
                    BluetoothStatusView(isConnected: comboManager.host.isPoweredOn && comboManager.host.isAdvertising)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Menu {
                            Button(action: {
                                filterByType = nil
                                currentFilteredIndex = 0
                            }) {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease")
                                    Text("Alle anzeigen")
                                    if filterByType == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Divider()
                            
                            ForEach(MarkerType.allCases, id: \.self) { markerType in
                                Button(action: {
                                    filterByType = markerType
                                    currentFilteredIndex = 0
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if !filteredMarkers.isEmpty {
                                            focusOnMarker(filteredMarkers[0])
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: markerType.systemImage)
                                            .foregroundColor(markerType.color)
                                        Text(markerType.label)
                                        Spacer()
                                        if filterByType == markerType {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filterByType?.systemImage ?? "line.3.horizontal.decrease")
                                    .font(.caption)
                                if filterByType != nil {
                                    Text("\(filteredMarkers.count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(height: 32)
                            .padding(.horizontal, 8)
                            .background(filterByType != nil ? filterByType!.color : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 2)
                        }
                        
                        // Next Marker Button (nur bei aktivem Filter)
                        if filterByType != nil && !filteredMarkers.isEmpty {
                            Button(action: focusOnNextFilteredMarker) {
                                Image(systemName: "location.north")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                        
                        // Location refresh button
                        Button(action: centerOnUserLocation) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
            
            // Untere Marker-Auswahl (Sliding Sheet)
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Drag Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray)
                        .frame(width: 40, height: 6)
                        .padding(.top, 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    let newHeight = bottomSheetHeight - value.translation.height
                                    bottomSheetHeight = max(150, min(400, newHeight))
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    // Snap to positions
                                    if bottomSheetHeight < 225 {
                                        withAnimation(.spring()) {
                                            bottomSheetHeight = 150
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            bottomSheetHeight = 350
                                        }
                                    }
                                }
                        )
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Titel und Filter-Status
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Marker setzen")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                
                                // Filter Status
                                if let filter = filterByType {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: filter.systemImage)
                                                .foregroundColor(filter.color)
                                            Text("Filter: \(filter.label)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("(\(filteredMarkers.count))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(filter.color.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        Spacer()
                                        
                                        if !filteredMarkers.isEmpty {
                                            Text("\(currentFilteredIndex + 1)/\(filteredMarkers.count)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            // Quick Access Buttons (4 wichtige Marker)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                                ForEach(quickMarkers, id: \.id) { markerType in
                                    MarkerButton(
                                        markerType: markerType,
                                        action: { addMarkerAtCurrentLocation(type: markerType) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Erweiterte Marker (nur sichtbar wenn Sheet aufgezogen)
                            if bottomSheetHeight > 200 {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Weitere Marker")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    let otherMarkers = MarkerType.allCases.filter { !quickMarkers.contains($0) }
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                        ForEach(otherMarkers, id: \.id) { markerType in
                                            CompactMarkerButton(
                                                markerType: markerType,
                                                action: { addMarkerAtCurrentLocation(type: markerType) }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .frame(height: bottomSheetHeight)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                )
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: bottomSheetHeight)
            }
        }
        .sheet(item: $selectedMarker) { marker in
            MarkerDetailSheetView(marker: marker, markerStore: markerStore)
        }
        .onAppear {
            locationManager.setup()
        }
        .onReceive(locationManager.$location) { location in
            guard let location = location else { return }
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }
    
    private func centerOnUserLocation() {
        locationManager.refresh()
        if let location = locationManager.location {
            withAnimation(.easeInOut(duration: 1.0)) {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }
    
    private func focusOnNextFilteredMarker() {
        guard !filteredMarkers.isEmpty else { return }
        
        // Zum nächsten Marker wechseln (mit Wrap-around)
        currentFilteredIndex = (currentFilteredIndex + 1) % filteredMarkers.count
        
        let marker = filteredMarkers[currentFilteredIndex]
        
        // Verwende die vorhandene focusOnMarker Funktion
        focusOnMarker(marker)
        
        // Haptisches Feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🎯 Fokus auf Marker \(currentFilteredIndex + 1)/\(filteredMarkers.count): \(marker.markerType.label)")
    }
    
    private func focusOnMarker(_ marker: MapMarker) {
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MKCoordinateRegion(
                center: marker.coordinate.clLocationCoordinate2D,
                span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
            )
        }
        
        // Markiere den Marker als ausgewählt
        selectedMarker = marker
    }
    
    private func addMarkerAtCurrentLocation(type: MarkerType) {
        let coordinate = region.center
        let marker = MapMarker(
            coordinate: coordinate,
            markerType: type,
            message: "Automatisch gesetzt",
            timestamp: Date()
        )
        
        markerStore.addMarker(marker)
        // Automatische Synchronisation erfolgt jetzt in MarkerStore
        
        // Kurzes Feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Bluetooth Status View
struct BluetoothStatusView: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(isConnected ? "Verbunden" : "Nicht verbunden")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 2)
    }
}

// MARK: - Marker Buttons
struct MarkerButton: View {
    let markerType: MarkerType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: markerType.systemImage)
                    .font(.title2)
                    .foregroundColor(markerType.color)
                
                Text(markerType.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(markerType.color.opacity(0.1))
                    .stroke(markerType.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactMarkerButton: View {
    let markerType: MarkerType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: markerType.systemImage)
                    .font(.callout)
                    .foregroundColor(markerType.color)
                
                Text(markerType.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(markerType.color.opacity(0.1))
                    .stroke(markerType.color.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ModernMapView(
        comboManager: BLEComboManager(),
        markerStore: MapMarkerStore()
    )
}