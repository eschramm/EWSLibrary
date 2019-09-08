//
//  TagCloudVC.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 8/19/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit

#warning("TODO: put searchbar into tableview header")

public protocol Tag {
    var title: String { get }
}

public protocol TagCloudController {
    var cloudID: String { get }
}

public enum TagContext {
    case item
    case all
}

public protocol TagCloudDelegate : class {
    func tagCount(cloudID: String, context: TagContext) -> Int
    func tag(cloudID: String, context: TagContext, for index: Int) -> Tag
    func shouldCreateTag(with title: String) -> Bool
    func indexForCreatedTag(with title: String) -> Int
    func presentTagAddingViewController(tagAddingViewController: UIViewController)
    func dismissTagAddingViewController()
    func removeTag(at index: Int)
    func didAddTag(from index: Int) -> Bool
}

public class TagCloudCell : UITableViewCell, TagCloudController {
    
    // https://stackoverflow.com/questions/55061353/non-scrolling-uicollectionview-inside-uitableviewcell-dynamic-height
    
    public var tagColor = UIColor.green
    public var tagTitleColor = UIColor.black
    public var tagTitleFont = UIFont.systemFont(ofSize: 14)
    public var verticalPadding: CGFloat = 10
    public var horizontalPadding: CGFloat = 10
    
    weak var tagCloudDelegate: TagCloudDelegate?
    public let cloudID: String
    let cellContext: TagContext
    let updateItemTagCellHandler: ((Int) -> ())?
    
    var tagCloudDataSource: TagCloudDataSource!
    
    var collectionView: UICollectionView!
    
