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
private struct ApplePaySetting {
    /// 通貨
    let currencyCode = "JPY"
    /// 国コード
    let countryCode = "JP"
    /// AppleDeveloperで登録したID
    let merchantIdentifier = ""
    /// ApplePayの支払いの対象とするカードブランド
    /// (iOSのversionによって指定できるものが異なる)
    let paymentNetworks: [PKPaymentNetwork] = [.visa, .masterCard]
    /// 請求先の情報。指定している情報は、ユーザがApplePay認証完了後のpaymentに含まれて入手できる
    /// 指定した項目は、ユーザにとって必須入力となる。(実用上クレカが代理請求するので、指定しなくても困らない)
    let billingAddressFields: [PKAddressField] = []
    /// 配送先の情報。指定している情報は、ユーザがApplePay認証完了後のpaymentに含まれて入手できる
    /// 指定した項目は、ユーザにとって必須入力となる。
    let shippingAddressFields: [PKAddressField] = [.all]
}

final class ApplePayWrapper {

}
