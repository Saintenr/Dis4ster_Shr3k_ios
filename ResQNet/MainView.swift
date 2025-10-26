import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Identifiable wrapper for the sheet
private struct IdentifiedCoordinate: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

// MARK: - Main View
struct MainView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var markerStore = MapMarkerStore()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    
    @State private var selectedMarker: MapMarker?
    @State private var addMarkerDraft: IdentifiedCoordinate?   // replaces optional raw coordinate
    @State private var filterByType: MarkerType? = nil
    @State private var showingFilterSheet = false
    
    // MARK: - UIKit Map wrapper
    struct MapView: UIViewRepresentable {
        @Binding var region: MKCoordinateRegion
        @Binding var markers: [MapMarker]
        @Binding var selectedMarker: MapMarker?
        var filterByType: MarkerType?
        
        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
            return mapView
        }
        
        func updateUIView(_ mapView: MKMapView, context: Context) {
            if mapView.region.center.latitude != region.center.latitude ||
                mapView.region.center.longitude != region.center.longitude ||
                mapView.region.span.latitudeDelta != region.span.latitudeDelta ||
                mapView.region.span.longitudeDelta != region.span.longitudeDelta {
                mapView.setRegion(region, animated: true)
            }
            
            // Update annotations efficiently
            let current = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(current)
            
            // Filter markers if a type is selected
            let filteredMarkers = filterByType == nil ? markers : markers.filter { $0.markerType == filterByType! }
            
            let newAnnotations = filteredMarkers.map { marker -> MKPointAnnotation in
                let a = MKPointAnnotation()
                a.coordinate = marker.coordinate.clLocationCoordinate2D
                a.title = marker.markerType.label
                a.subtitle = marker.message
                return a
            }
            mapView.addAnnotations(newAnnotations)
            
            // When filtering, center on the nearest marker to the user's location
            if filterByType != nil && !filteredMarkers.isEmpty, 
               let userLocation = mapView.userLocation.location {
                
                // Find the nearest marker to the user's location
                let nearestMarker = filteredMarkers.min(by: { 
                    let loc1 = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    let loc2 = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                    return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
                })
                
                // If we found a marker, center the map on it with a reasonable zoom level
                if let nearestMarker = nearestMarker {
                    let markerLocation = CLLocationCoordinate2D(
                        latitude: nearestMarker.coordinate.latitude,
                        longitude: nearestMarker.coordinate.longitude
                    )
                    let region = MKCoordinateRegion(
                        center: markerLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                    mapView.setRegion(region, animated: true)
                }
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        init(_ parent: MapView) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            // Find the corresponding marker in our store
            let marker = parent.markers.first { marker in
                let markerLocation = CLLocation(latitude: marker.coordinate.latitude, longitude: marker.coordinate.longitude)
                let annotationLocation = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
                return markerLocation.distance(from: annotationLocation) < 5 // 5 meters tolerance
            }
            
            let identifier = "marker"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            if let marker = marker {
                // Configure the marker appearance based on its type
                view.markerTintColor = UIColor(marker.markerType.color)
                view.glyphImage = UIImage(systemName: marker.markerType.systemImage)
                view.glyphTintColor = .white
                
                // Adjust the size based on marker type if needed
                switch marker.markerType {
                case .danger:
                    view.displayPriority = .required
                default:
                    view.displayPriority = .defaultHigh
                }
            }
            
            view.annotation = annotation
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            return view
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation else { return }
            
            // Safer matching (avoid exact double equality)
            let tolMeters: CLLocationDistance = 5
            let annLoc = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
            
            parent.selectedMarker = parent.markers.first(where: { m in
                let mLoc = CLLocation(latitude: m.coordinate.latitude, longitude: m.coordinate.longitude)
                return mLoc.distance(from: annLoc) <= tolMeters
            })
        }
    }
}
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map takes up the whole screen
                MapView(region: $region, markers: $markerStore.markers, selectedMarker: $selectedMarker, filterByType: filterByType)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        // Reset filter when view appears
                        filterByType = nil
                    }
                    .onAppear {
                        locationManager.setup()
                        
                        // Kick the region once when we first get a location
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                            if let location = locationManager.location {
                                withAnimation {
                                    region = MKCoordinateRegion(
                                        center: location.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                }
                                timer.invalidate()
                            }
                        }
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
                
                // Bottom buttons overlay
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { searchMarkersInRegion() }) {
                            HStack {
                                if filterByType != nil {
                                    Image(systemName: filterByType!.systemImage)
                                    Text("Filter: \(filterByType!.label)")
                                        .lineLimit(1)
                                } else {
                                    Text("Filter Marker")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(filterByType != nil ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .sheet(isPresented: $showingFilterSheet) {
                            NavigationView {
                                List {
                                    ForEach(MarkerType.allCases) { type in
                                        Button(action: {
                                            filterByType = type
                                            showingFilterSheet = false
                                        }) {
                                            HStack {
                                                Image(systemName: type.systemImage)
                                                    .foregroundColor(.blue)
                                                Text(type.label)
                                                Spacer()
                                                if filterByType == type {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                        .foregroundColor(.primary)
                                    }
                                    
                                    Button("Clear Filter") {
                                        filterByType = nil
                                        showingFilterSheet = false
                                    }
                                    .foregroundColor(.red)
                                }
                                .navigationTitle("Filter by Type")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("Done") {
                                            showingFilterSheet = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            // Capture the current map center into an Identified item.
                            addMarkerDraft = IdentifiedCoordinate(coordinate: region.center)
                        }) {
                            Text("Marker setzen")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground).opacity(0.9))
                            .shadow(radius: 5)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("ResQNet")
            .toolbar {
                // Bluetooth button on the left
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: ContentView()) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .imageScale(.large)
                    }
                }
                // Refresh button on the right
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { refreshLocation() }) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.large)
                    }
                }
            }
            // Present the "add marker" flow: now robust and never nil
            .sheet(item: $addMarkerDraft) { draft in
                AddMarkerView(coordinate: draft.coordinate, markerStore: markerStore) {
                    addMarkerDraft = nil
                }
            }
            // Existing detail sheet
            .sheet(item: $selectedMarker) { marker in
                MarkerDetailView(marker: marker, markerStore: markerStore)
            }
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    private var isAuthorized = false
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.distanceFilter = 10
    }
    
    func setup() {
        checkLocationAuthorization()
    }
    
    private func checkLocationAuthorization() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let status = self.locationManager.authorizationStatus
            switch status {
            case .notDetermined:
                DispatchQueue.main.async {
                    self.locationManager.requestWhenInUseAuthorization()
                }
            case .restricted, .denied:
                print("Location access denied")
            case .authorizedAlways, .authorizedWhenInUse:
                DispatchQueue.main.async {
                    self.startUpdatingLocation()
                }
            @unknown default:
                break
            }
        }
    }
    
    private func startUpdatingLocation() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if self.location == nil || location.horizontalAccuracy < (self.location?.horizontalAccuracy ?? .greatestFiniteMagnitude) {
            DispatchQueue.main.async {
                self.location = location
                print("Updated location: \(location.coordinate) with accuracy: \(location.horizontalAccuracy)m")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .denied { return }
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func refresh() {
        if CLLocationManager.locationServicesEnabled() {
            checkLocationAuthorization()
        }
    }
}

// MARK: - Helpers & Actions
extension MainView {
    private func refreshLocation() {
        if let location = locationManager.location {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }
    
    private func searchMarkersInRegion() {
        if filterByType != nil {
            // If already filtering, turn off the filter
            filterByType = nil
            return
        }
        
        // Show the filter sheet to select marker type
        showingFilterSheet = true
    }
}

#Preview {
    MainView()
}