    public init(cloudID: String, tagCloudDelegate: TagCloudDelegate, reuseIdentifier: String) {
        self.cloudID = cloudID
        self.tagCloudDelegate = tagCloudDelegate
        self.cellContext = .item
        self.updateItemTagCellHandler = nil
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildDataSource()
        buildCell()
        if #available(iOS 13.0, *), let tagCloudDiffDataSource = tagCloudDataSource as? TagCloudDiffDataSource {
            tagCloudDiffDataSource.injectCollectionView(collectionView: collectionView)
        }
        isAccessibilityElement = false
    }
    
    init(allCell cloudID: String, tagCloudDelegate: TagCloudDelegate, reuseIdentifier: String, updateItemTagCellHandler: @escaping (Int) -> ()) {
        self.cloudID = cloudID
        self.tagCloudDelegate = tagCloudDelegate
        self.cellContext = .all
        self.updateItemTagCellHandler = updateItemTagCellHandler
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildDataSource()
        buildCell()
        if #available(iOS 13.0, *), let tagCloudDiffDataSource = tagCloudDataSource as? TagCloudDiffDataSource {
            tagCloudDiffDataSource.injectCollectionView(collectionView: collectionView)
        }
        isAccessibilityElement = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: 50, height: 55)
        flowLayout.sectionInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flowLayout.headerReferenceSize = CGSize.zero
        flowLayout.footerReferenceSize = CGSize.zero
        collectionView = UICollectionView(frame: contentView.frame, collectionViewLayout: flowLayout)
        contentView.addSubview(collectionView)
        accessibilityElements = [collectionView!]  // enables accessibility for collection view elements (and UI testing)
        collectionView.delegate = self
        if #available(iOS 13.0, *) {
            // nothing
        } else {
            collectionView.dataSource = tagCloudDataSource
        }
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.register(TagCollectionViewCell.self, forCellWithReuseIdentifier: "TagCloudCell")
        contentView.backgroundColor = .orange
        
        var constraints = [
            collectionView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ]
        
        switch cellContext {
        case .item:
            let addButton = UIButton(type: .contactAdd)
            addButton.translatesAutoresizingMaskIntoConstraints = false
            addButton.addTarget(self, action: #selector(addTag), for: .touchUpInside)
            contentView.addSubview(addButton)
            
            constraints.append(contentsOf: [
                addButton.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                addButton.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -8)
            ])
        case .all:
            break
        }
        NSLayoutConstraint.activate(constraints)
        
        NotificationCenter.default.addObserver(forName: .TagTextFieldChanged, object: nil, queue: .main) { [weak self] (_) in
            self?.collectionView.reloadData()
        }
    }
    
    func buildDataSource() {
        if #available(iOS 13.0, *) {
            self.tagCloudDataSource = TagCloudDiffDataSource(tagCloudDelegate: tagCloudDelegate!, tagCloudID: cloudID, context: cellContext, resizeCellHandler: {
                // HACK: this allows for updating cell sizing inside tableview
                if let tableView = self.superview as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            })
        } else {
            self.tagCloudDataSource = TagCloudTraditionalDataSource(tagCloudDelegate: tagCloudDelegate!, tagCloudID: cloudID, context: cellContext, resizeCellHandler: {
                // HACK: this allows for updating cell sizing inside tableview
                if let tableView = self.superview as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            })
        }
    }
    
    @objc func addTag() {
        guard let tagCloudDelegate = tagCloudDelegate else { return }
        let updateItemTagCellHandler: (Int) -> () = { [weak self] index in
            let allowAdd = tagCloudDelegate.didAddTag(from: index)
            if allowAdd {
                if #available(iOS 13.0, *), let tagCloudDiffDataSource = self?.tagCloudDataSource as? TagCloudDiffDataSource {
                    tagCloudDiffDataSource.rebuildCacheAndUpdateSnapshot()
                } else {
                    self?.tagCloudDataSource.updateCache()
                    // assumes add to end, but check if already handled
                    if self?.collectionView.numberOfItems(inSection: 0) ?? 0 < tagCloudDelegate.tagCount(cloudID: self?.cloudID ?? "", context: .item) {
                        self?.collectionView.insertItems(at: [IndexPath(row: tagCloudDelegate.tagCount(cloudID: self?.cloudID ?? "", context: .item) - 1, section: 0)])
                    }
                    //self?.collectionView.reloadData()
                }
                
                // HACK: this allows for updating cell sizing inside tableview
                
                if let tableView = self?.superview as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
            tagCloudDelegate.dismissTagAddingViewController()
        }
        let tagAddingTVC = TagAddingTVC(tagCloudDelegate: tagCloudDelegate, cloudID: cloudID, updateItemTagCellHandler: updateItemTagCellHandler)
        let navController = UINavigationController(rootViewController: tagAddingTVC)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelAdd))
        tagAddingTVC.navigationItem.rightBarButtonItem = cancelButton
        tagCloudDelegate.presentTagAddingViewController(tagAddingViewController: navController)
    }
    
    @objc func cancelAdd() {
        tagCloudDelegate?.dismissTagAddingViewController()
    }
    
    override public func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        self.layoutIfNeeded()
        let contentSize = self.collectionView.collectionViewLayout.collectionViewContentSize
        let calculatedHeight = contentSize.height + 20
        let minHeight: CGFloat = 58
        return CGSize(width: contentSize.width, height: calculatedHeight > minHeight ? calculatedHeight : minHeight) // 20 is the margin of the collectinview with top and bottom
    }
}

extension TagCloudCell : UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    // MARK: - UICollectionViewDataSource
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let tagCloudDelegate = tagCloudDelegate, let tagCloudDataSource = tagCloudDataSource else { return .zero }
        //let originalIndex = tagCloudDataSource.originalIndex(for: indexPath.row)
        let title = tagCloudDataSource.filteredTagPointers[indexPath.row].title
        //let title = tagCloudDelegate.tag(cloudID: cloudID, context: cellContext, for: originalIndex).title as NSString
        let titleSize = title.size(withAttributes: [.font : tagTitleFont])
        return CGSize(width: titleSize.width + horizontalPadding, height: titleSize.height + verticalPadding)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch cellContext {
        case .all:
            _ = updateItemTagCellHandler?(tagCloudDataSource.originalIndex(for: indexPath.row))
        case .item:
            tagCloudDelegate?.removeTag(at: indexPath.row)
            if #available(iOS 13.0, *), let tagCloudDiffDataSource = tagCloudDataSource as? TagCloudDiffDataSource {
                tagCloudDiffDataSource.rebuildCacheAndUpdateSnapshot()
            } else {
                tagCloudDataSource.updateCache()
                collectionView.deleteItems(at: [indexPath])
            }
            
            // HACK: this allows for updating cell sizing inside tableview
            
            if let tableView = self.superview as? UITableView {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }
}

