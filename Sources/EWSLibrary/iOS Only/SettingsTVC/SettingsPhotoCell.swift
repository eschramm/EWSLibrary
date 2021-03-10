//
//  SettingsPhotoCell.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/5/20.
//  Copyright © 2020 eware. All rights reserved.
//

#if os(iOS)
import UIKit

public class SettingsPhotoCell : UITableViewCell, SettingsCell {
    
    let getImageTitleHandler: () -> (UIImage?, String?)
    let setImageUpdateTitleHandler: (UIImage?) -> (String?)
    let maxCellHeight: CGFloat?
    var heightConstraint: NSLayoutConstraint?
    
    init?(model: SettingsCellModel, identifier: String) {
        if case .photoCell(maxCellHeight: let maxCellHeight, getImageTitleHandler: let getImageTitleHandler, setImageUpdateTitleHandler: let setImageUpdateTitleHandler) = model.cellType {
            self.maxCellHeight = maxCellHeight
            self.getImageTitleHandler = getImageTitleHandler
            self.setImageUpdateTitleHandler = setImageUpdateTitleHandler
            super.init(style: .default, reuseIdentifier: identifier)
            buildCell()
        } else {
            return nil
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildCell() {
        let tuple = getImageTitleHandler()
        imageView?.image = tuple.0
        textLabel?.text = tuple.1
        textLabel?.numberOfLines = 0
        accessoryType = .disclosureIndicator
        if let maxCellHeight = maxCellHeight {
            heightConstraint = contentView.heightAnchor.constraint(equalToConstant: maxCellHeight)
            heightConstraint?.priority = .defaultHigh
        }
    }
    
    public override func updateConstraints() {
        super.updateConstraints()
        let hasImage = (imageView?.image != nil)
        if heightConstraint?.isActive != hasImage {
            NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewBeginUpdates))
            heightConstraint?.isActive = hasImage
            NotificationCenter.default.post(Notification(name: .SettingsTVCTableviewEndUpdates))
        }
    }
    
    func selectAction(presentingViewController: UIViewController) {
        let photoViewController = PhotoViewController(image: imageView?.image)
        photoViewController.delegate = self
        presentingViewController.present(photoViewController, animated: true, completion: nil)
    }
}

extension SettingsPhotoCell: PhotoViewControllerDelegate {
    func photoViewController(photoViewController: PhotoViewController, didUpdate image: UIImage?) {
        photoViewController.dismiss(animated: true) {
            self.imageView?.image = image
            self.textLabel?.text = self.setImageUpdateTitleHandler(image)
            self.updateConstraints()
            self.setNeedsLayout()
        }
    }
}

protocol PhotoViewControllerDelegate: class {
    func photoViewController(photoViewController: PhotoViewController, didUpdate image: UIImage?)
}

class PhotoViewController: UIViewController {
    
    let imageView = UIImageView()
    let captureButton = UIButton(type: .system)
    let deleteButton = UIButton(type: .system)
    weak var delegate: PhotoViewControllerDelegate?
    
    init(image: UIImage?) {
        imageView.image = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .equalCentering
        view.addSubview(stackView)
        
        captureButton.addTarget(self, action: #selector(capture(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(captureButton)
                
        deleteButton.setTitle("Remove Photo", for: .normal)
        deleteButton.addTarget(self, action: #selector(remove(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(deleteButton)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(done(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(doneButton)
        
        updateButtons()
        
        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: imageView.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }
    
    @objc func capture(_ sender: AnyObject) {
        // NOTE: If want to adjust aspect ratio/crop in the future - https://stackoverflow.com/questions/43580924/how-to-make-uiimagepickercontroller-crop-169-ratio
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.mediaTypes = ["public.image"]
        picker.sourceType = .camera
        present(picker, animated: true, completion: nil)
    }
    
    @objc func remove(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.3) {
            self.imageView.alpha = 0
        }
        imageView.image = nil
        updateButtons()
    }
    
    @objc func done(_ sender: AnyObject) {
        delegate?.photoViewController(photoViewController: self, didUpdate: imageView.image)
    }
    
    func updateButtons() {
        captureButton.setTitle((imageView.image == nil) ? "Capture Photo" : "Update Photo", for: .normal)
        deleteButton.isHidden = (imageView.image == nil)
    }
}

extension PhotoViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        imageView.image = image
        imageView.alpha = 1
        updateButtons()
        dismiss(animated: true, completion: nil)
    }
}
#endif
