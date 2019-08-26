//
//  ViewController.swift
//  EWSLibraryiOSTestApp
//
//  Created by Eric Schramm on 8/19/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit
import EWSLibrary


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
    func presentTagAddingViewController(tagAddingViewController: UIViewController)
    func dismissTagAddingViewController()
}

class MainTVC: UITableViewController {
    
    let allTags = ["One", "Twenty", "Three Hundred", "Four Thousand", "Fifty Thousand", "Six Hundred Thousand", "Seven Million", "Eighty Million"]
    var addedTags = ["One"]
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "TagCloudCell")
        if cell == nil {
            let removeAtIndexHandler: (Int) -> () = { index in
                self.addedTags.remove(at: index)
            }
            let addFromIndexAllowHandler: (Int) -> (Bool) = { index in
                let tagToAdd = self.allTags[index]
                if !self.addedTags.contains(tagToAdd) {
                    self.addedTags.append(self.allTags[index])
                    return true
                } else {
                    return false
                }
            }
            cell = TagCloudCell(cloudID: "TagCloud", tagCloudDelegate: self, reuseIdentifier: "TagCloudCell", removeAtIndexHandler: removeAtIndexHandler, addFromIndexAllowHandler: addFromIndexAllowHandler)
        }
        return cell!
    }
}

extension String: Tag {
    public var title: String {
        return self
    }
}

extension MainTVC: TagCloudDelegate {
    func tagCount(cloudID: String, context: TagContext) -> Int {
        switch context {
        case .item:
            return addedTags.count
        case .all:
            return allTags.count
        }
    }
    
    func tag(cloudID: String, context: TagContext, for index: Int) -> Tag {
        switch context {
        case .item:
            return addedTags[index]
        case .all:
            return allTags[index]
        }
    }
    
    func presentTagAddingViewController(tagAddingViewController: UIViewController) {
        present(tagAddingViewController, animated: true, completion: nil)
    }
    
    func dismissTagAddingViewController() {
        dismiss(animated: true, completion: nil)
    }
}

class TagCloudCell : UITableViewCell, TagCloudController {
    
    // https://stackoverflow.com/questions/55061353/non-scrolling-uicollectionview-inside-uitableviewcell-dynamic-height
    
    let tagColor = UIColor.green
    let tagTitleColor = UIColor.black
    let tagTitleFont = UIFont.systemFont(ofSize: 14)
    let verticalPadding: CGFloat = 10
    let horizontalPadding: CGFloat = 10
    
    weak var tagCloudDelegate: TagCloudDelegate?
    let cloudID: String
    
    let removeAtIndexHandler: ((Int) -> ())?
    let addFromIndexAllowHandler: (Int) -> (Bool)
    
    var tagCloudDataSource: TagCloudDataSource!
    
    var collectionView: UICollectionView!
    
    public init(cloudID: String, tagCloudDelegate: TagCloudDelegate, reuseIdentifier: String, removeAtIndexHandler: @escaping (Int) -> (), addFromIndexAllowHandler: @escaping (Int) -> (Bool)) {
        self.cloudID = cloudID
        self.tagCloudDelegate = tagCloudDelegate
        self.removeAtIndexHandler = removeAtIndexHandler
        self.addFromIndexAllowHandler = addFromIndexAllowHandler
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
        buildDataSource()
        tagCloudDataSource.injectCollectionView(collectionView: collectionView)
    }
    
    init(cloudID: String, tagCloudDelegate: TagCloudDelegate, reuseIdentifier: String, addFromIndexAllowHandler: @escaping (Int) -> (Bool)) {
        self.cloudID = cloudID
        self.tagCloudDelegate = tagCloudDelegate
        self.removeAtIndexHandler = nil
        self.addFromIndexAllowHandler = addFromIndexAllowHandler
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildDataSource()
        buildCell()
        tagCloudDataSource.injectCollectionView(collectionView: collectionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cellContext() -> TagContext {
        return removeAtIndexHandler == nil ? .all : .item
    }
    
    func buildCell() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: 50, height: 55)
        flowLayout.sectionInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flowLayout.headerReferenceSize = CGSize.zero
        flowLayout.footerReferenceSize = CGSize.zero
        collectionView = UICollectionView(frame: contentView.frame, collectionViewLayout: flowLayout)
        contentView.addSubview(collectionView)
        collectionView.delegate = self
        //collectionView.dataSource = self
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
        
        switch cellContext() {
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
            //configureDataSource()
        }
        NSLayoutConstraint.activate(constraints)
    }

    func buildDataSource() {
        self.tagCloudDataSource = TagCloudDataSource(tagCloudDelegate: tagCloudDelegate!, tagCloudID: cloudID, context: cellContext())
    }
    
