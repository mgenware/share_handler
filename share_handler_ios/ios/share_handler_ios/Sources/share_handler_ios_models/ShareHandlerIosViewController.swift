//
//  ShareHandlerIosViewController.swift
//  Pods
//
//  Created by Josh Juncker on 7/7/22.
//

import Contacts
import Intents
import Social
import UIKit
import UniformTypeIdentifiers

open class ShareHandlerIosViewController: UIViewController {
    static var hostAppBundleIdentifier = ""
    static var appGroupId = ""
    let sharedKey = "ShareKey"
    var sharedText: [String] = []
    let imageContentType = UTType.image.identifier
    let movieContentType = UTType.movie.identifier
    let textContentType = UTType.text.identifier
    let urlContentType = UTType.url.identifier
    let fileURLType = UTType.fileURL.identifier
    let dataContentType = UTType.data.identifier
    var sharedAttachments: [SharedAttachment] = []
    private var fileNameCounter: [String: Int] = [:]
    lazy var userDefaults: UserDefaults = {
        return UserDefaults(suiteName: ShareHandlerIosViewController.appGroupId)!
    }()

    public func loadIds() {
        // loading Share extension App Id
        let shareExtensionAppBundleIdentifier = Bundle.main.bundleIdentifier!

        // convert ShareExtension id to host app id
        // By default it is remove last part of id after last point
        // For example: com.test.ShareExtension -> com.test
        let lastIndexOfPoint = shareExtensionAppBundleIdentifier.lastIndex(of: ".")
        ShareHandlerIosViewController.hostAppBundleIdentifier = String(
            shareExtensionAppBundleIdentifier[..<lastIndexOfPoint!])

        // loading custom AppGroupId from Build Settings or use group.<hostAppBundleIdentifier>
        ShareHandlerIosViewController.appGroupId =
            (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String)
            ?? "group.\(ShareHandlerIosViewController.hostAppBundleIdentifier)"
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // load group and app id from build info
        loadIds()
        Task {
            await handleInputItems()
        }
    }

    func handleInputItems() async {
        for case let content as NSExtensionItem in extensionContext?.inputItems ?? [] {
            if let contents = content.attachments {
                for (index, attachment) in (contents).enumerated() {
                    do {
                        if attachment.hasItemConformingToTypeIdentifier(fileURLType) {
                            do {
                                try await handleFiles(
                                    content: content, attachment: attachment, index: index)
                            } catch {
                                guard
                                    let identifier = attachment.registeredTypeIdentifiers.first(
                                        where: {
                                            guard let type = UTType($0) else { return false }
                                            return type.conforms(to: .image)
                                                || type.conforms(to: .movie)
                                        })
                                else { throw error }
                                try await handleMedia(
                                    attachment: attachment, typeIdentifier: identifier)
                            }
                        } else if attachment.hasItemConformingToTypeIdentifier(imageContentType) {
                            let identifier =
                                attachment.registeredTypeIdentifiers.first {
                                    $0 != imageContentType
                                        && UTType($0)?.conforms(to: .image) == true
                                } ?? imageContentType
                            try await handleMedia(
                                attachment: attachment, typeIdentifier: identifier)
                        } else if attachment.hasItemConformingToTypeIdentifier(movieContentType) {
                            let identifier =
                                attachment.registeredTypeIdentifiers.first {
                                    $0 != movieContentType
                                        && UTType($0)?.conforms(to: .movie) == true
                                } ?? movieContentType
                            try await handleMedia(
                                attachment: attachment, typeIdentifier: identifier)
                        } else if attachment.hasItemConformingToTypeIdentifier(urlContentType) {
                            try await handleUrl(
                                content: content, attachment: attachment, index: index)
                        } else if attachment.hasItemConformingToTypeIdentifier(textContentType) {
                            try await handleText(
                                content: content, attachment: attachment, index: index)
                        } else if attachment.hasItemConformingToTypeIdentifier(dataContentType) {
                            let identifier =
                                attachment.registeredTypeIdentifiers.first {
                                    $0 != dataContentType && UTType($0)?.conforms(to: .data) == true
                                } ?? dataContentType
                            try await handleMedia(
                                attachment: attachment, typeIdentifier: identifier)
                        } else {
                            print(
                                "Attachment not handled with registered type identifiers: \(attachment.registeredTypeIdentifiers)"
                            )
                        }
                    } catch {
                        self.dismissWithError()
                        return
                    }

                }
            }
        }
        redirectToHostApp()
    }

    public func getNewFileUrl(fileName: String) throws -> URL {
        let containerUrl = FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: ShareHandlerIosViewController.appGroupId)!
        let sharedFilesUrl = containerUrl.appendingPathComponent(
            "flt_share_handler", isDirectory: true)

        print(
            "[share_handler] Shared files dir URL: \(sharedFilesUrl) | App Group ID: \(ShareHandlerIosViewController.appGroupId)"
        )

