import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testPermissionDescriptionsAndTransportPolicy() {
    let info = Bundle.main.infoDictionary ?? [:]
    for key in ["NSFaceIDUsageDescription", "NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"] {
      let value = info[key] as? String ?? ""
      XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
    }
    let transport = info["NSAppTransportSecurity"] as? [String: Any] ?? [:]
    XCTAssertFalse(transport["NSAllowsArbitraryLoads"] as? Bool ?? false)
    XCTAssertEqual(info["CFBundleDisplayName"] as? String, "ASTHA RAVEN")
    XCTAssertEqual(info["BGTaskSchedulerPermittedIdentifiers"] as? [String], ["com.astharaven.asthaApp.outbox"])
    XCTAssertEqual(info["UIBackgroundModes"] as? [String], ["fetch"])
  }

}
