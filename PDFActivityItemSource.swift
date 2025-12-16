import UIKit
final class PDFActivityItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let subject: String

    init(url: URL, subject: String = "Estimator Pro Document") {
        self.url = url
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        subject
    }
}
