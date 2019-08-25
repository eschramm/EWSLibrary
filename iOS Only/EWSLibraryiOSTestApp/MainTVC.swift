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

public protocol TagCloudController { }

public enum TagContext {
    case item
    case all
}

public protocol TagDelegate : class {
    func tagCount(tagController: TagCloudController, context: TagContext) -> Int
    func tag(tagController: TagCloudController, context: TagContext, for index: Int) -> Tag
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
            cell = TagCloudCell(tagDelegate: self, reuseIdentifier: "TagCloudCell", removeAtIndexHandler: removeAtIndexHandler, addFromIndexAllowHandler: addFromIndexAllowHandler)
        }
        return cell!
    }
}

extension String: Tag {
    public var title: String {
        return self
    }
}

extension MainTVC: TagDelegate {
    
    func tagCount(tagController: TagCloudController, context: TagContext) -> Int {
        switch context {
        case .item:
            return addedTags.count
        case .all:
            return allTags.count
        }
    }
    
    func tag<String>(tagController: TagCloudController, context: TagContext, for index: Int) -> String {
        switch context {
        case .item:
            return addedTags[index] as! String
        case .all:
            return allTags[index] as! String
        }
    }
    
    func presentTagAddingViewController(tagAddingViewController: UIViewController) {
        present(tagAddingViewController, animated: true, completion: nil)
    }
    
    func dismissTagAddingViewController() {
        dismiss(animated: true, completion: nil)
    }
}

class TagCloudCell : UITableViewCell {
    // https://stackoverflow.com/questions/55061353/non-scrolling-uicollectionview-inside-uitableviewcell-dynamic-height
    
    /*enum Section {
        case main
    }*/
    
    let tagColor = UIColor.green
    let tagTitleColor = UIColor.black
    let tagTitleFont = UIFont.systemFont(ofSize: 14)
    let verticalPadding: CGFloat = 10
    let horizontalPadding: CGFloat = 10

    /*
    class OutlineItem: Hashable {
        let title: String
        let indentLevel: Int
        let subitems: [OutlineItem]
        let outlineViewController: UIViewController.Type?

        var isExpanded = false

        init(title: String,
             indentLevel: Int = 0,
             viewController: UIViewController.Type? = nil,
             subitems: [OutlineItem] = []) {
            self.title = title
            self.indentLevel = indentLevel
            self.subitems = subitems
            self.outlineViewController = viewController
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }
        static func == (lhs: OutlineItem, rhs: OutlineItem) -> Bool {
            return lhs.identifier == rhs.identifier
        }
        var isGroup: Bool {
            return self.outlineViewController == nil
        }
        private let identifier = UUID()
    }*/
    
    weak var tagDelegate: TagDelegate?
    //var dataSource: UICollectionViewDiffableDataSource<Section, String>! = nil
    
    let removeAtIndexHandler: ((Int) -> ())?
    let addFromIndexAllowHandler: (Int) -> (Bool)
    
    var collectionView: UICollectionView!
    
    public init(tagDelegate: TagDelegate, reuseIdentifier: String, removeAtIndexHandler: @escaping (Int) -> (), addFromIndexAllowHandler: @escaping (Int) -> (Bool)) {
        self.tagDelegate = tagDelegate
        self.removeAtIndexHandler = removeAtIndexHandler
        self.addFromIndexAllowHandler = addFromIndexAllowHandler
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
    }
    
