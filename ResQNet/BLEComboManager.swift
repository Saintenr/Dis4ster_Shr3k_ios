import Foundation
import Combine

final class BLEComboManager: ObservableObject {
    @Published var messages: [String] = []
    @Published var log: [String] = []

    let central = BLEManager()
    let host = BLEPeripheralManager()

    private var bag: Set<AnyCancellable> = []
    private var autoConnectInProgress = false
    private var markerStore: MapMarkerStore?

    init() {
        // Nachrichten sofort zusammenführen mit Combine
        central.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.mergeMessages() }
            .store(in: &bag)
        host.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.mergeMessages() }
            .store(in: &bag)

        // Logs miterfassen (nur letzte Zeile)
        central.$log
            .dropFirst()
            .sink { [weak self] l in if let last = l.last { self?.log.append(last) } }
            .store(in: &bag)
        host.$log
            .dropFirst()
            .sink { [weak self] l in if let last = l.last { self?.log.append(last) } }
            .store(in: &bag)

        // Auto-Connect: wenn unser Chat-Service gesichtet wird
        central.$discovered
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                guard self.central.connectedName == nil, !self.autoConnectInProgress else { return }
                if let target = items.first(where: { d in
                    d.advertisedServiceUUIDs.contains(BLEUUIDs.service) ||
                    d.name == "ResQNet Chat"
                }) {
                    self.autoConnectInProgress = true
                    self.log.append("Auto-Connect zu: \(target.name)")
                    self.central.connect(target.peripheral)
                }
            }
            .store(in: &bag)

        // Verbindungsstatus loggen + AutoConnect-Flag zurücksetzen
        central.$connectedName
            .sink { [weak self] name in
                guard let self else { return }
                if let n = name {
                    self.log.append("✅ Verbunden mit \(n)")
                    // Bei neuer Verbindung: Marker synchronisieren
                    self.syncMarkersOnConnection()
                } else {
                    self.log.append("🔴 Verbindung getrennt")
                }
                self.autoConnectInProgress = false
            }
            .store(in: &bag)
    } // ← WICHTIG: init korrekt schließen!

    // MarkerStore setzen für Synchronisation
    func setMarkerStore(_ store: MapMarkerStore) {
        self.markerStore = store
        // Bidirektionale Verbindung aufbauen
        store.setBLEManager(self)
        log.append("🔗 Marker-Store verbunden")
    }

    // Start: Advertising + gezielter Scan
    func start() {
        host.start()
        central.startScan(duration: 15, onlyChatService: true)
        log.append("Dual-Mode gestartet (Advertising + Scan).")

        // Falls noch keine Verbindung: manueller Auto-Connect-Versuch
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            if self.central.connectedName == nil,
               let first = self.central.discovered.first {
                self.log.append("Manueller Auto-Connect-Versuch zu \(first.name)")
                self.central.connect(first.peripheral)
            }
        }
    }

    func stop() {
        host.stop()
        central.stopScan()
        central.disconnect()
        log.append("Dual-Mode gestoppt.")
    }

    /// Sende intelligent: bevorzugt Host→Notify, sonst Central→Write, sonst lokal puffern
    func send(_ text: String) {
        // Prüfen ob es sich um Marker-Daten handelt
        if text.hasPrefix("MARKER:") {
            sendMarkerData(text)
            return
        }
        
        if host.subscriberCount > 0 {
            host.send(text)
            return
        }

        if central.connectedName != nil,
           central.rxCharacteristic != nil,
           central.connectedPeripheral != nil {
            central.send(text)
            return
        }

        messages.append("Ich: \(text)")
        log.append("⚠️ Noch keine aktive Verbindung – Nachricht lokal gespeichert.")
    }
    
    // Marker synchronisieren
    func syncMarker(_ marker: MapMarker) {
        guard let data = try? JSONEncoder().encode(marker),
              let jsonString = String(data: data, encoding: .utf8) else {
            log.append("❌ Fehler beim Kodieren des Markers")
            return
        }
        
        let markerMessage = "MARKER:\(jsonString)"
        
        // Marker nur senden wenn Verbindung besteht
        if host.subscriberCount > 0 || (central.connectedName != nil && central.rxCharacteristic != nil) {
            sendMarkerData(markerMessage)
            log.append("📍 Marker gesendet: \(marker.markerType.label)")
        } else {
            log.append("⚠️ Marker-Sync wartend - keine Verbindung")
        }
    }
    
    private func sendMarkerData(_ markerData: String) {
        if host.subscriberCount > 0 {
            host.send(markerData)
            return
        }

        if central.connectedName != nil,
           central.rxCharacteristic != nil,
           central.connectedPeripheral != nil {
            central.send(markerData)
            return
        }

        log.append("⚠️ Marker-Sync fehlgeschlagen - keine Verbindung")
    }
    
    private func syncMarkersOnConnection() {
        guard let markerStore = markerStore else { return }
        
        // Lokale Marker an verbundenes Gerät senden
        for marker in markerStore.markers {
            syncMarker(marker)
        }
        
        log.append("🔄 \(markerStore.markers.count) Marker synchronisiert")
    }

    private func mergeMessages() {
        var merged: [String] = []
        merged.append(contentsOf: central.messages)
        merged.append(contentsOf: host.messages)
        
        // Eingehende Marker-Daten sofort verarbeiten
        let newMarkerMessages = merged.filter { $0.hasPrefix("Peer: MARKER:") }
        for message in newMarkerMessages {
            processIncomingMarker(message)
        }
        
        // Chat-Nachrichten sofort anzeigen (keine Marker-Daten)
        let chatMessages = merged.filter { !$0.contains("MARKER:") }
        
        // Nur aktualisieren wenn sich etwas geändert hat
        if chatMessages != messages {
            messages = chatMessages
            print("💬 Messages updated: \(chatMessages.count) messages")
        }
    }
    
    private func processIncomingMarker(_ message: String) {
        guard let markerStore = markerStore else { 
            log.append("❌ Kein MarkerStore verfügbar")
            return 
        }
        
        let markerData = message.replacingOccurrences(of: "Peer: MARKER:", with: "")
        
        guard let data = markerData.data(using: .utf8),
              let marker = try? JSONDecoder().decode(MapMarker.self, from: data) else {
            log.append("❌ Fehler beim Dekodieren des empfangenen Markers")
            return
        }
        
        // receiveMarker verwenden um Sync-Loops zu vermeiden
        DispatchQueue.main.async {
            markerStore.receiveMarker(marker)
        }
        
        log.append("� Marker empfangen: \(marker.markerType.label)")
    }
}
