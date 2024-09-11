//
//  SandboxBrowser.swift
//  SandboxBrowser
//
//  Created by Joe on 2017/8/25.
//  Copyright © 2017年 Joe. All rights reserved.
//

import Foundation
import UIKit

public enum FileType: String {
    case directory = "directory"
    case gif = "gif"
    case jpg = "jpg"
    case png = "png"
    case jpeg = "jpeg"
    case json = "json"
    case pdf = "pdf"
    case plist = "plist"
    case file = "file"
    case sqlite = "sqlite"
    case log = "log"

    var fileName: String {
        switch self {
        case .directory: return "directory"
        case .jpg, .pdf, .gif, .jpeg: return "image"
        case .plist: return "plist"
        case .sqlite: return "sqlite"
        case .log: return "log"
        default: return "file"
        }
    }
}

public enum BackupStatus: String {
    case excluded = "∅"
    case included = "✪"
    case failure = "⧮"
    case unknown = "⍰"
}

public struct FileItem {
    public var name: String
    public var path: String
    public var type: FileType

    public var modificationDate: Date {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            return attr[FileAttributeKey.modificationDate] as? Date ?? Date()
        } catch {
            print(error)
            return Date()
        }
    }

    var image: UIImage {
        let bundle = Bundle(for: FileListViewController.self)
        let path = bundle.path(forResource: "Resources", ofType: "bundle")
        let resBundle = Bundle(path: path!)!

        return UIImage(contentsOfFile: resBundle.path(forResource: type.fileName, ofType: "png")!)!
    }

    var backupStatus: BackupStatus {

        let fileURL = URL(fileURLWithPath: path)
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
            if let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                return isExcludedFromBackup ? .excluded : .included
            }
        } catch {
            return .failure
        }
        return .unknown // Default to true if unable to retrieve the attribute
    }

    func markFileAsExcludedFromBackup(excluded: Bool) -> Bool {
            // try marking file and return false if somethin went wrong
        var fileURL = URL(fileURLWithPath: path)
        do {
            var resourceValues = try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
            resourceValues.isExcludedFromBackup = excluded
            try fileURL.setResourceValues(resourceValues)
        } catch {
            return false
        }
        return true
    }

    var size: Int64? {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = fileAttributes[FileAttributeKey.size] as? NSNumber {
                return fileSize.int64Value
            } else {
                print("Failed to get file size attribute.")
                return nil
            }
        } catch {
            print("Failed to get file attributes for path: \(path). Error: \(error.localizedDescription)")
            return nil
        }
    }

    var sizeString: String {
        if let sizeBytes = size {
            return ByteCountFormatter().string(for: sizeBytes) ?? "error"
        } else {
            return "N/A"
        }
    }
}



public class SandboxBrowser: UINavigationController {

    public enum Options: CaseIterable {
        /// simple file iCloud backup status preview
        /// you able to see if files are set for backup
        /// and able to edit backup status (this to ensure thing is working on _this_ phone/setup)
        case backupDisplay
        /// in case it is enabled possible a bit slowdown
        /// you will see file size next to date
        case fileSizeDisplay
    }

    private(set) public var options: [SandboxBrowser.Options]!

    var fileListVC: FileListViewController?


    open var didSelectFile: ((FileItem, FileListViewController) -> ())? {
        didSet {
            fileListVC?.didSelectFile = didSelectFile
        }
    }

    public convenience init() {
        self.init(initialPath: URL(fileURLWithPath: NSHomeDirectory()), options: [])
    }

    public convenience init(initialPath: URL, options: [Options]) {
        let fileListVC = FileListViewController(
            initialPath: initialPath,
            options: options
        )
        self.init(rootViewController: fileListVC)
        self.fileListVC = fileListVC
        self.options = options
    }
}

public class FileListViewController: UIViewController {