class TagCollectionViewCell : UICollectionViewCell {
    
    let tagColor = UIColor.green
    let tagTitleColor = UIColor.black
    let tagTitleFont = UIFont.systemFont(ofSize: 14)
    let verticalPadding: CGFloat = 10
    let horizontalPadding: CGFloat = 10
    
    let tagLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        tagLabel.backgroundColor = tagColor
        tagLabel.layer.cornerRadius = 5
        tagLabel.clipsToBounds = true
        tagLabel.textAlignment = .center
        tagLabel.font = tagTitleFont
        tagLabel.textColor = tagTitleColor
        
        contentView.addSubview(tagLabel)
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        let viewsDict = ["tagLabel" : tagLabel]
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[tagLabel]|", options: .alignmentMask, metrics: nil, views: viewsDict)
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|[tagLabel]|", options: .alignmentMask, metrics: nil, views: viewsDict))
        
        NSLayoutConstraint.activate(constraints)
    }
}

class TagAddingTVC : UITableViewController {
    
    let allTagsCell: TagCloudCell
    weak var tagCloudDelegate: TagCloudDelegate?
    let updateItemTagCellHandler: (Int) -> ()
    
    init(tagCloudDelegate: TagCloudDelegate, cloudID: String, updateItemTagCellHandler: @escaping (Int) -> ()) {
        self.allTagsCell = TagCloudCell(allCell: cloudID, tagCloudDelegate: tagCloudDelegate, reuseIdentifier: "ExistingTagsCell", updateItemTagCellHandler: updateItemTagCellHandler)
        self.tagCloudDelegate = tagCloudDelegate
        self.updateItemTagCellHandler = updateItemTagCellHandler
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableView.contentOffset = CGPoint(x: 0, y: -15)
        super.viewDidAppear(animated)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            var cell = tableView.dequeueReusableCell(withIdentifier: "AddCell")
            if cell == nil {
                let searchAddCell = AddCell(reuseIdentifier: "AddCell") { newTagTitle in
                    if let delegate = self.tagCloudDelegate {
                        if delegate.shouldCreateTag(with: newTagTitle) {
                            let createdIndex = delegate.indexForCreatedTag(with: newTagTitle)
                            self.updateItemTagCellHandler(createdIndex)
                        }
                    }
                }
                searchAddCell.searchBar.delegate = allTagsCell.tagCloudDataSource
                cell = searchAddCell
            }
            return cell!
        case 1:
            var cell = tableView.dequeueReusableCell(withIdentifier: "ExistingTagsCell")
            if cell == nil {
                cell = allTagsCell
            }
            return cell!
        default:
            fatalError("Should not ever reach")
        }
    }
}

class AddCell : UITableViewCell {
    
    let searchBar = UISearchBar() // UITextField()
    
    let addTagHandler: (String) -> ()
    
    init(reuseIdentifier: String, addTagHandler: @escaping (String) -> ()) {
        self.addTagHandler = addTagHandler
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchBar)
        
