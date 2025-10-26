import SwiftUI

struct ModernChatView: View {
    @ObservedObject var comboManager: BLEComboManager
    @State private var messageText = ""
    @State private var showConnectionDetail = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Header
                connectionHeader
                
                // Messages
                messagesView
                
                // Input
                MessageInputView(
                    messageText: $messageText,
                    isConnected: isConnected,
                    isTextFieldFocused: _isTextFieldFocused,
                    onSend: sendMessage
                )
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Status") {
                        showConnectionDetail = true
                    }
                }
            }
            .sheet(isPresented: $showConnectionDetail) {
                ConnectionDetailView(comboManager: comboManager)
            }
            .onTapGesture {
                // Tastatur schließen beim Tippen außerhalb
                isTextFieldFocused = false
            }
        }
    }
    
    // MARK: - Views and Properties
    private var connectionHeader: some View {
        ConnectionStatusHeader(comboManager: comboManager)
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(comboManager.messages.enumerated()), id: \.offset) { index, message in
                        ChatBubble(message: message)
                            .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: comboManager.messages.count) { _, newCount in
                if newCount > 0 {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var isConnected: Bool {
        comboManager.host.subscriberCount > 0 || comboManager.central.connectedName != nil
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        comboManager.send(text)
        messageText = ""
    }
}

// MARK: - Connection Status Header
struct ConnectionStatusHeader: View {
    @ObservedObject var comboManager: BLEComboManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 4)
                            .scaleEffect(comboManager.host.isAdvertising ? 1.5 : 1.0)
                            .opacity(comboManager.host.isAdvertising ? 0 : 1)
                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: comboManager.host.isAdvertising)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if comboManager.host.isAdvertising {
                        Text("Dual Mode aktiv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if comboManager.host.isAdvertising {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.multicolor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
        }
    }
    
    private var statusColor: Color {
        if comboManager.host.isPoweredOn && comboManager.host.isAdvertising {
            return .green
        } else if comboManager.host.isPoweredOn {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if comboManager.host.isPoweredOn && comboManager.host.isAdvertising {
            return "Verbunden und bereit"
        } else if comboManager.host.isPoweredOn {
            return "Bluetooth aktiviert"
        } else {
            return "Bluetooth deaktiviert"
        }
    }
}

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: String
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(cleanMessage)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isFromCurrentUser ? .blue : .secondary.opacity(0.2))
                    )
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                
                Text(Date().formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private var isFromCurrentUser: Bool {
        message.hasPrefix("Ich: ")
    }
    
    private var cleanMessage: String {
        if message.hasPrefix("Ich: ") {
            return message.replacingOccurrences(of: "Ich: ", with: "")
        } else {
            return message.replacingOccurrences(of: "Peer: ", with: "")
        }
    }
}

// MARK: - Message Input
struct MessageInputView: View {
    @Binding var messageText: String
    let isConnected: Bool
    @FocusState var isTextFieldFocused: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Input
                TextField("Nachricht schreiben...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.secondary.opacity(0.1))
                    )
                    .disabled(!isConnected)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        onSend()
                        isTextFieldFocused = false
                    }
                
                // Send Button
                Button(action: {
                    onSend()
                    isTextFieldFocused = false
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .secondary)
                }
                .disabled(!canSend)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
    
    private var canSend: Bool {
        isConnected && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Connection Detail View
struct ConnectionDetailView: View {
    @ObservedObject var comboManager: BLEComboManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 16) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Dual Mode")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(comboManager.host.isAdvertising ? "Aktiv und bereit für Verbindungen" : "Inaktiv")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                
                // Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verbindungsstatistiken")
                        .font(.headline)
                    
                    HStack {
                        Text("Verbundene Geräte:")
                        Spacer()
                        Text("\(comboManager.host.subscriberCount)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Nachrichten gesendet:")
                        Spacer()
                        Text("\(comboManager.messages.filter { $0.hasPrefix("Ich: ") }.count)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Nachrichten empfangen:")
                        Spacer()
                        Text("\(comboManager.messages.filter { $0.hasPrefix("Peer: ") }.count)")
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Verbindungsdetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ModernChatView(comboManager: BLEComboManager())
}