    init(tagDelegate: TagDelegate, reuseIdentifier: String, addFromIndexAllowHandler: @escaping (Int) -> (Bool)) {
        self.tagDelegate = tagDelegate
        self.removeAtIndexHandler = nil
        self.addFromIndexAllowHandler = addFromIndexAllowHandler
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        buildCell()
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
        collectionView.dataSource = self
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
    /*
    func configureDataSource() {
        self.dataSource = UICollectionViewDiffableDataSource<Section, String>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, tag: String) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath)
            cell.label.text = menuItem.title
            cell.indentLevel = menuItem.indentLevel
            cell.isGroup = menuItem.isGroup
            cell.isExpanded = menuItem.isExpanded
            return cell
        }

        // load our initial data
        let snapshot = snapshotForCurrentState()
        self.dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    func snapshotForCurrentState() -> NSDiffableDataSourceSnapshot<Section, OutlineItem> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, OutlineItem>()
        snapshot.appendSections([Section.main])
        func addItems(_ menuItem: OutlineItem) {
            snapshot.appendItems([menuItem])
            if menuItem.isExpanded {
                menuItem.subitems.forEach { addItems($0) }
            }
        }
        menuItems.forEach { addItems($0) }
        return snapshot
    }

    func updateUI() {
        let snapshot = snapshotForCurrentState()
        dataSource.apply(snapshot, animatingDifferences: true)
    }*/
    
    @objc func addTag() {
        guard let tagDelegate = tagDelegate else { return }
        let updatedAddFromIndexAllowHandler: (Int) -> (Bool) = { index in
            let allowAdd = self.addFromIndexAllowHandler(index)
            if allowAdd {
                self.collectionView.insertItems(at: [IndexPath(row: tagDelegate.tagCount(tagController: self, context: .item) - 1, section: 0)])
                //self.collectionView.reloadData()
                
                // HACK: this allows for updating cell sizing inside tableview
                
                if let tableView = self.superview as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
            self.tagDelegate?.dismissTagAddingViewController()
            return allowAdd
        }
        let tagAddingTVC = TagAddingTVC(tagDelegate: tagDelegate, addFromIndexAllowHandler: updatedAddFromIndexAllowHandler)
        tagDelegate.presentTagAddingViewController(tagAddingViewController: tagAddingTVC)
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        self.layoutIfNeeded()
        let contentSize = self.collectionView.collectionViewLayout.collectionViewContentSize
        let calculatedHeight = contentSize.height + 20
        let minHeight: CGFloat = 58
        return CGSize(width: contentSize.width, height: calculatedHeight > minHeight ? calculatedHeight : minHeight) // 20 is the margin of the collectinview with top and bottom
    }
}

extension TagCloudCell : UICollectionViewDataSource, TagCloudController, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    // MARK: - UICollectionViewDataSource
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tagDelegate?.tagCount(tagController: self, context: cellContext()) ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let tagDelegate = tagDelegate else { return .zero }
        let title = tagDelegate.tag(tagController: self, context: cellContext(), for: indexPath.row).title as NSString
        let titleSize = title.size(withAttributes: [.font : tagTitleFont])
        return CGSize(width: titleSize.width + horizontalPadding, height: titleSize.height + verticalPadding)
    }
    
    // MARK: - UICollectionViewDelegate
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCloudCell", for: indexPath) as? TagCollectionViewCell else { fatalError("Could not return a TagCollectionViewCell") }
        let tag = tagDelegate!.tag(tagController: self, context: cellContext(), for: indexPath.row)
        tagCell.tagLabel.text = tag.title
        return tagCell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch cellContext() {
        case .all:
            _ = addFromIndexAllowHandler(indexPath.row)
        case .item:
            removeAtIndexHandler?(indexPath.row)
            collectionView.deleteItems(at: [indexPath])
            
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
    
    weak var tagDelegate: TagDelegate!
    let addFromIndexAllowHandler: (Int) -> (Bool)
    
    init(tagDelegate: TagDelegate, addFromIndexAllowHandler: @escaping (Int) -> (Bool)) {
        self.tagDelegate = tagDelegate
        self.addFromIndexAllowHandler = addFromIndexAllowHandler
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
                searchAddCell.searchAddField.delegate = self
                cell = searchAddCell
            }
            return cell!
        case 1:
            var cell = tableView.dequeueReusableCell(withIdentifier: "ExistingTagsCell")
            if cell == nil {
                cell = TagCloudCell(tagDelegate: tagDelegate, reuseIdentifier: "ExistingTagsCell", addFromIndexAllowHandler: addFromIndexAllowHandler)
            }
            return cell!
        default:
            fatalError("Should not ever reach")
        }
    }
}

extension TagAddingTVC : UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print(string)
        return true
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