    private struct Misc {
        static let cellIdentifier = "FileCell"
    }

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds)
        view.backgroundColor = .white
        view.delegate = self
        view.dataSource = self
        view.rowHeight = 52
        view.separatorInset = .zero
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(gesture:)))
        longPress.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPress)
        return view
    }()

    private var items: [FileItem] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    public var didSelectFile: ((FileItem, FileListViewController) -> ())?
    private var initialPath: URL?
    private var options: [SandboxBrowser.Options]!

    public convenience init(initialPath: URL, options: [SandboxBrowser.Options]) {
        self.init()

        self.initialPath = initialPath
        self.options = options
        self.title = initialPath.lastPathComponent
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        view.addSubview(tableView)

        loadPath(initialPath!.relativePath)
        navigationItem.rightBarButtonItem = .init(barButtonSystemItem: .stop, target: self, action: #selector(close))

        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "R E L O A D")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        tableView.refreshControl = refreshControl
    }

    @objc private func onLongPress(gesture: UILongPressGestureRecognizer) {

        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        let item = items[indexPath.row]
        if item.type != .directory { shareFile(item.path) }
    }

    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }

    @objc func refresh(_ sender: AnyObject) {
        DispatchQueue.main.async {
            self.loadPath(self.initialPath!.relativePath)
            self.tableView.refreshControl?.endRefreshing()
        }
    }

    private func loadPath(_ path: String = "") {

        guard let paths = try? FileManager.default.contentsOfDirectory(atPath: path) else {
          return
        }

        var filelist: [FileItem] = []
        paths
            .filter { !$0.hasPrefix(".") }
            .forEach { subpath in
            var isDir: ObjCBool = ObjCBool(false)

            let fullpath = path.appending("/" + subpath)

            FileManager.default.fileExists(atPath: fullpath, isDirectory: &isDir)

            var pathExtension = URL(fileURLWithPath: fullpath).pathExtension.lowercased()
            if pathExtension.hasPrefix("sqlite") || pathExtension == "db" { pathExtension = "sqlite" }

            let filetype: FileType = isDir.boolValue ? .directory : FileType(rawValue: pathExtension) ?? .file
            let fileItem = FileItem(name: subpath, path: fullpath, type: filetype)
            filelist.append(fileItem)
        }
        DispatchQueue.main.async {
            self.items = filelist
        }

    }

    private func shareFile(_ filePath: String) {

        let controller = UIActivityViewController(
            activityItems: [NSURL(fileURLWithPath: filePath)],
            applicationActivities: nil)

        controller.excludedActivityTypes = [
            .postToTwitter, .postToFacebook, .postToTencentWeibo, .postToWeibo,
            .postToFlickr, .postToVimeo, .message, .addToReadingList,
            .print, .copyToPasteboard, .assignToContact, .saveToCameraRoll,
        ]

        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.popoverPresentationController?.sourceView = view
            controller.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.size.width * 0.5, y: UIScreen.main.bounds.size.height * 0.5, width: 10, height: 10)
        }
        if (self.presentedViewController == nil) {
            // The "if" test prevents "Warning: Attempt to present UIActivityViewController:...
            // on which is already presenting" warning messages from occurring.
            self.present(controller, animated: true, completion: nil)
        }
    }
}

final class FileCell: UITableViewCell {
    override func layoutSubviews() {
        super.layoutSubviews()

        var imageFrame = imageView!.frame
        imageFrame.size.width = 42
        imageFrame.size.height = 42
        imageView?.frame = imageFrame
        imageView?.center.y = contentView.center.y

        var textLabelFrame = textLabel!.frame
        textLabelFrame.origin.x = imageFrame.maxX + 10
        textLabelFrame.origin.y = textLabelFrame.origin.y - 3
        textLabel?.frame = textLabelFrame

        var detailLabelFrame = detailTextLabel!.frame
        detailLabelFrame.origin.x = textLabelFrame.origin.x
        detailLabelFrame.origin.y = detailLabelFrame.origin.y + 3
        detailTextLabel?.frame = detailLabelFrame
    }
}

extension FileListViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: Misc.cellIdentifier)
        if cell == nil { cell = FileCell(style: .subtitle, reuseIdentifier: Misc.cellIdentifier) }

        let item = items[indexPath.row]
        cell?.textLabel?.text = item.name

        cell?.imageView?.image = item.image
        var detailText = DateFormatter.localizedString(from: item.modificationDate,
                                                       dateStyle: .medium,
                                                       timeStyle: .medium)
        if options.contains(.fileSizeDisplay) {
            detailText += " | " + item.sizeString
        }

        if options.contains(.backupDisplay) {
            detailText = item.backupStatus.rawValue + "\u{2009}" + detailText
        }

        cell?.detailTextLabel?.text = detailText

        if #available(iOS 13.0, *) {
            cell?.detailTextLabel?.textColor = .secondaryLabel
        } else {
            cell?.detailTextLabel?.textColor = .systemGray
        }
        cell?.accessoryType = item.type == .directory ? .disclosureIndicator : .none
        return cell!
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < items.count else { return }

        tableView.deselectRow(at: indexPath, animated: true)

        let item = items[indexPath.row]

        switch item.type {
        case .directory:
            let sandbox = FileListViewController(
                initialPath: URL(fileURLWithPath: item.path),
                options: options
            )
            sandbox.didSelectFile = didSelectFile
            self.navigationController?.pushViewController(sandbox, animated: true)
        default:
            didSelectFile?(item, self)
        }
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard options.contains(.backupDisplay) else { return nil }
        let item = self.items[indexPath.row]
        let itemIsExcluded = item.backupStatus != .included
        let title = itemIsExcluded ? "Add to Backup" : "Exclude from Backup"
        let contextItem = UIContextualAction(style: .normal, title: title) {  (contextualAction, view, completion) in
            if item.markFileAsExcludedFromBackup(excluded: !itemIsExcluded) == false {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
            }
            completion(true)
        }
        let swipeActions = UISwipeActionsConfiguration(actions: [contextItem])

        return swipeActions
    }
}
