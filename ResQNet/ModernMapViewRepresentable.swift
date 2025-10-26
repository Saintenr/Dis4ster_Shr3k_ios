import SwiftUI
import MapKit

struct ModernMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let markers: [MapMarker]
    @Binding var selectedMarker: MapMarker?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        mapView.showsScale = true
        mapView.showsCompass = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if significantly different
        let currentRegion = mapView.region
        let threshold = 0.001
        
        if abs(currentRegion.center.latitude - region.center.latitude) > threshold ||
           abs(currentRegion.center.longitude - region.center.longitude) > threshold ||
           abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) > threshold {
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotations
        updateAnnotations(mapView: mapView)
    }
    
    private func updateAnnotations(mapView: MKMapView) {
        // Remove all existing annotations except user location
        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingAnnotations)
        
        // Add new annotations
        let newAnnotations = markers.map { marker -> MarkerAnnotation in
            let annotation = MarkerAnnotation()
            annotation.coordinate = marker.coordinate.clLocationCoordinate2D
            annotation.title = marker.markerType.label
            annotation.subtitle = marker.message
            annotation.marker = marker
            return annotation
        }
        
        mapView.addAnnotations(newAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ModernMapViewRepresentable
        
        init(_ parent: ModernMapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let markerAnnotation = annotation as? MarkerAnnotation else { return nil }
            
            let identifier = "customMarker"
            var annotationView: MKAnnotationView
            
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                dequeuedView.annotation = annotation
                annotationView = dequeuedView
            } else {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = true
                
                // Custom callout accessory
                let detailButton = UIButton(type: .detailDisclosure)
                detailButton.tintColor = UIColor.systemBlue
                annotationView.rightCalloutAccessoryView = detailButton
            }
            
            // Create custom marker image
            let markerType = markerAnnotation.marker.markerType
            let markerImage = createMarkerImage(for: markerType)
            annotationView.image = markerImage
            
            // Set anchor point
            annotationView.centerOffset = CGPoint(x: 0, y: -markerImage.size.height / 2)
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let markerAnnotation = view.annotation as? MarkerAnnotation else { return }
            parent.selectedMarker = markerAnnotation.marker
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        private func createMarkerImage(for markerType: MarkerType) -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                // Background circle
                let rect = CGRect(origin: .zero, size: size)
                
                // Convert SwiftUI Color to UIColor
                let color: UIColor
                switch markerType.color {
                case .red:
                    color = UIColor.systemRed
                case .green:
                    color = UIColor.systemGreen
                case .blue:
                    color = UIColor.systemBlue
                case .orange:
                    color = UIColor.systemOrange
                default:
                    color = UIColor.systemBlue
                }
                
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.fillEllipse(in: rect)
                
                // White border
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(3)
                context.cgContext.strokeEllipse(in: rect)
                
                // Icon
                let iconSize: CGFloat = 20
                let iconRect = CGRect(
                    x: (size.width - iconSize) / 2,
                    y: (size.height - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                
                if let iconImage = UIImage(systemName: markerType.systemImage)?.withConfiguration(
                    UIImage.SymbolConfiguration(pointSize: iconSize * 0.8, weight: .bold)
                ) {
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    iconImage.draw(in: iconRect, blendMode: .normal, alpha: 1.0)
                }
            }
        }
    }
}

// Custom annotation class to hold marker data
class MarkerAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var title: String?
    var subtitle: String?
    var marker: MapMarker!
}