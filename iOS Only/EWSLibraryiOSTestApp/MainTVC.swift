//
//  ViewController.swift
//  EWSLibraryiOSTestApp
//
//  Created by Eric Schramm on 8/19/19.
//  Copyright © 2019 eware. All rights reserved.
//

import UIKit
import EWSLibrary

class MainTVC: UITableViewController {
    
    var allTags = ["One", "Twenty", "Three Hundred", "Four Thousand", "Fifty Thousand", "Six Hundred Thousand", "Seven Million", "Eighty Million"]
    var filteredAllTags = [String]()
    var addedTags = ["One"]
    
    func updatedFilteredAllTags() {
        filteredAllTags = allTags.filter({ (tag) -> Bool in
            !addedTags.contains(tag)
        })
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "TagCloudCell")
        if cell == nil {
            cell = TagCloudCell(cloudID: "TagCloud", tagCloudDelegate: self, reuseIdentifier: "TagCloudCell")
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
            updatedFilteredAllTags()
            return filteredAllTags.count
        }
    }
    
    func tag(cloudID: String, context: TagContext, for index: Int) -> Tag {
        switch context {
        case .item:
            return addedTags[index]
        case .all:
            return filteredAllTags[index]
        }
    }
    
    func removeTag(at index: Int) {
        self.addedTags.remove(at: index)
        updatedFilteredAllTags()
    }
    
    func didAddTag(from index: Int) -> Bool {
        let tagToAdd = self.filteredAllTags[index]
        if !self.addedTags.contains(tagToAdd) {
            self.addedTags.append(self.filteredAllTags[index])
            updatedFilteredAllTags()
            return true
        } else {
            return false
        }
    }
    
    func presentTagAddingViewController(tagAddingViewController: UIViewController) {
        present(tagAddingViewController, animated: true, completion: nil)
    }
    
    func dismissTagAddingViewController() {
        dismiss(animated: true, completion: nil)
    }
    
    func shouldCreateTag(with title: String) -> Bool {
        return !(allTags.contains(title))
    }
    
    func indexForCreatedTag(with title: String) -> Int {
        allTags.append(title)
        updatedFilteredAllTags()
        return filteredAllTags.count - 1
    }
}
