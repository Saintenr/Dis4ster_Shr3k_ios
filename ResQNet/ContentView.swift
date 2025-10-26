import SwiftUI

enum Mode: String, CaseIterable {
    case client = "Client (Central)"
    case host = "Host (Peripheral)"
    case dual = "Dual Mode"
}

struct ContentView: View {
    @State private var mode: Mode = .client

    @StateObject private var central = BLEManager()
    @StateObject private var host = BLEPeripheralManager()
    @StateObject private var combo = BLEComboManager()

    @State private var sendTextCentral = ""
    @State private var sendTextHost = ""
    @State private var showBTHint = false

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {

                Picker("Modus", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .client {
                    StatusCard(isOn: central.isPoweredOn,
                               connectedName: central.connectedName,
                               isScanning: central.isScanning)

                    HStack(spacing: 10) {
                        Button {
                            if !central.isPoweredOn { showBTHint = true }
                            else { central.startScan(duration: 8, onlyChatService: false) }
                        } label: { Label("Scan", systemImage: "dot.radiowaves.left.and.right") }
                        .buttonStyle(.borderedProminent)
                        .disabled(central.isScanning)
                        .alert("Bluetooth nicht verfügbar", isPresented: $showBTHint) {
                            Button("OK", role: .cancel) {}
                        } message: { Text("Bitte auf echter Hardware testen und Bluetooth aktivieren.") }

                        Button {
                            central.stopScan()
                        } label: { Label("Stop", systemImage: "stop.fill") }
                        .buttonStyle(.bordered)
                        .disabled(!central.isScanning)

                        Spacer()

                        if central.connectedName != nil {
                            Button(role: .destructive) { central.disconnect() } label: {
                                Label("Trennen", systemImage: "bolt.slash.fill")
                            }.buttonStyle(.bordered)
                        }
                    }

                    List {
                        Section("Gefundene Geräte") {
                            if central.discovered.isEmpty {
                                if #available(iOS 17.0, *) {
                                    ContentUnavailableView(
                                        "Keine Geräte gefunden",
                                        systemImage: "antenna.radiowaves.left.and.right",
                                        description: Text("Tippe auf „Scan“ oder ziehe zum Aktualisieren.")
                                    )
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 32)).foregroundStyle(.secondary)
                                        Text("Keine Geräte gefunden").bold()
                                        Text("Tippe auf „Scan“ oder ziehe zum Aktualisieren.")
                                            .font(.footnote).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                            } else {
                                ForEach(central.discovered) { item in
                                    DeviceRow(peripheral: item) { central.connect(item.peripheral) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { central.startScan(duration: 8, onlyChatService: false) }

                    ChatView(messages: central.messages,
                             sendText: $sendTextCentral,
                             onSend: { central.send($0) })

                } else if mode == .host {
                    HostStatusCard(isOn: host.isPoweredOn, isAdvertising: host.isAdvertising)

                    HStack(spacing: 10) {
                        Button { host.start() } label: {
                            Label(host.isAdvertising ? "Läuft…" : "Host starten", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(host.isAdvertising || !host.isPoweredOn)

                        Button { host.stop() } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!host.isAdvertising)

                        Spacer()
                    }

                    ChatView(messages: host.messages,
                             sendText: $sendTextHost,
                             onSend: { host.send($0 + "\n") })

                } else if mode == .dual {
                    HostStatusCard(isOn: combo.host.isPoweredOn,
                                   isAdvertising: combo.host.isAdvertising)

                    HStack(spacing: 10) {
                        Button { combo.start() } label: {
                            Label("Dual starten", systemImage: "bolt.badge.automatic")
                        }
                        .buttonStyle(.borderedProminent)

                        Button { combo.stop() } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    ChatView(messages: combo.messages,
                             sendText: $sendTextHost,
                             onSend: { combo.send($0) })
                }

                LogPeek(log: mode == .client ? central.log : (mode == .host ? host.log : combo.log))
            }
            .padding(.horizontal)
            .navigationTitle("ResQNet Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MainView()) {
                        Image(systemName: "map")
                            .imageScale(.large)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        let log = mode == .client ? central.log : (mode == .host ? host.log : combo.log)
                        LogView(log: log, onClear: {
                            switch mode {
                            case .client: central.log.removeAll()
                            case .host:   host.log.removeAll()
                            case .dual:   combo.log.removeAll()
                            }
                        })
                        .navigationTitle("Log")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Log", systemImage: "list.bullet.rectangle.portrait")
                    }
                }
            }
        }
    }
}


private struct HostStatusCard: View {
    let isOn: Bool
    let isAdvertising: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(isOn ? .green : .red).frame(width: 10, height: 10)
                Text(isOn ? "Bluetooth AN" : "Bluetooth AUS")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if isAdvertising { ProgressView().controlSize(.small) }
            }
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(isAdvertising ? .blue : .secondary)
                Text(isAdvertising ? "Hosting aktiv (Advertising)" : "Hosting aus")
                    .foregroundStyle(isAdvertising ? .primary : .secondary)
                Spacer()
            }
            .font(.subheadline)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 1, y: 1)
        )
    }
}

