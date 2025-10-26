import Foundation
import CoreBluetooth
import Combine

final class BLEPeripheralManager: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    // Public
    @Published var isAdvertising = false
    @Published var isPoweredOn = false
    @Published var log: [String] = []
    @Published var messages: [String] = []   // eingehend vom Central
    @Published var subscriberCount: Int = 0


    // CoreBluetooth
    private var pm: CBPeripheralManager!
    private var txCharacteristic: CBMutableCharacteristic! // notify (Peripheral → Central)
    private var rxCharacteristic: CBMutableCharacteristic! // write / writeNR (Central → Peripheral)

    private var subscribedCentrals: [CBCentral] = []       // aktuell abonnierte Centrals
    private var pendingChunks: [Data] = []                 // wartende Chunks, falls Puffer voll
    

    override init() {
        super.init()
        pm = CBPeripheralManager(delegate: self, queue: .main)
    }

    // MARK: - Lifecycle
    func start() {
        guard isPoweredOn else { return }
        setupServiceIfNeeded()
        let adv: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BLEUUIDs.service],
            CBAdvertisementDataLocalNameKey: "ResQNet Chat"
        ]
        pm.startAdvertising(adv)
        isAdvertising = true
        log.append("Advertising gestartet.")
    }

    func stop() {
        pm.stopAdvertising()
        isAdvertising = false
        log.append("Advertising gestoppt.")
    }

    // MARK: - Messaging (Peripheral → Central über TX notify)
    func send(_ text: String) {
        // 1) Frame mit Zeitstempel + Location bauen
        let frame = ChatFrame.make(text: text, from: LocalID.value)
        guard let data = ChatCodec.encode(frame) else {
            log.append("TX Fehler: Encoding fehlgeschlagen")
            return
        }

        // 2) An abonnierende Centrals senden (Notify über txCharacteristic)
        guard let tx = txCharacteristic else {
            log.append("TX abgebrochen: keine TX-Characteristic")
            return
        }

        // iOS sendet per updateValue – ggf. in kleinen Stücken, falls nötig
        var offset = 0
        let mtu = 180 // konservativer Chunk (CBPeripheralManager hat keine direkte mtu-Eigenschaft)
        while offset < data.count {
            let len = min(mtu, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset+len))
            let ok = pm.updateValue(chunk, for: tx, onSubscribedCentrals: nil)
            if !ok {
                // Sendepuffer voll → minimal verzögert erneut
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    _ = self?.pm.updateValue(chunk, for: tx, onSubscribedCentrals: nil)
                }
            }
            offset += len
        }

        // 3) UI-Chat & Log aktualisieren
        DispatchQueue.main.async {
            self.messages.append("Ich: \(text)")
        }
        log.append("TX: " + ChatFormat.line(from: frame))

    }



    // MARK: - Private
    private func setupServiceIfNeeded() {
        guard txCharacteristic == nil else { return }

        txCharacteristic = CBMutableCharacteristic(
            type: BLEUUIDs.txChar,
            properties: [.notify],
            value: nil,
            permissions: []
        )
        rxCharacteristic = CBMutableCharacteristic(
            type: BLEUUIDs.rxChar,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(type: BLEUUIDs.service, primary: true)
        service.characteristics = [txCharacteristic, rxCharacteristic]
        pm.removeAllServices()
        pm.add(service)
        log.append("Service hinzugefügt.")
    }

    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        isPoweredOn = peripheral.state == .poweredOn
        log.append("PM state: \(peripheral.state.rawValue)")
        if peripheral.state != .poweredOn {
            isAdvertising = false
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error { log.append("Service add error: \(error.localizedDescription)") }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let tx = txCharacteristic, !pendingChunks.isEmpty else { return }
        let mtu = subscribedCentrals.first?.maximumUpdateValueLength ?? 20

        while !pendingChunks.isEmpty {
            let chunk = pendingChunks.removeFirst()
            if chunk.count > mtu {
                let head = chunk.subdata(in: 0..<mtu)
                let tail = chunk.subdata(in: mtu..<chunk.count)
                if !pm.updateValue(head, for: tx, onSubscribedCentrals: nil) {
                    // Nicht bereit → in gleicher Reihenfolge zurücklegen
                    pendingChunks.insert(tail, at: 0)
                    pendingChunks.insert(head, at: 0)
                    return
                }
                pendingChunks.insert(tail, at: 0)
            } else {
                if !pm.updateValue(chunk, for: tx, onSubscribedCentrals: nil) {
                    pendingChunks.insert(chunk, at: 0)
                    return
                }
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
        }
        subscriberCount = subscribedCentrals.count          // ← NEU
        log.append("Central subscribed: \(central.identifier) (MTU \(central.maximumUpdateValueLength))")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
        subscriberCount = subscribedCentrals.count          // ← NEU
        log.append("Central unsubscribed: \(central.identifier)")
    }


    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for r in requests {
            defer { pm.respond(to: r, withResult: .success) } // wir akzeptieren unsere RX-Char
            guard r.characteristic.uuid == BLEUUIDs.rxChar, let value = r.value else { continue }

            if let frame = ChatCodec.decode(value) {
                if frame.from == LocalID.value {
                    log.append("RX self-frame (ignoriert)")
                } else {
                    DispatchQueue.main.async {
                        self.messages.append("Peer: \(frame.text)")
                    }
                    log.append("RX: \(frame.text)")
                }
            } else if let str = String(data: value, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.messages.append("Peer: \(str)")
                }
                log.append("RX text: \(str)")
            } else {
                log.append("RX bytes: \(value as NSData)")
            }
        }
    }
    
    private static func format(frame: ChatFrame) -> String {
        let time = Date(timeIntervalSince1970: frame.ts)
            .formatted(date: .omitted, time: .standard)
        var s = "[\(time)] \(frame.text)"
        if let la = frame.lat, let lo = frame.lon {
            s += "  @\(String(format: "%.5f", la)),\(String(format: "%.5f", lo))"
            if let a = frame.acc { s += " ±\(Int(a))m" }
        }
        return s
    }
}
