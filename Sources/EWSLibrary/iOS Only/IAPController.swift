//
//  InAppPurchase.swift
//  StattyCaddy
//
//  Created by Eric Schramm on 10/9/14.
//  Copyright (c) 2014 Eric Schramm. All rights reserved.
//

#if os(iOS)
import Foundation
import StoreKit


public class IAPCoordinator {
    
    var iapController: IAPController?
    let productIdentifiers: Set<String>
    let productPackage: IAPProductPackage
    
    var dismissHandler: ((UIViewController) -> ())?
    
    var iapViewController: IAPviewController?
    
    public init(productIdentifiers: Set<String>, productPackage: IAPProductPackage) {
        self.productIdentifiers = productIdentifiers
        self.productPackage = productPackage
    }
    
    func present(for productIdentifier: String, presentHandler: @escaping (UIViewController) -> (), dismissHandler: @escaping (UIViewController)-> ()) {
        self.dismissHandler = dismissHandler
        let controller = IAPController(productIdentifiers: self.productIdentifiers, presentHandler: presentHandler, dismissHandler: dismissHandler)
        iapController = controller
        controller.requestProducts { (success, products) in
            if let products = products, let product = products.first(where: { (product) -> Bool in
                product.productIdentifier == productIdentifier
            }) {
                let viewController = IAPviewController(product: product, productPackage: self.productPackage, iapController: controller, dismissHandler: dismissHandler)
                self.iapViewController = viewController
                presentHandler(viewController)
            }
        }
    }
    
    @objc public func dismiss() {
        if let dismissHandler = dismissHandler, let iapViewController = iapViewController {
            dismissHandler(iapViewController)
        }
    }
}