private struct StatusCard: View {
    let isOn: Bool
    let connectedName: String?
    let isScanning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(isOn ? .green : .red).frame(width: 10, height: 10)
                Text(isOn ? "Bluetooth AN" : "Bluetooth AUS")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if isScanning { ProgressView().controlSize(.small) }
            }
            if let name = connectedName {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.fill").foregroundStyle(.blue)
                    Text("Verbunden mit "); Text(name).fontWeight(.semibold)
                    Spacer()
                }.font(.subheadline)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal").foregroundStyle(.secondary)
                    Text("Nicht verbunden").foregroundStyle(.secondary)
                    Spacer()
                }.font(.subheadline)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 1, y: 1)
        )
    }
}

private struct DeviceRow: View {
    let peripheral: DiscoveredPeripheral
    var onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
                    .frame(width: 42, height: 42)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(peripheral.name).font(.headline).lineLimit(1)
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("RSSI \(peripheral.rssi)")
                }
                .font(.caption2).foregroundStyle(.secondary)

                if !peripheral.advertisedServiceUUIDs.isEmpty {
                    Text(peripheral.advertisedServiceUUIDs.map { $0.uuidString }.joined(separator: ", "))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Button("Verbinden", action: onConnect).buttonStyle(.bordered)
        }
        .contentShape(Rectangle())
    }
}

private struct ChatView: View {
    let messages: [String]
    @Binding var sendText: String
    var onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, m in
                        HStack {
                            if m.hasPrefix("Ich:") {
                                Spacer()
                                Text(m.replacingOccurrences(of: "Ich: ", with: ""))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.25)))
                            } else {
                                Text(m.replacingOccurrences(of: "Peer: ", with: ""))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15)))
                                Spacer()
                            }
                        }
                        .font(.callout)
                    }
                }
                .padding(.vertical, 6)
            }
            HStack {
                TextField("Nachricht…", text: $sendText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.send)
                    .onSubmit { if !sendText.isEmpty { onSend(sendText); sendText = "" } }
                Button {
                    if !sendText.isEmpty { onSend(sendText); sendText = "" }
                } label: { Image(systemName: "paperplane.fill") }
                .disabled(sendText.isEmpty)
            }
            .padding(.vertical, 6)
        }
    }
}

private struct LogPeek: View {
    let log: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Log (letzte 5)").font(.footnote).foregroundStyle(.secondary); Spacer() }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(log.suffix(5).enumerated().map({ ($0.offset, $0.element) }), id: \.0) { _, line in
                        Text(line).font(.caption2).monospaced()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 90)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }
}

private struct LogView: View {
    let log: [String]
    var onClear: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Leeren", role: .destructive, action: onClear).buttonStyle(.bordered)
                Spacer()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption).monospaced()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
}
