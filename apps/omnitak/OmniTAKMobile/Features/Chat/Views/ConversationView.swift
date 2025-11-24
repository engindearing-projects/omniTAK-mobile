//
//  ConversationView.swift
//  OmniTAKTest
//
//  Message thread UI with bubbles, send button, input field
//

import SwiftUI

struct ConversationView: View {
    @ObservedObject var chatManager: ChatManager
    let conversation: Conversation

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0

    var messages: [ChatMessage] {
        chatManager.getMessages(for: conversation.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isFromSelf: message.isFromSelf
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom()
                    // Mark conversation as read
                    chatManager.markConversationAsRead(conversationId: conversation.id)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom()
                }
            }

            // Photo preview when image is selected
            if let image = selectedImage {
                VStack(spacing: 8) {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                            .clipped()

                        Spacer()

                        Button(action: {
                            selectedImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    if isUploading {
                        ProgressView(value: uploadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .background(Color(.systemGray6))
            }

            Divider()

            // Message input with photo button
            HStack(spacing: 8) {
                // Photo attachment button
                Button(action: {
                    showPhotoPicker = true
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .disabled(isUploading)

                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage || isUploading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle(conversation.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(selectedImage: $selectedImage)
        }
    }

    private var canSendMessage: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = selectedImage != nil
        return hasText || hasImage
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let image = selectedImage {
            // Send message with image
            sendMessageWithImage(text: text, image: image)
        } else if !text.isEmpty {
            // Send text-only message
            chatManager.sendMessage(text: text, to: conversation.id)
            messageText = ""
            scrollToBottom()
        }
    }

    private func sendMessageWithImage(text: String, image: UIImage) {
        isUploading = true
        uploadProgress = 0

        // Simulate upload progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if uploadProgress < 0.9 {
                uploadProgress += 0.1
            } else {
                timer.invalidate()
            }
        }

        // Process and send image asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            let messageId = UUID().uuidString

            // Create image attachment
            guard let attachment = PhotoAttachmentService.shared.createImageAttachment(from: image, messageId: messageId) else {
                DispatchQueue.main.async {
                    isUploading = false
                    uploadProgress = 0
                    print("Failed to create image attachment")
                }
                return
            }

            DispatchQueue.main.async {
                uploadProgress = 1.0

                // Send via ChatManager
                chatManager.sendMessageWithImage(
                    text: text,
                    imageAttachment: attachment,
                    to: conversation.id
                )

                // Reset state
                messageText = ""
                selectedImage = nil
                isUploading = false
                uploadProgress = 0
                scrollToBottom()
            }
        }
    }

    private func scrollToBottom() {
        guard let lastMessage = messages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let isFromSelf: Bool
    @State private var showFullScreenImage = false
    @State private var fullImage: UIImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromSelf {
                Spacer()
            }

            VStack(alignment: isFromSelf ? .trailing : .leading, spacing: 4) {
                // Sender name (only for received messages)
                if !isFromSelf {
                    Text(message.senderCallsign)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                }

                // Message bubble with optional image
                HStack(alignment: .bottom, spacing: 4) {
                    VStack(alignment: isFromSelf ? .trailing : .leading, spacing: 8) {
                        // Image attachment
                        if message.hasImage, let attachment = message.imageAttachment {
                            ImageAttachmentView(
                                attachment: attachment,
                                onTap: { image in
                                    fullImage = image
                                    showFullScreenImage = true
                                }
                            )
                        }

                        // Text content
                        if !message.messageText.isEmpty {
                            Text(message.messageText)
                                .font(.body)
                                .foregroundColor(isFromSelf ? .white : .primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromSelf ? Color.blue : Color(.systemGray5))
                    )

                    // Status indicator for sent messages
                    if isFromSelf {
                        statusIcon
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
            }

            if !isFromSelf {
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let image = fullImage {
                FullScreenImageView(image: image)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
        case .sent:
            Image(systemName: "checkmark")
        case .delivered:
            Image(systemName: "checkmark.circle")
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Image Attachment View

struct ImageAttachmentView: View {
    let attachment: ImageAttachment
    let onTap: (UIImage) -> Void
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 300)
                    .cornerRadius(12)
                    .onTapGesture {
                        // Load full image for preview
                        if let localPath = attachment.localPath,
                           let fullImage = PhotoAttachmentService.shared.loadImage(from: localPath) {
                            onTap(fullImage)
                        } else {
                            onTap(image)
                        }
                    }
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 150)
                    .background(Color(.systemGray4))
                    .cornerRadius(12)
            } else {
                // Placeholder for failed load
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Image unavailable")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(width: 200, height: 150)
                .background(Color(.systemGray4))
                .cornerRadius(12)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        // Try to load thumbnail first for performance
        if let thumbnailPath = attachment.thumbnailPath {
            if let cached = ImageCache.shared.get(thumbnailPath) {
                self.image = cached
                self.isLoading = false
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                if let loadedImage = PhotoAttachmentService.shared.loadThumbnail(from: thumbnailPath) {
                    ImageCache.shared.set(loadedImage, for: thumbnailPath)
                    DispatchQueue.main.async {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                    return
                }

                // Fallback to base64 data
                tryLoadFromBase64()
            }
        } else {
            tryLoadFromBase64()
        }
    }

    private func tryLoadFromBase64() {
        if let base64 = attachment.base64Data,
           let data = Data(base64Encoded: base64),
           let loadedImage = UIImage(data: data) {
            DispatchQueue.main.async {
                self.image = loadedImage
                self.isLoading = false
            }
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        let chatManager = ChatManager.shared
        let conversation = Conversation(
            title: "Test User",
            participants: [
                ChatParticipant(id: "test-1", callsign: "Test User")
            ]
        )

        NavigationView {
            ConversationView(chatManager: chatManager, conversation: conversation)
        }
    }
}