class IAPController: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    let productIdentifiers: Set<String>
    var purchasedProductIdentifiers: Set<String>
    let presentHandler: (UIViewController) -> ()
    var completionHandler: ((Bool, [SKProduct]?) -> ())?
    var productsRequest: SKProductsRequest?
    
    init(productIdentifiers: Set<String>, presentHandler: @escaping (UIViewController) -> (), dismissHandler: @escaping (UIViewController)-> ()) {
        self.productIdentifiers = productIdentifiers
        self.presentHandler = presentHandler
        self.purchasedProductIdentifiers = Set<String>()
        for productIdentifier in productIdentifiers {
            let productPurchased = UserDefaults.standard.bool(forKey: productIdentifier)  // assumes we store a bool key-value in UserDefaults for local/cached IAP purchased status
            if productPurchased {
                purchasedProductIdentifiers.insert(productIdentifier)
                print("Previously purchased: \(productIdentifier)")
            } else {
                print("Not purchased: \(productIdentifier)")
            }
        }
        
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    func requestProducts(completionHandler: @escaping (Bool, [SKProduct]?) -> ()) {
        productsRequest?.cancel()
        self.completionHandler = completionHandler
        
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()
    }
    
    func requestProductsWithCompletionHandler(_ completionHandler: ((_ success: Bool, _ products: [SKProduct]?) -> ())?) {
        self.completionHandler = completionHandler
        let productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest.delegate = self
        productsRequest.start()
    }
    
    func buyProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func productPurchased(_ productIdentifier: String) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    func completeTransaction(_ transaction: SKPaymentTransaction) {
        print("completeTransaction ...")
        provideContentForProductIdentifier(transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    func restoreCompletedTransactions() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func restoreTransaction(_ transaction: SKPaymentTransaction) {
        print("restoreTransaction ...")
        provideContentForProductIdentifier(transaction.original!.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    func failedTransaction(_ transaction: SKPaymentTransaction) {
        print("failedTransaction ...")
        if transaction.error!._code !=  SKError.Code.paymentCancelled.rawValue {
            print("Transaction error: \(transaction.error!.localizedDescription)")
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    func provideContentForProductIdentifier(_ productIdentifier: String) {
        purchasedProductIdentifiers.insert(productIdentifier)
        UserDefaults.standard.set(true, forKey: productIdentifier)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "IAPHelperProductPurchasedNotification"), object: productIdentifier, userInfo: nil)
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                completeTransaction(transaction)
            case .failed:
                failedTransaction(transaction)
            case .restored:
                restoreTransaction(transaction)
            default:
                print("Unhandled transaction.transactionState in updatedTransactions: \(transaction.transactionState)")
            }
        }
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        print("Loaded list of products ...")
        productsRequest = nil
        
        let skProducts = response.products
        for skProduct in skProducts {
            print("Found product: \(skProduct.productIdentifier) \(skProduct.localizedTitle) \(skProduct.price)")
        }
        completionHandler?(true, skProducts)
        completionHandler = nil;
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products")
        productsRequest = nil
        completionHandler?(false, nil)
        completionHandler = nil
        
        let alert = UIAlertController(title: "Request Failed", message: "Failed to load In App Purchase", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        presentHandler(alert)
    }
    
}

public struct IAPProductPackage {
    let identifier: String
    let title: String
    let description: String
    let pngTitle: String?
    public init(identifier: String, title: String, description: String, pngTitle: String?) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.pngTitle = pngTitle
    }
}

class IAPviewController : UIViewController {
    
    let product: SKProduct
    let productPackage: IAPProductPackage
    var activityIndicator: UIActivityIndicatorView?
    let iapController: IAPController
    let dismissHandler: (UIViewController) -> ()
    
    
    init(product: SKProduct, productPackage: IAPProductPackage, iapController: IAPController, dismissHandler: @escaping (UIViewController) -> ()) {
        self.product = product
        self.productPackage = productPackage
        self.iapController = iapController
        self.dismissHandler = dismissHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        view.backgroundColor = UIColor.white
        
        let titleLabel = UILabel()
        titleLabel.text = productPackage.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let descriptionView = UITextView()
        descriptionView.text = productPackage.description
        descriptionView.textAlignment = NSTextAlignment.center
        descriptionView.isEditable = false
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionView)
        
        let graphicView = UIImageView()
        graphicView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(graphicView)
        
        let actionButton = UIButton(type: .custom)
        actionButton.setTitle("Purchase \(productPackage.title)", for: .normal)
        actionButton.setTitleColor(UIColor.blue, for: .normal)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(IAPviewController.actionButtonTapped), for: .touchUpInside)
        view.addSubview(actionButton)
        
        let restoreButton = UIButton(type: .custom)
        restoreButton.setTitle("Restore Purchase", for: .normal)
        restoreButton.setTitleColor(UIColor.blue, for: .normal)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.addTarget(self, action: #selector(IAPviewController.restoreButtonTapped), for: .touchUpInside)
        view.addSubview(restoreButton)
        
        let indicator = UIActivityIndicatorView(style: .gray)
        activityIndicator = indicator
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.isHidden = true
        view.addSubview(indicator)
        
        var viewBindingsDict = [String : AnyObject]()
        viewBindingsDict["titleLabel"] = titleLabel
        viewBindingsDict["descriptionView"] = descriptionView
        viewBindingsDict["graphicView"] = graphicView
        viewBindingsDict["actionButton"] = actionButton
        viewBindingsDict["restoreButton"] = restoreButton
        viewBindingsDict["activityIndicator"] = activityIndicator
        
        var constraints = [NSLayoutConstraint]()
        
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-(80)-[titleLabel]-[descriptionView(100)]-[graphicView(>=20)]-(>=40)-[actionButton]-[activityIndicator]-[restoreButton]-(40)-|", options: [], metrics: nil, views: viewBindingsDict))
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-[descriptionView]-|", options: [], metrics: nil, views: viewBindingsDict))
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-[graphicView]-|", options: [], metrics: nil, views: viewBindingsDict))
        constraints.append(contentsOf: [
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        
        NSLayoutConstraint.activate(constraints)
        
        view.layoutSubviews()
        
        if let pngTitle = productPackage.pngTitle, let largeImage = UIImage(named: pngTitle) {
            graphicView.image = imageWithImage(largeImage, scaledToWidth: graphicView.frame.size.width)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(IAPviewController.contentUnlocked(_:)),
            name: NSNotification.Name("IAPHelperProductPurchasedNotification"),
            object: nil)
    }
    
    func imageWithImage(_ sourceImage:UIImage, scaledToWidth width:CGFloat) -> UIImage {
        
        let oldWidth = sourceImage.size.width
        let scaleFactor = width / oldWidth
        
        let newHeight = sourceImage.size.height * scaleFactor
        let newWidth = oldWidth * scaleFactor
        
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        sourceImage.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func imageWithImage(_ sourceImage:UIImage, scaledToHeight height:CGFloat) -> UIImage {
        
        let oldHeight = sourceImage.size.width
        let scaleFactor = height / oldHeight
        
        let newHeight = oldHeight * scaleFactor
        let newWidth = sourceImage.size.width * scaleFactor
        
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        sourceImage.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func imageWithImage(_ sourceImage:UIImage, scaledToSize newSize:CGSize) -> UIImage {
        UIGraphicsBeginImageContext(newSize)
        sourceImage.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    @objc func actionButtonTapped() {
        iapController.buyProduct(product)
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimating()
    }
    
    @objc func restoreButtonTapped() {
        iapController.restoreCompletedTransactions()
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimating()
    }
    
    @objc func contentUnlocked(_ notification: Notification) {
        dismissHandler(self)
    }
    
}
#endif