        let addButton = UIButton(type: .system)
        addButton.setTitle("Add", for: .normal)
        addButton.isHidden = true
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addTag), for: .touchUpInside)
        
        searchBar.inputAccessoryView = addButton
        
        NotificationCenter.default.addObserver(forName: .TagTextFieldChanged, object: searchBar, queue: .main) { [weak self] (notification) in
            if let userInfo = notification.userInfo, let isUnique = userInfo[TagCloudTraditionalDataSource.TagFieldTextIsUnique] as? Bool {
                if isUnique, let searchText = self?.searchBar.text, !searchText.isEmpty {
                    addButton.setTitle("Add \"\(searchText)\"", for: .normal)
                    addButton.isHidden = false
                } else {
                    addButton.isHidden = true
                }
            }
        }
        
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.safeAreaLayoutGuide.leadingAnchor, multiplier: 1),
            searchBar.trailingAnchor.constraint(equalToSystemSpacingAfter: contentView.safeAreaLayoutGuide.trailingAnchor, multiplier: -1),
            searchBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            searchBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    @objc func addTag() {
        guard let addText = searchBar.text, !addText.isEmpty else { return }
        addTagHandler(addText)
    }
}

extension Notification.Name {
    static let TagTextFieldChanged = Notification.Name(rawValue: "TagTextFieldChanged")
}

struct TagPointer {
    let title: String
    let originalIndex: Int
}

enum Section {
    case main
}

protocol TagCloudDataSource: UICollectionViewDataSource, UISearchBarDelegate {
    
    var tagCloudDelegate: TagCloudDelegate? { get }
    var tagCloudID: String { get }
    var context: TagContext { get }
    var lastSearchString: String { get set }
    var resizeCellHandler: () -> () { get }
    
    var allTagPointers: [TagPointer] { get set }
    var filteredTagPointers: [TagPointer] { get set }
    
    func updateCache()
    func updatedCache() -> [TagPointer]
    func originalIndex(for filteredIndex: Int) -> Int
    
    func internalCollectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    func internalCollectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    
    func internalSearchBar(_ searchBar: UISearchBar, textDidChange searchText: String, dataModelCommit: (()->())?)
}

extension TagCloudDataSource {
    
    func updatedCache() -> [TagPointer] {
        guard let tagCloudDelegate = tagCloudDelegate else { return [] }
        var allTagPointers = [TagPointer]()
        for originalIndex in 0..<tagCloudDelegate.tagCount(cloudID: tagCloudID, context: context) {
            allTagPointers.append(TagPointer(title: tagCloudDelegate.tag(cloudID: tagCloudID, context: context, for: originalIndex).title, originalIndex: originalIndex))
        }
        return allTagPointers
    }
    
    func originalIndex(for filteredIndex: Int) -> Int {
        return filteredTagPointers[filteredIndex].originalIndex
    }
    
    func internalCollectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredTagPointers.count
    }
    
    func internalCollectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCloudCell", for: indexPath) as? TagCollectionViewCell else {
            fatalError("Could not return a TagCollectionViewCell")
        }
        let tagPointer = filteredTagPointers[indexPath.row]
        tagCell.tagLabel.text = tagPointer.title
        //tagCell.accessibilityLabel = tagPointer.title
        //print("set accessibilityLabel to \(tagCell.accessibilityLabel)")
        return tagCell
    }
    
    func internalSearchBar(_ searchBar: UISearchBar, textDidChange searchText: String, dataModelCommit: (()->())?) {
        if searchText.count < lastSearchString.count {
            filteredTagPointers = allTagPointers
        } else if !searchText.isEmpty {
            let lowerCasedSearchString = searchText.lowercased()
            self.filteredTagPointers = filteredTagPointers.filter { (tagPointer) -> Bool in
                tagPointer.title.lowercased().contains(lowerCasedSearchString)
            }
        }
        
        let isUnique = (filteredTagPointers.first { (tagPointer) -> Bool in
                tagPointer.title == searchText
            } == nil)
        
        lastSearchString = searchText
        
        let userInfo: [AnyHashable : Any] = [TagCloudTraditionalDataSource.TagFieldTextIsUnique : isUnique]
        let notification = Notification.init(name: .TagTextFieldChanged, object: searchBar, userInfo: userInfo)
        dataModelCommit?()
        NotificationCenter.default.post(notification)
        resizeCellHandler()
    }
}


