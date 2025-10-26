import SwiftUI

struct TabContainerView: View {
    @StateObject private var comboManager = BLEComboManager()
    @StateObject private var markerStore = MapMarkerStore()
    
    var body: some View {
        TabView {
            // Karten-Tab (Hauptscreen)
            ModernMapView(comboManager: comboManager, markerStore: markerStore)
                .tabItem {
                    Label("Karte", systemImage: "map.fill")
                }
            
            // Chat-Tab
            ModernChatView(comboManager: comboManager)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
            
            // Einstellungen/Verbindungen-Tab
            ConnectionView(comboManager: comboManager)
                .tabItem {
                    Label("Verbindung", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .onAppear {
            // MarkerStore mit BLEComboManager verknüpfen für Synchronisation
            comboManager.setMarkerStore(markerStore)
            
            // Automatisch Dual Mode starten beim App-Start
            comboManager.start()
        }
    }
}

#Preview {
    TabContainerView()
}