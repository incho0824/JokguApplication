import Foundation

class SMSService {
    static let shared = SMSService()
    private init() {}

    func sendSMS(to phoneNumber: String, message: String) {
        guard let accountSID = ProcessInfo.processInfo.environment["TWILIO_ACCOUNT_SID"],
              let authToken = ProcessInfo.processInfo.environment["TWILIO_AUTH_TOKEN"],
              let fromNumber = ProcessInfo.processInfo.environment["TWILIO_FROM_NUMBER"] else {
            print("SMS credentials not set")
            return
        }

        let urlString = "https://api.twilio.com/2010-04-01/Accounts/\(accountSID)/Messages.json"
        guard let url = URL(string: urlString) else {
            print("Invalid Twilio URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = "To=\(phoneNumber)&From=\(fromNumber)&Body=\(message)"
        request.httpBody = body.data(using: .utf8)
        let credentials = "\(accountSID):\(authToken)"
        if let authData = credentials.data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(authData)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request).resume()
    }
}