class TagCloudTraditionalDataSource : NSObject, TagCloudDataSource {

    static let TagFieldTextIsUnique = "TagFieldTextIsUnique"
    
    weak var tagCloudDelegate: TagCloudDelegate?
    let tagCloudID: String
    let context: TagContext
    let resizeCellHandler: () -> ()
    
    var allTagPointers = [TagPointer]()
    var filteredTagPointers = [TagPointer]()
    var lastSearchString = ""
    
    init(tagCloudDelegate: TagCloudDelegate, tagCloudID: String, context: TagContext, resizeCellHandler: @escaping () -> ()) {
        self.tagCloudDelegate = tagCloudDelegate
        self.tagCloudID = tagCloudID
        self.context = context
        self.resizeCellHandler = resizeCellHandler
        super.init()
        updateCache()
    }
    
    func updateCache() {
        let allTagPointers = updatedCache()
        self.allTagPointers = allTagPointers
        self.filteredTagPointers = allTagPointers
    }
}

extension TagCloudTraditionalDataSource : UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return internalCollectionView(collectionView, numberOfItemsInSection: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return internalCollectionView(collectionView, cellForItemAt: indexPath)
    }
}

extension TagCloudTraditionalDataSource : UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        internalSearchBar(searchBar, textDidChange: searchText, dataModelCommit: nil)
    }
}

@available(iOS 13.0, *)
class TagCloudDiffDataSource : NSObject, TagCloudDataSource {
    
    weak var tagCloudDelegate: TagCloudDelegate?
    let tagCloudID: String
    let context: TagContext
    let resizeCellHandler: () -> ()
    
    var allTagPointers = [TagPointer]()
    var filteredTagPointers = [TagPointer]()
    var lastSearchString = ""
    
    var dataSource: UICollectionViewDiffableDataSource<Section, String>! = nil
    
    init(tagCloudDelegate: TagCloudDelegate, tagCloudID: String, context: TagContext, resizeCellHandler: @escaping () -> ()) {
        self.tagCloudDelegate = tagCloudDelegate
        self.tagCloudID = tagCloudID
        self.context = context
        self.resizeCellHandler = resizeCellHandler
        super.init()
        updateCache()
    }
    
    func updateCache() {
        let allTagPointers = updatedCache()
        self.allTagPointers = allTagPointers
        self.filteredTagPointers = allTagPointers
    }
    
    func injectCollectionView(collectionView: UICollectionView) {
        configureDataSource(collectionView: collectionView)
    }

    func rebuildCacheAndUpdateSnapshot() {
        updateCache()
        dataSource.apply(snapshotForCurrentState(), animatingDifferences: true)
    }
    
    func configureDataSource(collectionView: UICollectionView) {
        self.dataSource = UICollectionViewDiffableDataSource<Section, String>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, tag: String) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCloudCell", for: indexPath) as? TagCollectionViewCell else { fatalError("Could not return TagCollectionViewCell") }
            cell.tagLabel.text = tag
            return cell
        }
        
        // load our initial data
        let snapshot = snapshotForCurrentState()
        self.dataSource.apply(snapshot, animatingDifferences: false)
        collectionView.dataSource = dataSource
    }
    
    func snapshotForCurrentState() -> NSDiffableDataSourceSnapshot<Section, String> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
        snapshot.appendSections([Section.main])
        for tagPointer in filteredTagPointers {
            snapshot.appendItems([tagPointer.title])
        }
        return snapshot
    }
}

@available(iOS 13.0, *)
extension TagCloudDiffDataSource : UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return internalCollectionView(collectionView, numberOfItemsInSection: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return internalCollectionView(collectionView, cellForItemAt: indexPath)
    }
}

@available(iOS 13.0, *)
extension TagCloudDiffDataSource : UITextFieldDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        internalSearchBar(searchBar, textDidChange: searchText) {
            self.dataSource.apply(self.snapshotForCurrentState())
        }
    }
}
