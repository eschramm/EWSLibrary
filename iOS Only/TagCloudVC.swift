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

public protocol TagController {
    
}

public protocol TagCloudDelegate {
    func tagCloudController(tagCloudController: TagCloudController, didTapTag tag: Tag)
}

public protocol TagDataSource {
    func tagCount(tagController: TagController) -> Int
    func tag(tagController: TagController, for index: Int) -> Tag
}

public class TagCloudController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, TagController {
    
    let delegate: TagCloudDelegate
    let dataSource: TagDataSource
    var collectionView: UICollectionView
    var stretchVerticallyToContentSize = false
    
    let tagColor = UIColor.green
    let tagTitleColor = UIColor.black
    let tagTitleFont = UIFont.systemFont(ofSize: 14)
    let verticalPadding: CGFloat = 10
    let horizontalPadding: CGFloat = 10
    var verticalStretchConstraint: NSLayoutConstraint!
    
    public init(view: UIView, delegate: TagCloudDelegate, dataSource: TagDataSource, stretchVerticallyToContentSize: Bool = false) {
        
        self.delegate = delegate
        self.dataSource = dataSource
        self.stretchVerticallyToContentSize = stretchVerticallyToContentSize
        
        view.layoutIfNeeded()
        
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: 50, height: 55)
        flowLayout.sectionInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flowLayout.headerReferenceSize = CGSize.zero
        flowLayout.footerReferenceSize = CGSize.zero
        self.collectionView = UICollectionView(frame: view.frame, collectionViewLayout: flowLayout)
        
        super.init(nibName: nil, bundle: nil)
        
        self.view = view
        viewDidLoad()
    }
    
    public func unrestrainedHeight() -> CGFloat {
        return collectionView.contentSize.height
    }
    
    override public func viewDidLoad() {
        
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        view.addSubview(collectionView)
        
        if let view = view {
            verticalStretchConstraint = NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: view.frame.height)
            let viewsDict = ["collectionView" : collectionView, "verticalStretchConstraint" : verticalStretchConstraint!, "view" : view] as [String : Any]
            var constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[collectionView]|", options: [], metrics: nil, views: viewsDict)
            let verticalVisualFormat: String
            if stretchVerticallyToContentSize {
                verticalVisualFormat = "V:|[collectionView]"
            } else {
                verticalVisualFormat = "V:|[collectionView]|"
            }
            constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: verticalVisualFormat, options: [], metrics: nil, views: viewsDict))
            //constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:[collectionView(>=\(view.frame.height)@750)]", options: .alignmentMask, metrics: nil, views: viewsDict))
            NSLayoutConstraint.activate(constraints)
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if stretchVerticallyToContentSize {
            NSLayoutConstraint.activate([verticalStretchConstraint])
        }
        updateTagCloud()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateTagCloud() {
        collectionView.reloadData()
        if stretchVerticallyToContentSize {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: {
                self.verticalStretchConstraint.constant = self.collectionView.contentSize.height
            })
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate.tagCloudController(tagCloudController: self, didTapTag: dataSource.tag(tagController: self, for: indexPath.row))
    }
    
    // MARK: - UICollectionViewDataSource
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.tagCount(tagController: self)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let title = dataSource.tag(tagController: self, for: indexPath.row).title as NSString
        let titleSize = title.size(withAttributes: [.font : tagTitleFont])
        return CGSize(width: titleSize.width + horizontalPadding, height: titleSize.height + verticalPadding)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        verticalStretchConstraint.constant = collectionView.contentSize.height
    }
    
    // MARK: - UICollectionViewDelegate
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        let tag = dataSource.tag(tagController: self, for: indexPath.row)
        
        let tagLabel = UILabel()
        tagLabel.backgroundColor = tagColor
        tagLabel.text = tag.title
        tagLabel.textAlignment = .center
        tagLabel.font = tagTitleFont
        tagLabel.textColor = tagTitleColor
        
        cell.addSubview(tagLabel)
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        let viewsDict = ["tagLabel" : tagLabel]
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[tagLabel]|", options: .alignmentMask, metrics: nil, views: viewsDict)
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|[tagLabel]|", options: .alignmentMask, metrics: nil, views: viewsDict))
        
        NSLayoutConstraint.activate(constraints)
        
        return cell
    }
}

protocol TagSelectorDelegate {
    func tagSelectorVC(tagSelectorVC: TagSelectorVC, didSelectTag tag: Tag)
    func tagSelectorVC(tagSelectorVC: TagSelectorVC, createNewTagWith name: String)
}

class TagSelectorVC : UIViewController, TagCloudDelegate, TagDataSource, TagController, UITextFieldDelegate {
    
    let delegate: TagSelectorDelegate!
    let dataSource: TagDataSource!
    
