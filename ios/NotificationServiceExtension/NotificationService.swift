import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var task: URLSessionDataTask?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard
            let content = bestAttemptContent,
            let rawUrl = request.content.userInfo["receipt_url"] as? String,
            let url = URL(string: rawUrl),
            url.scheme == "https"
        else {
            finish()
            return
        }

        var ack = URLRequest(url: url, timeoutInterval: 2.0)
        ack.httpMethod = "POST"
        ack.setValue("application/json", forHTTPHeaderField: "Accept")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 2.0
        task = URLSession(configuration: config).dataTask(with: ack) { [weak self] _, _, _ in
            self?.finish()
        }
        task?.resume()

        // Giữ `content` sống đến khi ACK xong; banner vẫn giữ nguyên
        // tiêu đề, nội dung, âm thanh và interruption level từ backend.
        bestAttemptContent = content
    }

    override func serviceExtensionTimeWillExpire() {
        task?.cancel()
        finish()
    }

    private func finish() {
        guard let handler = contentHandler, let content = bestAttemptContent else { return }
        contentHandler = nil
        handler(content)
    }
}
