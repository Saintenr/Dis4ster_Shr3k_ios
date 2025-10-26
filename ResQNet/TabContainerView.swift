import SwiftUI

struct TabContainerView: View {
    @StateObject private var comboManager = BLEComboManager()
    @StateObject private var markerStore = MapMarkerStore()
    
    var body: some View {
        TabView {
            ModernMapView(comboManager: comboManager, markerStore: markerStore)
                .tabItem {
                    Label("Karte", systemImage: "map.fill")
                }
            
            ModernChatView(comboManager: comboManager)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
            
            ConnectionView(comboManager: comboManager)
                .tabItem {
                    Label("Verbindung", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .onAppear {
            comboManager.setMarkerStore(markerStore)
            comboManager.start()
        }
    }
}

#Preview {
    TabContainerView()
}