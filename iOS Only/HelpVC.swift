//
//  HelpVC.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 12/6/18.
//  Copyright © 2018 eware. All rights reserved.
//

import WebKit

public class HelpVC : UIViewController {
    
    public enum Resource {
        case localHTMLtitle(String)
        case url(URL)
    }
    
    let resource: Resource
    
    let webView = WKWebView()
    
    
    public init(resource: Resource) {
        self.resource = resource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented - not intended for use in Storyboard or nib")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
                ])
        } else {
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.topAnchor.constraint(equalTo: view.topAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
        }
        
        let url: URL?
        switch resource {
        case .localHTMLtitle(let title):
            url = Bundle.main.url(forResource: title, withExtension: ".html")
        case .url(let externalURL):
            url = externalURL
        }
        if let url = url {
            let urlRequest = URLRequest(url: url)
            webView.load(urlRequest)
        }
    }
}