    @objc func addTag() {
        guard let tagCloudDelegate = tagCloudDelegate else { return }
        let updatedAddFromIndexAllowHandler: (Int) -> (Bool) = { index in
            let allowAdd = self.addFromIndexAllowHandler(index)
            if allowAdd {
                //self.collectionView.insertItems(at: [IndexPath(row: tagDelegate.tagCount(tagController: self, context: .item) - 1, section: 0)])
                self.tagCloudDataSource.rebuildCacheAndUpdateSnapshot()
                
                // HACK: this allows for updating cell sizing inside tableview
                
                if let tableView = self.superview as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
            tagCloudDelegate.dismissTagAddingViewController()
            return allowAdd
        }
        let tagAddingTVC = TagAddingTVC(tagCloudDelegate: tagCloudDelegate, cloudID: cloudID, addFromIndexAllowHandler: updatedAddFromIndexAllowHandler)
        tagCloudDelegate.presentTagAddingViewController(tagAddingViewController: tagAddingTVC)
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
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
    /*
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tagDelegate?.tagCount(tagController: self, context: cellContext()) ?? 0
    }*/

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let tagCloudDelegate = tagCloudDelegate, let tagCloudDataSource = tagCloudDataSource else { return .zero }
        let originalIndex = tagCloudDataSource.originalIndex(for: indexPath.row)
        let title = tagCloudDelegate.tag(cloudID: cloudID, context: cellContext(), for: originalIndex).title as NSString
        let titleSize = title.size(withAttributes: [.font : tagTitleFont])
        return CGSize(width: titleSize.width + horizontalPadding, height: titleSize.height + verticalPadding)
    }
    
    // MARK: - UICollectionViewDelegate
    /*
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCloudCell", for: indexPath) as? TagCollectionViewCell else { fatalError("Could not return a TagCollectionViewCell") }
        let tag = tagDelegate!.tag(tagController: self, context: cellContext(), for: indexPath.row)
        tagCell.tagLabel.text = tag.title
        return tagCell
    }*/
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch cellContext() {
        case .all:
            _ = addFromIndexAllowHandler(tagCloudDataSource.originalIndex(for: indexPath.row))
        case .item:
            removeAtIndexHandler?(indexPath.row)
            //collectionView.deleteItems(at: [indexPath])
            tagCloudDataSource.rebuildCacheAndUpdateSnapshot()
            
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
    
    init(tagCloudDelegate: TagCloudDelegate, cloudID: String, addFromIndexAllowHandler: @escaping (Int) -> (Bool)) {
        self.allTagsCell = TagCloudCell(cloudID: cloudID, tagCloudDelegate: tagCloudDelegate, reuseIdentifier: "ExistingTagsCell", addFromIndexAllowHandler: addFromIndexAllowHandler)
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            var cell = tableView.dequeueReusableCell(withIdentifier: "AddCell")
            if cell == nil {
                let searchAddCell = AddCell(reuseIdentifier: "AddCell")
                searchAddCell.searchAddField.delegate = allTagsCell.tagCloudDataSource
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
    
    let searchAddField = UITextField()
    
    init(reuseIdentifier: String) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        searchAddField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchAddField)
        
        let addButton = UIButton(type: .contactAdd)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            searchAddField.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.safeAreaLayoutGuide.leadingAnchor, multiplier: 1),
            addButton.leadingAnchor.constraint(equalToSystemSpacingAfter: searchAddField.trailingAnchor, multiplier: 1),
            addButton.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            addButton.centerYAnchor.constraint(equalTo: searchAddField.centerYAnchor),
            searchAddField.heightAnchor.constraint(lessThanOrEqualToConstant: 44),
            searchAddField.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            searchAddField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            searchAddField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
}

class TagCloudDataSource : NSObject, UICollectionViewDataSource {
    
    struct TagPointer {
        let title: String
        let originalIndex: Int
    }
    
    enum Section {
        case main
    }
    
    weak var tagCloudDelegate: TagCloudDelegate?
    let tagCloudID: String
    let context: TagContext
    
    var allTagPointers = [TagPointer]()
    var filteredTagPointers = [TagPointer]()
    var lastSearchString = ""
    
    init(tagCloudDelegate: TagCloudDelegate, tagCloudID: String, context: TagContext) {
        self.tagCloudDelegate = tagCloudDelegate
        self.tagCloudID = tagCloudID
        self.context = context
        super.init()
        rebuildCache()
    }
    
    func injectCollectionView(collectionView: UICollectionView) {
        configureDataSource(collectionView: collectionView)
    }
    
    func rebuildCache() {
        allTagPointers.removeAll()
        guard let tagCloudDelegate = tagCloudDelegate else { return }
        for originalIndex in 0..<tagCloudDelegate.tagCount(cloudID: tagCloudID, context: context) {
            allTagPointers.append(TagPointer(title: tagCloudDelegate.tag(cloudID: tagCloudID, context: context, for: originalIndex).title, originalIndex: originalIndex))
        }
        filteredTagPointers = allTagPointers
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredTagPointers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCloudCell", for: indexPath) as? TagCollectionViewCell else {
            fatalError("Could not return a TagCollectionViewCell")
        }
        guard let tagCloudDelegate = tagCloudDelegate else {
            return tagCell
        }
        let tag = tagCloudDelegate.tag(cloudID: tagCloudID, context: context, for: indexPath.row)
        tagCell.tagLabel.text = tag.title
        return tagCell
    }
    
    func originalIndex(for filteredIndex: Int) -> Int {
        return filteredTagPointers[filteredIndex].originalIndex
    }
    
    // MARK - iOS 13 - UIDiffable
    
    var dataSource: UICollectionViewDiffableDataSource<Section, String>! = nil
    
    func rebuildCacheAndUpdateSnapshot() {
        rebuildCache()
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

extension TagCloudDataSource : UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let fieldText = textField.text else { return true }
        let searchString: String
        if string.isEmpty {
            searchString = String(fieldText.prefix(upTo: fieldText.index(fieldText.endIndex, offsetBy: -1)))
        } else {
            searchString = fieldText + string
        }
        if searchString.count < lastSearchString.count {
            filteredTagPointers = allTagPointers
        }
        if !searchString.isEmpty {
            let lowerCasedSearchString = searchString.lowercased()
            filteredTagPointers = filteredTagPointers.filter { (tagPointer) -> Bool in
                tagPointer.title.lowercased().contains(lowerCasedSearchString)
            }
        }
        lastSearchString = searchString
        dataSource.apply(snapshotForCurrentState())
        return true
    }
}
