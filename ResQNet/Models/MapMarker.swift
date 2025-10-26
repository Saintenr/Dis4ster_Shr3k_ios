import Foundation
import CoreLocation
import Combine
import SwiftUI

struct MapMarker: Identifiable, Codable {
    let id: UUID
    let coordinate: Coordinate
    let markerType: MarkerType
    let message: String?
    let timestamp: Date
    
    init(id: UUID = UUID(), 
         coordinate: CLLocationCoordinate2D, 
         markerType: MarkerType, 
         message: String? = nil, 
         timestamp: Date = Date()) {
        self.id = id
        self.coordinate = Coordinate(coordinate: coordinate)
        self.markerType = markerType
        self.message = message
        self.timestamp = timestamp
    }
    
    // Helper struct to make CLLocationCoordinate2D Codable
    struct Coordinate: Codable {
        var latitude: Double
        var longitude: Double
        
        init(coordinate: CLLocationCoordinate2D) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        }
        
        var clLocationCoordinate2D: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

enum MarkerType: Int, Codable, CaseIterable, Identifiable {
    case medAidNeed = 1
    
    case medAidOffer = 10
    case water = 11
    case food = 12
    case shelter = 13
    case power = 14
    case comms = 15
    
    case firstAidKit = 16
    case sanitation = 17
    case transport = 18
    case fuel = 19
    case tools = 20
    
    case danger = 30
    case infoPoint = 31
    case checkpoint = 32
    
    var id: Int { self.rawValue }
    
    var label: String {
        switch self {
        case .medAidNeed: return "Medizinische Hilfe benötigt"
        case .medAidOffer: return "Medizinische Hilfe angeboten"
        case .water: return "Wasser verfügbar"
        case .food: return "Essen verfügbar"
        case .shelter: return "Unterkunft verfügbar"
        case .power: return "Strom verfügbar"
        case .comms: return "Kommunikation möglich"
        case .firstAidKit: return "Erste-Hilfe-Set verfügbar"
        case .sanitation: return "Sanitäre Einrichtungen"
        case .transport: return "Transport verfügbar"
        case .fuel: return "Treibstoff verfügbar"
        case .tools: return "Werkzeug verfügbar"
        case .danger: return "Achtung Gefahr"
        case .infoPoint: return "Informationspunkt"
        case .checkpoint: return "Kontrollpunkt"
        }
    }
    
    var systemImage: String {
        switch self {
        case .medAidNeed, .medAidOffer: return "cross.fill"
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .shelter: return "house.fill"
        case .power: return "bolt.fill"
        case .comms: return "antenna.radiowaves.left.and.right"
        case .firstAidKit: return "cross.case.fill"
        case .sanitation: return "shower.fill"
        case .transport: return "car.fill"
        case .fuel: return "fuelpump.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .danger: return "exclamationmark.triangle.fill"
        case .infoPoint: return "info.circle.fill"
        case .checkpoint: return "checkerboard.shield"
        }
    }
    
    var color: Color {
        switch self {
        case .medAidNeed: return .red
        case .danger: return .red
        case .medAidOffer, .firstAidKit: return .green
        case .water, .food, .shelter, .power, .comms, .sanitation, .transport, .fuel, .tools: 
            return .blue
        case .infoPoint, .checkpoint: 
            return .orange
        }
    }
}

// MARK: - Persistence
class MapMarkerStore: ObservableObject {
    @Published var markers: [MapMarker] = []
    private let savePath: URL
    private var bleManager: BLEComboManager?

    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        savePath = documentsDirectory.appendingPathComponent("savedMarkers")
        loadMarkers()
    }
    
    // BLE Manager für automatische Synchronisation setzen
    func setBLEManager(_ manager: BLEComboManager) {
        self.bleManager = manager
    }

    func addMarker(_ marker: MapMarker) {
        // Prüfen ob Marker bereits existiert (Duplikat vermeiden)
        guard !markers.contains(where: { $0.id == marker.id }) else {
            print("Marker mit ID \(marker.id) bereits vorhanden")
            return
        }

        markers.append(marker)
        saveMarkers()

        // Automatisch synchronisieren wenn BLE verfügbar
        bleManager?.syncMarker(marker)
        print("✅ Marker hinzugefügt und synchronisiert: \(marker.markerType.label)")
    }
    
    func removeMarker(_ marker: MapMarker) {
        markers.removeAll { $0.id == marker.id }
        saveMarkers()

        // TODO: Marker-Löschung auch über BLE synchronisieren
        print("🗑️ Marker entfernt: \(marker.markerType.label)")
    }
    
    func updateMarker(_ marker: MapMarker) {
        if let index = markers.firstIndex(where: { $0.id == marker.id }) {
            markers[index] = marker
            saveMarkers()

            // Automatisch synchronisieren wenn BLE verfügbar
            bleManager?.syncMarker(marker)
            print("🔄 Marker aktualisiert und synchronisiert: \(marker.markerType.label)")
        }
    }

    // Marker empfangen (ohne automatische Sync um Loops zu vermeiden)
    func receiveMarker(_ marker: MapMarker) {
        // Prüfen ob Marker bereits existiert (Duplikat vermeiden)
        guard !markers.contains(where: { $0.id == marker.id }) else {
            print("Empfangener Marker bereits vorhanden: \(marker.id)")
            return
        }

        markers.append(marker)
        saveMarkers()
        print("📥 Marker empfangen: \(marker.markerType.label)")
    }
    
    private func loadMarkers() {
        guard let data = try? Data(contentsOf: savePath) else {
            print("Keine gespeicherten Marker gefunden")
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([MapMarker].self, from: data) {
            markers = decoded
            print("📂 \(decoded.count) Marker geladen")
        } else {
            print("❌ Fehler beim Laden der Marker")
        }
    }
    
    private func saveMarkers() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(markers) {
            try? encoded.write(to: savePath, options: [.atomic])
            print("💾 \(markers.count) Marker gespeichert")
        } else {
            print("❌ Fehler beim Speichern der Marker")
        }
    }
}


