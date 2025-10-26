import SwiftUI

struct ConnectionView: View {
    @ObservedObject var comboManager: BLEComboManager
    @State private var showingAdvancedSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    StatusRow(
                        title: "Bluetooth",
                        isActive: comboManager.host.isPoweredOn,
                        icon: "antenna.radiowaves.left.and.right"
                    )
                    
                    StatusRow(
                        title: "Dual Mode",
                        isActive: comboManager.host.isAdvertising,
                        icon: "bolt.badge.automatic"
                    )
                } header: {
                    Text("Verbindungsstatus")
                }
                
                Section {
                    if !comboManager.host.isAdvertising {
                        Button {
                            comboManager.start()
                        } label: {
                            Label("Dual Mode starten", systemImage: "play.fill")
                        }
                        .disabled(!comboManager.host.isPoweredOn)
                    } else {
                        Button {
                            comboManager.stop()
                        } label: {
                            Label("Dual Mode stoppen", systemImage: "stop.fill")
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("Aktionen")
                }
                
                Section {
                    if comboManager.messages.isEmpty {
                        Label("Keine aktiven Verbindungen", systemImage: "wifi.slash")
                            .foregroundColor(.secondary)
                    } else {
                        let peerCount = Set(comboManager.messages.compactMap { message in
                            message.hasPrefix("Peer:") ? "Peer Device" : nil
                        }).count
                        Label("\(peerCount) Gerät(e) verbunden", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Verbundene Geräte")
                }
                
                if !comboManager.messages.isEmpty {
                    Section {
                        HStack {
                            Label("Nachrichten gesendet", systemImage: "arrow.up.circle")
                            Spacer()
                            Text("\(comboManager.messages.filter { $0.hasPrefix("Ich:") }.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Nachrichten empfangen", systemImage: "arrow.down.circle")
                            Spacer()
                            Text("\(comboManager.messages.filter { $0.hasPrefix("Peer:") }.count)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistiken")
                    }
                }
                
                Section {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Hilfe & Information", systemImage: "questionmark.circle")
                    }
                    
                    Button {
                        showingAdvancedSettings = true
                    } label: {
                        Label("Erweiterte Einstellungen", systemImage: "gear")
                    }
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("Verbindung")
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView(comboManager: comboManager)
        }
    }
}
// MARK: - Status Row
struct StatusRow: View {
    let title: String
    let isActive: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isActive ? .blue : .secondary)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(isActive ? "Aktiv" : "Inaktiv")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Help View
struct HelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ResQNet ist eine Notfall-Kommunikations-App, die Bluetooth Low Energy (BLE) nutzt, um Geräte direkt miteinander zu verbinden.")
                    
                    Text("Features:")
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpFeatureRow(
                            icon: "map.fill",
                            title: "Interaktive Karte",
                            description: "Setzen und teilen Sie Notfall-Marker"
                        )
                        
                        HelpFeatureRow(
                            icon: "message.fill",
                            title: "Direkte Kommunikation",
                            description: "Chatten Sie ohne Internet-Verbindung"
                        )
                        
                        HelpFeatureRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Dual Mode",
                            description: "Automatische Verbindung zwischen Geräten"
                        )
                    }
                }
            } header: {
                Text("Über ResQNet")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Aktivieren Sie Bluetooth auf Ihrem Gerät")
                    Text("2. Starten Sie den Dual Mode in der App")
                    Text("3. Andere ResQNet-Geräte werden automatisch erkannt")
                    Text("4. Marker werden automatisch zwischen Geräten synchronisiert")
                }
            } header: {
                Text("Erste Schritte")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("• Bluetooth muss aktiviert sein")
                    Text("• Geräte müssen sich in Reichweite befinden (ca. 30-100m)")
                    Text("• Die App muss im Vordergrund laufen")
                }
            } header: {
                Text("Technische Anforderungen")
            }
        }
        .navigationTitle("Hilfe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @ObservedObject var comboManager: BLEComboManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearDataAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bluetooth Status")
                        Spacer()
                        Text(comboManager.host.isPoweredOn ? "Verfügbar" : "Nicht verfügbar")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("System Information")
                }
                
                Section {
                    Button {
                        showingClearDataAlert = true
                    } label: {
                        Label("Chat-Verlauf löschen", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Daten verwalten")
                } footer: {
                    Text("Dies löscht nur den lokalen Chat-Verlauf. Marker bleiben erhalten.")
                }
                
                Section {
                    HStack {
                        Text("Debug Log")
                        Spacer()
                        Text("\(comboManager.log.count) Einträge")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Entwickler")
                }
            }
            .navigationTitle("Erweiterte Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Chat-Verlauf löschen", isPresented: $showingClearDataAlert) {
            Button("Löschen", role: .destructive) 
                comboManager.messages.removeAll()
            
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchten Sie den gesamten Chat-Verlauf löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
}

#Preview {
    ConnectionView(comboManager: BLEComboManager())
}