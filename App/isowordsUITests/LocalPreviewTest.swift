//
//  LocalPreviewTest.swift
//  isowordsUITests
//
//  Created by Trevor Elkins on 6/13/24.
//

import Foundation
import XCTest
import Snapshotting
import SnapshottingTests

class LocalPreviewTest: PreviewTest {

  override func getApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["SWIFT_DEPENDENCIES_CONTEXT"] = "previewValue-8u2sy"
    return app
  }

  override func snapshotPreviews() -> [String]? {
    return nil
  }
    
  override func excludedSnapshotPreviews() -> [String]? {
    return nil
  }

  override func enableAccessibilityAudit() -> Bool {
    true
  }

  @available(iOS 17.0, *)
  override func auditType() -> XCUIAccessibilityAuditType {
    return .all
  }

  @available(iOS 17.0, *)
  override func handle(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
    return false
  }
}