        try FileManager.default.createDirectory(
            at: sharedFilesUrl, withIntermediateDirectories: true)
        let originalURL = sharedFilesUrl.appendingPathComponent(fileName)
        var destination = originalURL
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let stem = originalURL.deletingPathExtension().lastPathComponent
            let fileExtension = originalURL.pathExtension
            let name = "\(stem)_\(suffix)" + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
            destination = sharedFilesUrl.appendingPathComponent(name)
            suffix += 1
        }
        return destination
    }

    public func handleText(content: NSExtensionItem, attachment: NSItemProvider, index: Int)
        async throws
    {
        let data = try await attachment.loadItem(forTypeIdentifier: textContentType, options: nil)

        if let item = data as? String {
            sharedText.append(item)
        } else {
            if let d = data as? Data {
                do {
                    let contacts = try CNContactVCardSerialization.contacts(with: d)
                    for contact in contacts {
                        let data = try CNContactVCardSerialization.data(with: [contact])
                        let str = String(data: data, encoding: .utf8)!
                        sharedText.append(str)
                    }
                } catch {
                    dismissWithError()
                }
            } else {
                dismissWithError()
            }
        }
    }

    public func handleUrl(content: NSExtensionItem, attachment: NSItemProvider, index: Int)
        async throws
    {
        let data = try await attachment.loadItem(forTypeIdentifier: urlContentType, options: nil)

        if let item = data as? URL {
            sharedText.append(item.absoluteString)
        } else {
            dismissWithError()
        }

    }

    public func handleMedia(attachment: NSItemProvider, typeIdentifier: String) async throws {
        let suggestedName = attachment.suggestedName
        let fileUrl = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in
            attachment.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) {
                url, _, error in
                do {
                    if let error = error { throw error }
                    guard let url = url else { throw CocoaError(.fileReadUnknown) }
                    let destination = try self.getNewFileUrl(
                        fileName: self.getFileName(
                            from: url, suggestedName: suggestedName,
                            typeIdentifier: typeIdentifier))
                    guard self.copyFile(at: url, to: destination) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        sharedAttachments.append(SharedAttachment(path: fileUrl.absoluteString, type: .file))
    }

    public func handleFiles(content: NSExtensionItem, attachment: NSItemProvider, index: Int)
        async throws
    {
        let data = try await attachment.loadItem(forTypeIdentifier: fileURLType, options: nil)

        if let url = data as? URL {

            // Always copy
            let fileName = getFileName(from: url, suggestedName: attachment.suggestedName)
            let newFileUrl = try getNewFileUrl(fileName: fileName)
            let copied = copyFile(at: url, to: newFileUrl)
            if copied {
                sharedAttachments.append(
                    SharedAttachment.init(path: newFileUrl.absoluteString, type: .file))
            } else {
                throw CocoaError(.fileWriteUnknown)
            }
        } else {
            throw CocoaError(.fileReadUnknown)
        }

    }

    public func dismissWithError() {
        print("[ERROR] Error loading data!")
        let alert = UIAlertController(
            title: "Error", message: "Error loading data", preferredStyle: .alert)

        let action = UIAlertAction(title: "Error", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }

        alert.addAction(action)
        present(alert, animated: true, completion: nil)
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    public func redirectToHostApp() {
        // ids may not loaded yet so we need loadIds here too
        loadIds()
        let url = URL(
            string:
                "ShareMedia-\(ShareHandlerIosViewController.hostAppBundleIdentifier)://\(ShareHandlerIosViewController.hostAppBundleIdentifier)?key=\(sharedKey)"
        )
        var responder = self as UIResponder?
        let selectorOpenURL = sel_registerName("openURL:")

        let intent = self.extensionContext?.intent as? INSendMessageIntent

        let conversationIdentifier = intent?.conversationIdentifier
        let sender = intent?.sender
        let serviceName = intent?.serviceName
        let speakableGroupName = intent?.speakableGroupName

        let sharedMedia = SharedMedia.init(
            attachments: sharedAttachments, conversationIdentifier: conversationIdentifier,
            content: sharedText.joined(separator: "\n"),
            speakableGroupName: speakableGroupName?.spokenPhrase, serviceName: serviceName,
            senderIdentifier: sender?.contactIdentifier ?? sender?.customIdentifier,
            imageFilePath: nil)

        let json = sharedMedia.toJson()

        userDefaults.set(json, forKey: sharedKey)
        userDefaults.synchronize()

        while responder != nil {
            if let application = responder as? UIApplication {
                if #available(iOS 18.0, *) {
                    let _ = application.open(url!, options: [:], completionHandler: nil)
                } else {
                    let _ = application.perform(selectorOpenURL, with: url)
                }
            }
            responder = responder?.next
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    func getFileName(from url: URL, suggestedName: String? = nil, typeIdentifier: String? = nil)
        -> String
    {
        var name = suggestedName.map { ($0 as NSString).lastPathComponent } ?? url.lastPathComponent
        if name.isEmpty {
            name = UUID().uuidString
        }
        if (name as NSString).pathExtension.isEmpty {
            let fileExtension =
                url.pathExtension.isEmpty
                ? typeIdentifier.flatMap { UTType($0)?.preferredFilenameExtension }
                : url.pathExtension
            if let fileExtension = fileExtension {
                name += "." + fileExtension
            }
        }
        if let count = fileNameCounter[name] {
            fileNameCounter[name] = count + 1
            let fileExtension = (name as NSString).pathExtension
            name = "\((name as NSString).deletingPathExtension)_\(count + 1)"
            if !fileExtension.isEmpty {
                name += "." + fileExtension
            }
        } else {
            fileNameCounter[name] = 1
        }
        return name
    }

    func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch (let error) {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
        return true
    }
}
