//
//  GhostAlertView.swift
//  
//
//  Created by Eric Schramm on 5/28/21.
//

import UIKit


public class GhostAlertView : UIView {
    
    let timeout: TimeInterval
    
    @objc public init(title: String, message: String, timeout: TimeInterval, dismissible: Bool) {
        self.timeout = timeout
        super.init(frame: .zero)
        buildView(title: title, message: message)
        if dismissible {
            let gr = UITapGestureRecognizer(target: self, action: #selector(hide))
            gestureRecognizers = [gr]
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buildView(title: String, message: String) {
        
        alpha = 0
        
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 15
        layer.shadowOffset = CGSize(width: 7, height: 7)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.7
        layer.borderWidth = 1
        layer.borderColor = UIColor.label.cgColor
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        addSubview(titleLabel)
        var constraints: [NSLayoutConstraint] = [
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ]
        
        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.text = message
        messageLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        addSubview(messageLabel)
        constraints.append(contentsOf: [
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
        
        NSLayoutConstraint.activate(constraints)
    }
    
    @objc public func show(in view: UIView) {
        print("SHOWING ONE")
        for subview in view.subviews {
            if let otherGAV = subview as? GhostAlertView {
                otherGAV.hide()
            }
        }
        view.addSubview(self)
        
        NSLayoutConstraint.activate([
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
        
        UIView.animate(withDuration: 0.5) {
            self.alpha = 1
        } completion: { _ in
            print("Animation completed")
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(self.timeout * 1000))) {
                self.hide()
            }
        }
    }
    
    @objc func hide() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        UIView.animate(withDuration: 0.5) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
