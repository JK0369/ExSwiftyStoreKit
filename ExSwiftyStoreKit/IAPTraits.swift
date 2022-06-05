//
//  IAPTraits.swift
//  ExSwiftyStoreKit
//
//  Created by 김종권 on 2022/06/05.
//

import StoreKit
import SwiftyStoreKit
import RxSwift
import RxCocoa

enum IAPError: Error {
  case invalidProductID(String)
  case unknown(Error?)
  case failedRestorePurchases([(SKError, String?)])
  case noRetrievedProduct
  case noRestorePurchases
  case noProducts
  case canceledPayment
}

// Interface
protocol IAPTraits {
  static var iapService: IAPServiceType { get }
}

extension IAPTraits {
  static var iapService: IAPServiceType { IAPService.shared }
}

// Service
protocol IAPServiceType {
  func getPaymentStateObservable() -> Observable<SKPaymentTransactionState>
  func getLocalPriceObservable(productID: String) -> Observable<String>
  func restorePurchaseObservable() -> Observable<Void>
  func purchase(productID: String) -> Observable<Void>
}

private final class IAPService: IAPServiceType {
  static let shared = IAPService()
  
  private init() {}
  
  func getPaymentStateObservable() -> Observable<SKPaymentTransactionState> {
    .create { observer in
      SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
        for purchase in purchases {
          switch purchase.transaction.transactionState {
          case .purchased, .restored:
            SwiftyStoreKit.finishTransaction(purchase.transaction)
          default:
            break
          }
          observer.onNext(purchase.transaction.transactionState)
        }
      }
      return Disposables.create()
    }
  }
  
  func getLocalPriceObservable(productID: String) -> Observable<String> {
    .create { observer in
      SwiftyStoreKit.retrieveProductsInfo([productID]) { result in
        if let product = result.retrievedProducts.first {
          let priceString = product.localizedPrice ?? ""
          print("Product: \(product.localizedDescription), price: \(priceString)")
          observer.onNext(priceString)
        } else if let invalidProductId = result.invalidProductIDs.first {
          print("Invalid product identifier: \(invalidProductId)")
          observer.onError(IAPError.invalidProductID(invalidProductId))
        } else {
          print("Error: \(String(describing: result.error))")
          observer.onError(IAPError.unknown(result.error))
        }
      }
      return Disposables.create()
    }
  }
  
  func restorePurchaseObservable() -> Observable<Void> {
    .create { observer in
      SwiftyStoreKit.restorePurchases(atomically: true) { results in
        if results.restoreFailedPurchases.count > 0 {
          print("Restore Failed: \(results.restoreFailedPurchases)")
          observer.onError(IAPError.failedRestorePurchases(results.restoreFailedPurchases))
        } else if results.restoredPurchases.count > 0 {
          print("Restore Success: \(results.restoredPurchases)")
          observer.onNext(())
        } else {
          observer.onError(IAPError.noRestorePurchases)
        }
      }
      return Disposables.create()
    }
  }
  
  func purchase(productID: String) -> Observable<Void> {
    .create { observer in
      SwiftyStoreKit.purchaseProduct(productID, quantity: 1, atomically: true) { result in
        switch result {
        case .success:
          observer.onNext(())
        case .error(let error):
          switch error.code {
          case .unknown:
            print("Unknown error. Please contact support")
          case .clientInvalid:
            print("Not allowed to make the payment")
          case .paymentCancelled:
            observer.onError(IAPError.canceledPayment)
          case .paymentInvalid:
            print("The purchase identifier was invalid")
          case .paymentNotAllowed:
            print("The device is not allowed to make the payment")
          case .storeProductNotAvailable:
            print("The product is not available in the current storefront")
          case .cloudServicePermissionDenied:
            print("Access to cloud service information is not allowed")
          case .cloudServiceNetworkConnectionFailed:
            print("Could not connect to the network")
          case .cloudServiceRevoked:
            print("User has revoked permission to use this cloud service")
          default:
            print((error as NSError).localizedDescription)
          }
        }
      }
      return Disposables.create()
    }
  }
}
