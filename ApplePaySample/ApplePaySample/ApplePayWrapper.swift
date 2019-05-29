//
//  ApplePayWrapper.swift
//  ApplePaySample
//
//  Created by Sho Ito on 2019/05/22.
//  Copyright © 2019 aryzae. All rights reserved.
//

import Foundation
import PassKit

/// 静的な設定変数の集まり
/// 通貨
private let currencyCode: String = "JPY"
/// 国コード
private let countryCode: String = "JP"
/// AppleDeveloperで登録したID
private let merchantIdentifier: String = ""
/// 決済時に使用するプロトロコル
private let merchantCapabilities: PKMerchantCapability = .capability3DS
/// ApplePayの支払いの対象とするカードブランド
/// (iOSのversionによって指定できるものが異なる)
private let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard]
/// 請求先の情報。指定している情報は、ユーザがApplePay認証完了後のpaymentに含まれて入手できる
/// 指定した項目は、ユーザにとって必須入力となる。(実用上クレカが代理請求するので、指定しなくても困らない)
private let billingAddressFields: [PKAddressField] = []
/// 配送先の情報。指定している情報は、ユーザがApplePay認証完了後のpaymentに含まれて入手できる
/// 指定した項目は、ユーザにとって必須入力となる。
private let shippingAddressFields: PKAddressField = .all

private enum ShippingMethod: String, CaseIterable {
    case yamato
    case sagawa
    case japanPost

    func create() -> PKShippingMethod {
        let method: PKShippingMethod
        switch self {
        case .yamato:
            method = PKShippingMethod(label: "クロネコヤマト", amount: 600)
            method.identifier = rawValue
            method.detail = "メール便"
        case .sagawa:
            method = PKShippingMethod(label: "佐川急便", amount: 600)
            method.identifier = rawValue
            method.detail = "メール便"
        case .japanPost:
            method = PKShippingMethod(label: "日本郵便", amount: 600)
            method.identifier = rawValue
            method.detail = "メール便"
        }

        return method
    }
}

final class ApplePayWrapper: NSObject {
    enum Action {
        case cancel
        case authorize
    }
    struct Item {
        var product: String
        var price: NSDecimalNumber
    }
    // MARK: - typealias
    typealias Completion = ((PKPaymentAuthorizationStatus) -> Void)

    // MARK: - public property
    private(set) var productItems: [Item] = []
    private(set) var optionItems: [Item] = []
    private var action: Action = .cancel
    // MARK: private property
    private var didFinishHandler: ((PKPaymentAuthorizationViewController, ApplePayWrapper.Action) -> Void)?
    private var didAuthorizePaymentHandler: ((PKPaymentAuthorizationViewController, PKPayment, Completion) -> Void)?

    // MARK: - static method
    static func canMakePayments() -> Bool {
        return PKPaymentAuthorizationViewController.canMakePayments()
    }

    static func canMakePaymentsUsingNetworks() -> Bool {
        return PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: supportedNetworks)
    }

    // MARK: - public method
    func setProductItems(_ productItems: [Item], optionItems: [Item]? = nil) {
        self.productItems = productItems
        self.optionItems = optionItems ?? []
    }

    /// ApplePay決済のシートを表示するviewControllerを生成
    ///
    /// - Returns: 正常に作成できれば、PKPaymentAuthorizationViewControllerを返す。
    func createPaymentAuthorizationViewController() -> PKPaymentAuthorizationViewController? {
        guard let paymentRequest = createPaymentRequest() else { return nil }
        guard let paymentAuthorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) else {
            return nil
        }
        paymentAuthorizationViewController.delegate = self

        return paymentAuthorizationViewController
    }

    func setDidFinish(_ handler: @escaping (PKPaymentAuthorizationViewController, ApplePayWrapper.Action) -> Void) {
        self.didFinishHandler = handler
    }

    func setDidAuthorizePayment(_ handler: @escaping (PKPaymentAuthorizationViewController, PKPayment, Completion) -> Void) {
        self.didAuthorizePaymentHandler = handler
    }

    // MARK: - private method
    private func createPaymentRequest() -> PKPaymentRequest? {
        let shippingMethods = ShippingMethod.allCases.map { $0.create() }

        // 基本情報
        let paymentRequest = PKPaymentRequest()
        paymentRequest.currencyCode = currencyCode
        paymentRequest.countryCode = countryCode
        paymentRequest.merchantIdentifier = merchantIdentifier
        paymentRequest.merchantCapabilities = merchantCapabilities
        paymentRequest.supportedNetworks = supportedNetworks

        // 商品名と金額
        let paymentSummaryItems = createPaymentSummaryItems(include: shippingMethods.first)
        guard !paymentSummaryItems.isEmpty else { return nil }
        paymentRequest.paymentSummaryItems = paymentSummaryItems

        // 配送先(オプション)
        paymentRequest.requiredShippingAddressFields = shippingAddressFields
        // 配送方法(オプション)
        paymentRequest.shippingMethods = shippingMethods

        return paymentRequest
    }

    private func createPaymentSummaryItems(include shippingMethod: PKShippingMethod?) -> [PKPaymentSummaryItem] {
        var summaryItems = productItems.map { PKPaymentSummaryItem(label: $0.product, amount: $0.price) }

        // 配送料金
        if let shippingMethod = shippingMethod {
            let shippingItem = PKPaymentSummaryItem(label: "配送料", amount: shippingMethod.amount)
            summaryItems.append(shippingItem)
        }

        // クーポン割引、ポイント使用
        _ = optionItems.map { PKPaymentSummaryItem(label: $0.product, amount: $0.price) }.forEach { summaryItems.append($0) }

        // 合計 (labelはアルファベットだと全て大文字で表示される)
        let amountPrice = summaryItems.map { $0.amount.intValue }.reduce(0, { $0 + $1 })
        let amountItem = PKPaymentSummaryItem(label: "スーパー・aryzae", amount: NSDecimalNumber(integerLiteral: amountPrice))
        summaryItems.append(amountItem)

        return summaryItems
    }
}

// MARK: PKPaymentAuthorizationViewControllerDelegate
extension ApplePayWrapper: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        didFinishHandler?(controller, action)
        action = .cancel
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        paymentAuthorizationController(controller, didAuthorizePayment: payment) { (authorizationStatus) in
            completion(authorizationStatus)
        }
    }

    @available(iOS 11.0, *)
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        paymentAuthorizationController(controller, didAuthorizePayment: payment) { (authorizationStatus) in
            completion(PKPaymentAuthorizationResult(status: authorizationStatus, errors: nil))
        }
    }

    private func paymentAuthorizationController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        action = .authorize
        didAuthorizePaymentHandler?(controller, payment, completion)
    }
}
