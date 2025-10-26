import Foundation
import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Chat-UUIDs (eigener Service)
enum BLEUUIDs {
    static let service = CBUUID(string: "0000C0DE-0000-1000-8000-00805F9B34FB")
    // Peripheral → Central (Notifications)
    static let txChar  = CBUUID(string: "0000C0D1-0000-1000-8000-00805F9B34FB")
    // Central → Peripheral (Write/WriteNR)
    static let rxChar  = CBUUID(string: "0000C0D2-0000-1000-8000-00805F9B34FB")
}

// MARK: - Model für gefundene Geräte
struct DiscoveredPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var advertisedServiceUUIDs: [CBUUID]

    init(peripheral: CBPeripheral, rssi: Int, adv: [String: Any]) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.rssi = rssi
        self.name = peripheral.name
            ?? (adv[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unbekannt"
        self.advertisedServiceUUIDs = (adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
    }

    static func ==(lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
}

final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Public State
    @Published var isPoweredOn = false
    @Published var isScanning = false
    @Published var discovered: [DiscoveredPeripheral] = []
    @Published var connectedName: String?
    @Published var log: [String] = []
    @Published var messages: [String] = []        // ← Chat-Verlauf (Central-Seite)

    // CoreBluetooth
    // CoreBluetooth
    private var central: CBCentralManager!
    var connectedPeripheral: CBPeripheral?          // ← nicht mehr private
    var rxCharacteristic: CBCharacteristic?         // ← nicht mehr private
    var txCharacteristic: CBCharacteristic?         // ← kann private bleiben, wenn Combo sie nicht liest
    private var scanStopTask: DispatchWorkItem?

    

    // Scan-Filter: auf Chat-Service einschränken
    private let targetServiceUUID: CBUUID? = nil
    private let targetCharUUID: CBUUID? = nil // nicht erforderlich, wir suchen rx/tx gezielt

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    // MARK: - Public API
    func startScan(duration: TimeInterval = 8, onlyChatService: Bool = false) {
        guard isPoweredOn else { return }
        stopScan() // entprellen
        log.append("Starte Scan…")
        discovered.removeAll()
        let services: [CBUUID]? = onlyChatService ? [BLEUUIDs.service] :
            (targetServiceUUID == nil ? nil : [targetServiceUUID!])

        central.scanForPeripherals(
            withServices: services,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        isScanning = true

        // Auto-Stop
        let task = DispatchWorkItem { [weak self] in self?.stopScan() }
        scanStopTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    func stopScan() {
        scanStopTask?.cancel(); scanStopTask = nil
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        log.append("Scan gestoppt.")
    }

    func connect(_ peripheral: CBPeripheral) {
        stopScan()
        if let p = connectedPeripheral { central.cancelPeripheralConnection(p) }
        log.append("Verbinde mit \(peripheral.name ?? "Unbekannt")…")
        central.connect(peripheral, options: nil)

        // Connect-Timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            if self.connectedPeripheral?.identifier != peripheral.identifier {
                self.log.append("Verbindungstimeout – breche ab.")
                self.central.cancelPeripheralConnection(peripheral)
            }
        }
    }

    func disconnect() {
        if let p = connectedPeripheral { central.cancelPeripheralConnection(p) }
    }

    /// Komfort: Text senden (als JSON-Frame)
    func send(_ text: String, appendNewline: Bool = false) {
        let frame = ChatFrame.make(text: text, from: LocalID.value)
        guard let data = ChatCodec.encode(frame) else { return }
        writeSample(data)
    }

    func writeSample(_ data: Data) {
        guard let p = connectedPeripheral, let ch = rxCharacteristic else {
            log.append("Write abgebrochen: keine RX-Characteristic oder kein Peripheral")
            return
        }
        let type: CBCharacteristicWriteType = ch.properties.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(data, for: ch, type: type)

        if let f = ChatCodec.decode(data) {
            DispatchQueue.main.async {
                self.messages.append("Ich: \(f.text)")
            }
            log.append("TX: " + ChatFormat.line(from: f)) // Formatter wiederverwenden
        } else if let s = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.messages.append("Ich: \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            log.append("TX: \(s)")
        }
    }




    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isPoweredOn = (central.state == .poweredOn)
        log.append("Central state: \(central.state.rawValue)")
        // kein auto start/stop hier
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        var candidate = DiscoveredPeripheral(peripheral: peripheral,
                                             rssi: RSSI.intValue,
                                             adv: advertisementData)

        if let idx = discovered.firstIndex(where: { $0.id == candidate.id }) {
            discovered[idx].rssi = candidate.rssi
            discovered[idx].name = candidate.name
            discovered[idx].advertisedServiceUUIDs = candidate.advertisedServiceUUIDs
            candidate = discovered[idx]
        } else {
            discovered.append(candidate)
        }

        discovered.sort { $0.rssi > $1.rssi }

        var line = "Gefunden: \(candidate.name) | RSSI \(candidate.rssi)"
        if !candidate.advertisedServiceUUIDs.isEmpty {
            let uuids = candidate.advertisedServiceUUIDs.map { $0.uuidString }.joined(separator: ",")
            line += " | AdvServices:[\(uuids)]"
        }
        log.append(line)
        capLog()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedName = peripheral.name
        rxCharacteristic = nil
        txCharacteristic = nil
        log.append("Verbunden mit \(peripheral.name ?? "Unbekannt")")
        peripheral.delegate = self
        // Optional: nur unseren Service durchsuchen, ist schneller
        peripheral.discoverServices([BLEUUIDs.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log.append("Verbindung fehlgeschlagen: \(error?.localizedDescription ?? "-")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log.append("Getrennt: \(error?.localizedDescription ?? "OK")")
        connectedPeripheral = nil
        connectedName = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }

    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { log.append("Update Fehler: \(error.localizedDescription)"); capLog(); return }
        let value = characteristic.value ?? Data()
        if let frame = ChatCodec.decode(value) {
            if frame.from == LocalID.value {
                // vom lokalen Sender gespiegelt – ignorieren
                log.append("RX self-frame (ignoriert)")
            } else {
                DispatchQueue.main.async {
                    self.messages.append("Peer: \(frame.text)")
                }
                log.append("RX: \(frame.text)")
            }
        } else if let str = String(data: value, encoding: .utf8) {
            let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.messages.append("Peer: \(clean)")
            }
            log.append("RX text: \(clean)")
        } else {
            log.append("RX bytes: \(value as NSData)")
        }
        capLog()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log.append("Services Fehler: \(error.localizedDescription)"); capLog(); return
        }
        guard let services = peripheral.services, !services.isEmpty else {
            log.append("Keine Services gefunden"); capLog(); return
        }
        for s in services {
            log.append("Service: \(s.uuid)")
            // Alle Characteristics dieses Services suchen
            peripheral.discoverCharacteristics(nil, for: s)
        }
        capLog()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { log.append("Chars Fehler: \(error.localizedDescription)"); return }
        guard let chars = service.characteristics else { return }

        var foundTX: CBCharacteristic?
        var foundRX: CBCharacteristic?

        for c in chars {
            log.append("• Char \(c.uuid) props: \(c.properties.bleDescription)")
            if c.uuid == BLEUUIDs.txChar { foundTX = c }
            if c.uuid == BLEUUIDs.rxChar { foundRX = c }
        }

        // gezielte Zuweisung
        if let rx = foundRX { rxCharacteristic = rx }
        if let tx = foundTX {
            txCharacteristic = tx
            if tx.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: tx)
                log.append("TX notify abonniert.")
            }
        }

        // Fallbacks
        if rxCharacteristic == nil,
           let firstWritable = chars.first(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }) {
            rxCharacteristic = firstWritable
            log.append("→ Fallback RX: \(firstWritable.uuid)")
        }

        if txCharacteristic == nil,
           let firstNotify = chars.first(where: { $0.properties.contains(.notify) }) {
            txCharacteristic = firstNotify
            peripheral.setNotifyValue(true, for: firstNotify)
            log.append("→ Fallback TX: \(firstNotify.uuid) (notify aktiviert)")
        }

        capLog()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { log.append("Write Fehler: \(error.localizedDescription)"); capLog(); return }
        log.append("Write bestätigt für \(characteristic.uuid)")
        capLog()
    }

    // MARK: - Helper
    private func capLog(max: Int = 500) {
        if log.count > max { log.removeFirst(log.count - max) }
    }
    } // ← Ende der Klasse BLEManager

    // MARK: - Hilfs-Extension
    extension CBCharacteristicProperties {
        var bleDescription: String {
            var p: [String] = []
            if contains(.read) { p.append("read") }
            if contains(.write) { p.append("write") }
            if contains(.writeWithoutResponse) { p.append("writeNR") }
            if contains(.notify) { p.append("notify") }
            if contains(.indicate) { p.append("indicate") }
            return p.joined(separator: "|")
        }
    }
