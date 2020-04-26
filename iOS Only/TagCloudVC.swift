//
//  TagCloudVC.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 8/19/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit

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

public struct TagCloudParameters {
    let tagColor: UIColor
    let tagCornerRadius: CGFloat
    let tagTitleColor: UIColor
    let tagTitleFont: UIFont
    let backgroundColor: UIColor
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat
    
    public init(
        tagColor: UIColor = .systemGreen,
        tagCornerRadius: CGFloat = 5,
        tagTitleColor: UIColor = UIColor.dynamicLabel(),
        tagTitleFont: UIFont = UIFont.systemFont(ofSize: 14),
        backgroundColor: UIColor = .clear,
        verticalPadding: CGFloat = 10,
        horizontalPadding: CGFloat = 10)
    {
        self.tagColor = tagColor
        self.tagCornerRadius = tagCornerRadius
        self.tagTitleColor = tagTitleColor
        self.tagTitleFont = tagTitleFont
        self.backgroundColor = backgroundColor
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
    }
}

public class SettingsTagCloudCell : UITableViewCell, TagCloudController {
    
    // https://stackoverflow.com/questions/55061353/non-scrolling-uicollectionview-inside-uitableviewcell-dynamic-height

    public let cloudID: String
    weak var tagCloudDelegate: TagCloudDelegate?
    let parameters: TagCloudParameters
    let cellContext: TagContext
    let updateItemTagCellHandler: ((Int) -> ())?
    
    var tagCloudDataSource: TagCloudDataSource!
    
    var collectionView: UICollectionView!
    
    public init(cloudID: String, tagCloudDelegate: TagCloudDelegate, reuseIdentifier: String, parameters: TagCloudParameters = TagCloudParameters()) {
        self.cloudID = cloudID
        self.tagCloudDelegate = tagCloudDelegate
        self.parameters = parameters
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
    
    init(allCell cloudID: String, tagCloudDelegate: TagCloudDelegate, reuseIdentifier: String, parameters: TagCloudParameters, updateItemTagCellHandler: @escaping (Int) -> ()) {
        self.cloudID = cloudID
        self.tagCloudDelegate = tagCloudDelegate
        self.parameters = parameters
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
        contentView.backgroundColor = parameters.backgroundColor
        
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
            self.tagCloudDataSource = TagCloudDiffDataSource(tagCloudDelegate: tagCloudDelegate!, tagCloudID: cloudID, parameters: parameters, context: cellContext, resizeCellHandler: {
                // HACK: this allows for updating cell sizing inside tableview
                if let tableView = self.superview as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            })
        } else {
            self.tagCloudDataSource = TagCloudTraditionalDataSource(tagCloudDelegate: tagCloudDelegate!, tagCloudID: cloudID, parameters: parameters, context: cellContext, resizeCellHandler: {
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
        let tagAddingTVC = TagAddingTVC(tagCloudDelegate: tagCloudDelegate, cloudID: cloudID, parameters: parameters, updateItemTagCellHandler: updateItemTagCellHandler)
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
        return CGSize(width: contentSize.width, height: calculatedHeight > minHeight ? calculatedHeight : minHeight) // 20 is the margin of the collectionview with top and bottom
    }
}

extension SettingsTagCloudCell : UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    // MARK: - UICollectionViewDataSource
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let title = tagCloudDataSource.filteredTagPointers[indexPath.row].title
        let titleSize = title.size(withAttributes: [.font : parameters.tagTitleFont])
        return CGSize(width: titleSize.width + parameters.horizontalPadding, height: titleSize.height + parameters.verticalPadding)
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

extension SettingsTagCloudCell : SettingsCell {
    func selectAction(presentingViewController: UIViewController) {
        // nothing
    }
}

class TagCollectionViewCell : UICollectionViewCell {
    
    let tagLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        apply(parameters: TagCloudParameters())
        contentView.addSubview(tagLabel)
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        let viewsDict = ["tagLabel" : tagLabel]
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[tagLabel]|", options: .alignmentMask, metrics: nil, views: viewsDict)
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|[tagLabel]|", options: .alignmentMask, metrics: nil, views: viewsDict))
        
        NSLayoutConstraint.activate(constraints)
    }
    
    func apply(parameters: TagCloudParameters) {
        tagLabel.backgroundColor = parameters.tagColor
        tagLabel.layer.cornerRadius = parameters.tagCornerRadius
        tagLabel.clipsToBounds = true
        tagLabel.textAlignment = .center
        tagLabel.font = parameters.tagTitleFont
        tagLabel.textColor = parameters.tagTitleColor
    }
}

class TagAddingTVC : UITableViewController {
    
    let allTagsCell: SettingsTagCloudCell
    weak var tagCloudDelegate: TagCloudDelegate?
    let updateItemTagCellHandler: (Int) -> ()
    
    init(tagCloudDelegate: TagCloudDelegate, cloudID: String, parameters: TagCloudParameters, updateItemTagCellHandler: @escaping (Int) -> ()) {
        self.allTagsCell = SettingsTagCloudCell(allCell: cloudID, tagCloudDelegate: tagCloudDelegate, reuseIdentifier: "ExistingTagsCell", parameters: parameters, updateItemTagCellHandler: updateItemTagCellHandler)
        self.tagCloudDelegate = tagCloudDelegate
        self.updateItemTagCellHandler = updateItemTagCellHandler
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableviewHeader()
    }
    
    func configureTableviewHeader() {
        let headerView = AddView(addTagHandler: { (newTagTitle) in
            if let delegate = self.tagCloudDelegate {
                if delegate.shouldCreateTag(with: newTagTitle) {
                    let createdIndex = delegate.indexForCreatedTag(with: newTagTitle)
                    self.updateItemTagCellHandler(createdIndex)
                }
            }
        })
        headerView.searchBar.delegate = allTagsCell.tagCloudDataSource
       
        // see https://stackoverflow.com/questions/16471846/is-it-possible-to-use-autolayout-with-uitableviews-tableheaderview
        // autoLayout doesn't really work here so need to get height and set explicitly
    
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        let height = headerView.systemLayoutSizeFitting(CGSize(width: tableView.frame.width, height: 100), withHorizontalFittingPriority: .defaultHigh, verticalFittingPriority: .defaultHigh).height
        var headerFrame = headerView.frame
        headerFrame.size.height = height
        headerView.frame = headerFrame
         tableView.tableHeaderView = headerView
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "ExistingTagsCell")
        if cell == nil {
            cell = allTagsCell
        }
        return cell!
    }
}

class AddView : UIView {
    
