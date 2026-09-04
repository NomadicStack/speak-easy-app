import SwiftUI
import MessageUI

struct MailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentation
    let recipient: String
    var ccRecipients: [String]? = nil
    let subject: String
    let body: String
    let attachments: [URL]
    var preferredSenderEmail: String? = nil
    var result: (Result<MFMailComposeResult, Error>) -> Void

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentation: PresentationMode
        let result: (Result<MFMailComposeResult, Error>) -> Void

        init(presentation: Binding<PresentationMode>,
             result: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            _presentation = presentation
            self.result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result(.failure(error!))
                return
            }
            self.result(.success(result))
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation, result: result)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        if let cc = ccRecipients, !cc.isEmpty {
            vc.setCcRecipients(cc)
        }
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)

        if let sender = preferredSenderEmail, !sender.isEmpty {
            vc.setPreferredSendingEmailAddress(sender)
        }

        // Add attachments
        for url in attachments {
            if let data = try? Data(contentsOf: url) {
                let ext = url.pathExtension.lowercased()
                let mimeType: String
                switch ext {
                case "zip":
                    mimeType = "application/zip"
                case "csv":
                    mimeType = "text/csv"
                default:
                    mimeType = "audio/wav"
                }
                vc.addAttachmentData(data, mimeType: mimeType, fileName: url.lastPathComponent)
            }
        }
        
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<MailView>) {
    }
}
