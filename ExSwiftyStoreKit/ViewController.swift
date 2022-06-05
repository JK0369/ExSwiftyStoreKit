//
//  ViewController.swift
//  ExSwiftyStoreKit
//
//  Created by 김종권 on 2022/06/05.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController, IAPTraits {
  private let restoreButton: UIButton = {
    let button = UIButton()
    button.setTitle("restore", for: .normal)
    button.setTitleColor(.systemBlue, for: .normal)
    button.setTitleColor(.blue, for: .highlighted)
    button.addTarget(self, action: #selector(didTapRestoreButton), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  private let colorButton: UIButton = {
    let button = UIButton()
    button.setTitle("RandomColor", for: .normal)
    button.setTitleColor(.systemBlue, for: .normal)
    button.setTitleColor(.blue, for: .highlighted)
    button.setTitleColor(.systemBlue.withAlphaComponent(0.3), for: .disabled)
    button.addTarget(self, action: #selector(didTapColorButton), for: .touchUpInside)
    button.isEnabled = false
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  private let buyButton: UIButton = {
    let button = UIButton()
    button.setTitle("Buy RandomColor", for: .normal)
    button.setTitleColor(.systemBlue, for: .normal)
    button.setTitleColor(.blue, for: .highlighted)
    button.setTitleColor(.systemBlue.withAlphaComponent(0.3), for: .disabled)
    button.addTarget(self, action: #selector(didTapBuyButton), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
  }()
  
  private let disposeBag = DisposeBag()
  private let productID = "some product id"
  private var canUseRandomColor = false {
    didSet {
      self.colorButton.isEnabled = self.canUseRandomColor
      self.buyButton.isEnabled = !self.colorButton.isEnabled
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.addSubview(self.restoreButton)
    self.view.addSubview(self.colorButton)
    self.view.addSubview(self.buyButton)
    
    NSLayoutConstraint.activate([
      self.restoreButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 60),
      self.restoreButton.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 30),
    ])
    NSLayoutConstraint.activate([
      self.colorButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
      self.colorButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
    ])
    NSLayoutConstraint.activate([
      self.buyButton.topAnchor.constraint(equalTo: self.colorButton.bottomAnchor, constant: 16),
      self.buyButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
    ])
    
    // binding
    Self.iapService.getPaymentStateObservable()
      .withUnretained(self)
      .subscribe(onNext: { ss, state in
        switch state {
        case .purchased, .restored:
          ss.canUseRandomColor = true
        default:
          ss.canUseRandomColor = false
        }
      })
      .disposed(by: self.disposeBag)

    Self.iapService.getLocalPriceObservable(productID: self.productID)
      .withUnretained(self)
      .subscribe(onNext: { ss, price in
        ss.buyButton.setTitle("Buy RandomColor (\(price)$)", for: .normal)
      })
      .disposed(by: self.disposeBag)

    guard UserDefaults.standard.bool(forKey: self.productID) == true else { return }
    self.canUseRandomColor = true
  }
  
  @objc private func didTapRestoreButton() {
    Self.iapService.restorePurchaseObservable()
      .withUnretained(self)
      .subscribe(onNext: { ss, _ in
        // UserDefaults로 해당 product 구입했는지 저장
        UserDefaults.standard.set(true, forKey: ss.productID)
        ss.canUseRandomColor = true
      })
      .disposed(by: self.disposeBag)
  }
  
  @objc private func didTapColorButton() {
    self.view.backgroundColor = UIColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
  }
  
  @objc private func didTapBuyButton() {
    Self.iapService.purchase(productID: self.productID)
      .withUnretained(self)
      .subscribe(onError: { print("error \($0)") })
      .disposed(by: self.disposeBag)
  }
}