    let searchBar = UISearchBar()
    
    let addTagHandler: (String) -> ()
    
    init(addTagHandler: @escaping (String) -> ()) {
        self.addTagHandler = addTagHandler
        super.init(frame: .zero)
        buildCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchBar)
        
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
            searchBar.leadingAnchor.constraint(equalToSystemSpacingAfter: safeAreaLayoutGuide.leadingAnchor, multiplier: 1),
            searchBar.trailingAnchor.constraint(equalToSystemSpacingAfter: safeAreaLayoutGuide.trailingAnchor, multiplier: -1),
            searchBar.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            searchBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
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
    var parameters: TagCloudParameters { get }
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
        tagCell.apply(parameters: parameters)
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
    let parameters: TagCloudParameters
    let resizeCellHandler: () -> ()
    
    var allTagPointers = [TagPointer]()
    var filteredTagPointers = [TagPointer]()
    var lastSearchString = ""
    
    init(tagCloudDelegate: TagCloudDelegate, tagCloudID: String, parameters: TagCloudParameters, context: TagContext, resizeCellHandler: @escaping () -> ()) {
        self.tagCloudDelegate = tagCloudDelegate
        self.tagCloudID = tagCloudID
        self.parameters = parameters
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
    let parameters: TagCloudParameters
    let resizeCellHandler: () -> ()
    
    var allTagPointers = [TagPointer]()
    var filteredTagPointers = [TagPointer]()
    var lastSearchString = ""
    
    var dataSource: UICollectionViewDiffableDataSource<Section, String>! = nil
    
    init(tagCloudDelegate: TagCloudDelegate, tagCloudID: String, parameters: TagCloudParameters, context: TagContext, resizeCellHandler: @escaping () -> ()) {
        self.tagCloudDelegate = tagCloudDelegate
        self.tagCloudID = tagCloudID
        self.parameters = parameters
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
        self.dataSource = UICollectionViewDiffableDataSource<Section, String>(collectionView: collectionView) { [weak self]
            (collectionView: UICollectionView, indexPath: IndexPath, tag: String) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCloudCell", for: indexPath) as? TagCollectionViewCell else { fatalError("Could not return TagCollectionViewCell") }
            cell.tagLabel.text = tag
            if let self = self {
                cell.apply(parameters: self.parameters)
            }
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
