import SwiftUI
import MessageUI

struct MailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentation
    let recipient: String
    let subject: String
    let body: String
    let attachments: [URL]
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
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        
        // Add attachments
        for url in attachments {
            if let data = try? Data(contentsOf: url) {
                vc.addAttachmentData(data, mimeType: "audio/wav", fileName: url.lastPathComponent)
            }
        }
        
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<MailView>) {
    }
}
