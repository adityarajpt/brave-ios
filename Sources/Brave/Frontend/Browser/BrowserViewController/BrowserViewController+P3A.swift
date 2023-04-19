// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Preferences
import Growth
import Data
import BraveShields
import BraveCore
import Shared

extension BrowserViewController {
  
  func maybeRecordInitialShieldsP3A() {
    if Preferences.Shields.initialP3AStateReported.value { return }
    defer { Preferences.Shields.initialP3AStateReported.value = true }
    recordShieldsUpdateP3A(shield: .AdblockAndTp)
    recordShieldsUpdateP3A(shield: .FpProtection)
  }
  
  func recordShieldsUpdateP3A(shield: BraveShield) {
    let buckets: [Bucket] = [
      0,
      .r(1...5),
      .r(6...10),
      .r(11...20),
      .r(21...30),
      .r(31...),
    ]
    switch shield {
    case .AdblockAndTp:
      // Q51 On how many domains has the user set the adblock setting to be lower (block less) than the default?
      let adsBelowGlobalCount = Domain.totalDomainsWithAdblockShieldsLoweredFromGlobal()
      UmaHistogramRecordValueToBucket("Brave.Shields.DomainAdsSettingsBelowGlobal", buckets: buckets, value: adsBelowGlobalCount)
      // Q52 On how many domains has the user set the adblock setting to be higher (block more) than the default?
      let adsAboveGlobalCount = Domain.totalDomainsWithAdblockShieldsIncreasedFromGlobal()
      UmaHistogramRecordValueToBucket("Brave.Shields.DomainAdsSettingsAboveGlobal", buckets: buckets, value: adsAboveGlobalCount)
    case .FpProtection:
      // Q53 On how many domains has the user set the FP setting to be lower (block less) than the default?
      let fingerprintingBelowGlobalCount = Domain.totalDomainsWithFingerprintingProtectionLoweredFromGlobal()
      UmaHistogramRecordValueToBucket("Brave.Shields.DomainFingerprintSettingsBelowGlobal", buckets: buckets, value: fingerprintingBelowGlobalCount)
      // Q54 On how many domains has the user set the FP setting to be higher (block more) than the default?
      let fingerprintingAboveGlobalCount = Domain.totalDomainsWithFingerprintingProtectionIncreasedFromGlobal()
      UmaHistogramRecordValueToBucket("Brave.Shields.DomainFingerprintSettingsAboveGlobal", buckets: buckets, value: fingerprintingAboveGlobalCount)
    case .AllOff, .NoScript:
      break
    }
  }
  
  func recordDataSavedP3A(change: Int) {
    var dataSavedStorage = P3ATimedStorage<Int>.dataSavedStorage
    dataSavedStorage.add(value: change * BraveGlobalShieldStats.shared.averageBytesSavedPerItem, to: Date())
    
    // Values are in MB
    let buckets: [Bucket] = [
      0,
      .r(1...50),
      .r(51...100),
      .r(101...200),
      .r(201...400),
      .r(401...700),
      .r(701...1500),
      .r(1501...)
    ]
    let amountOfDataSavedInMB = dataSavedStorage.combinedValue / 1024 / 1024
    UmaHistogramRecordValueToBucket("Brave.Savings.BandwidthSavingsMB", buckets: buckets, value: amountOfDataSavedInMB)
  }
  
  func recordVPNUsageP3A(vpnEnabled: Bool) {
    let usage = P3AFeatureUsage.braveVPNUsage
    var braveVPNDaysInMonthUsedStorage = P3ATimedStorage<Int>.braveVPNDaysInMonthUsedStorage
    
    if vpnEnabled {
      usage.recordUsage()
      braveVPNDaysInMonthUsedStorage.replaceTodaysRecordsIfLargest(value: 1)
    } else {
      usage.recordHistogram()
    }
    
    UmaHistogramRecordValueToBucket(
      "Brave.VPN.DaysInMonthUsed",
      buckets: [
        0,
        1,
        2,
        .r(3...5),
        .r(6...10),
        .r(11...15),
        .r(16...20),
        .r(21...),
      ],
      value: braveVPNDaysInMonthUsedStorage.combinedValue
    )
    
    usage.recordReturningUsageMetric()
  }
  
  func recordAccessibilityDisplayZoomEnabledP3A() {
    // Accessibility Q1 New P3A iOS - Do you have iOS display zoom enabled?
    let isDisplayZoomEnabled = UIScreen.main.scale < UIScreen.main.nativeScale
    
    UmaHistogramBoolean("Brave.Accessibility.DisplayZoomEnabled", isDisplayZoomEnabled)
  }
  
  func recordAccessibilityDocumentsDirectorySizeP3A() {
    // Accessibility Q4 New P3A iOS - Documents directory size
    func fetchDocumentsAndDataSize() -> Int? {
      let fileManager = FileManager.default
      
      guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
      }

      do {
        if let documentsDirectorySize = try fileManager.directorySize(at: documentsDirectory){
          return Int(documentsDirectorySize / 1024 / 1024)
        } else {
          return nil
        }
      } catch {
        return nil
      }
    }
    
    let buckets: [Bucket] = [
      .r(0...50),
      .r(50...200),
      .r(200...500),
      .r(500...1000),
      .r(1000...),
    ]
    
    if let documentsSize = fetchDocumentsAndDataSize() {
      UmaHistogramRecordValueToBucket("Brave.Accessibility.DocumentDirectorySize", buckets: buckets, value: documentsSize)
    }
  }

  func recordGeneralBottomBarLocationP3A() {
    enum Answer: Int, CaseIterable {
      case top = 0
      case bottom = 1
    }
    
    // General Q1 New P3A iOS - Bottom Bar Location
    let answer: Answer = Preferences.General.isUsingBottomBar.value ? .bottom : .top
    UmaHistogramEnumeration("Brave.General.BottomBarLocation", sample: answer)
  }
  
  func recordTimeBasedNumberReaderModeUsedP3A(activated: Bool) {
    var storage = P3ATimedStorage<Int>.readerModeActivated
    if activated {
      storage.add(value: 1, to: Date())
    }
    UmaHistogramRecordValueToBucket(
      "Brave.TimeBased.NumberReaderModeActivated",
      buckets: [
        0,
        .r(1...5),
        .r(5...20),
        .r(20...50),
        .r(51...)
      ],
      value: storage.combinedValue
    )
  }
}

extension P3AFeatureUsage {
  fileprivate static let braveVPNUsage: Self = .init(
    name: "vpn-usage",
    histogram: "Brave.VPN.LastUsageTime",
    returningUserHistogram: "Brave.VPN.NewUserReturning"
  )
}

extension P3ATimedStorage where Value == Int {
  /// Holds timed storage for question 21 (`Brave.Savings.BandwidthSavingsMB`)
  fileprivate static var dataSavedStorage: Self { .init(name: "data-saved", lifetimeInDays: 7) }
  fileprivate static var braveVPNDaysInMonthUsedStorage: Self { .init(name: "vpn-days-in-month-used", lifetimeInDays: 30) }
  fileprivate static var readerModeActivated: Self { .init(name: "reader-mode-activated", lifetimeInDays: 7) }
}