    let scrollView = UIScrollView()
    let contentView = UIView()
    let tagField = UITextField()
    let addButton = UIButton(type: .contactAdd)
    let tagSuggestionButton = UIButton(type: .system)
    var tagCloudController: TagCloudController!
    let tagCloudView = UIView()
    var filtered = [Tag]()
    var lastSearchString: String?
    var suggestedTag: Tag?
    
    init(delegate: TagSelectorDelegate, dataSource: TagDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.backgroundColor = UIColor.black
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        tagField.borderStyle = .line
        tagField.backgroundColor = UIColor.white
        tagField.autocapitalizationType = .none
        tagField.translatesAutoresizingMaskIntoConstraints = false
        tagField.delegate = self
        contentView.addSubview(tagField)
        
        addButton.addTarget(self, action: #selector(TagSelectorVC.addTag(sender:)), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)
        
        tagSuggestionButton.contentEdgeInsets = UIEdgeInsets.init(top: 5, left: 10, bottom: 5, right: 10)
        tagSuggestionButton.backgroundColor = UIColor.green
        tagSuggestionButton.isHidden = true
        tagSuggestionButton.addTarget(self, action: #selector(addSuggestion(sender:)), for: .touchUpInside)
        tagSuggestionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagSuggestionButton)
        
        tagCloudView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagCloudView)
        
        var viewsDict = [String : Any]()
        viewsDict["scrollView"] = scrollView
        viewsDict["contentView"] = contentView
        viewsDict["tagField"] = tagField
        viewsDict["addButton"] = addButton
        viewsDict["tagSuggestionButton"] = tagSuggestionButton
        viewsDict["tagCloudView"] = tagCloudView
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: .directionMask, metrics: nil, views: viewsDict))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView]|", options: .directionMask, metrics: nil, views: viewsDict))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView(>=320)]|", options: .directionMask, metrics: nil, views: viewsDict))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView]|", options: .directionMask, metrics: nil, views: viewsDict))
        contentView.addConstraint(tagSuggestionButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[tagSuggestionButton][tagField(>=30)]-[tagCloudView(>=100)]-|", options: .directionMask, metrics: nil, views: viewsDict))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[tagCloudView]-|", options: .directionMask, metrics: nil, views: viewsDict))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[tagField(>=100)]-[addButton]-|", options: .directionMask, metrics: nil, views: viewsDict))
        contentView.addConstraint(addButton.centerYAnchor.constraint(equalTo: tagField.centerYAnchor))
        
        tagCloudController = TagCloudController(view: tagCloudView, delegate: self, dataSource: self)
        addChild(tagCloudController)
        tagCloudController.stretchVerticallyToContentSize = true
        
    }
    
    @objc func addTag(sender: UIButton) {
        if let text = tagField.text, !text.isEmpty {
            delegate.tagSelectorVC(tagSelectorVC: self, createNewTagWith: text)
        }
    }
    
    @objc func addSuggestion(sender: UIButton) {
        if let tag = suggestedTag {
            delegate.tagSelectorVC(tagSelectorVC: self, didSelectTag: tag)
        }
    }
    
    // MARK: - UITextField Delegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        addTag(sender: addButton)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        guard let textFieldText = textField.text else { return true }
        
        let needle = string.isEmpty ? String(textFieldText.dropLast()) : "\(textFieldText)\(string)".lowercased()

        var searched = [Tag]()
        if let _ = lastSearchString, !string.isEmpty {
            for tag in filtered {
                if tag.title.lowercased().contains(needle) {
                    searched.append(tag)
                }
            }
        } else {
            for n in 0...(dataSource.tagCount(tagController: self) - 1) {
                let tag = dataSource.tag(tagController: self, for: n)
                if tag.title.lowercased().contains(needle) {
                    searched.append(tag)
                }
            }
        }
        filtered = searched
        if filtered.count == 1 {
            let tag = filtered.first!
            tagSuggestionButton.setTitle(tag.title, for: .normal)
            tagSuggestionButton.isHidden = false
            suggestedTag = tag
        } else {
            tagSuggestionButton.setTitle("", for: .normal)
            tagSuggestionButton.isHidden = true
            suggestedTag = nil
        }
        
        return true
    }
    
    // MARK: - TagCloud Delegate
    
    func tagCloudController(tagCloudController: TagCloudController, didTapTag tag: Tag) {
        delegate.tagSelectorVC(tagSelectorVC: self, didSelectTag: tag)
    }
    
    // MARK: - Tag DataSource
    
    func tagCount(tagController: TagController) -> Int {
        return dataSource.tagCount(tagController: self)
    }
    
    func tag(tagController: TagController, for index: Int) -> Tag {
        return dataSource.tag(tagController: self, for: index)
    }
    
}



