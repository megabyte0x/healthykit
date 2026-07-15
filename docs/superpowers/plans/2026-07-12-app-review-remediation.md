# App Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve every issue in Apple's review of HealthSync 1.0 (4).

**Architecture:** Preserve the existing HealthKit and sync services. Add typed user-visible action feedback at the AppState/view boundary, update permission CTA copy, and document external metadata and release checks.

**Tech Stack:** SwiftUI, HealthKit, XCTest, Xcode

## Global Constraints

- The pre-permission CTA must use `Continue`, not `Connect Apple Health`.
- Every permission and manual-sync tap must produce visible progress or outcome feedback.
- App Store subtitle: `Private Health Data Sync`.

### Task 1: Compliance copy and feedback model

**Files:** `Tests/HealthSyncTests/APIClientTests.swift`, `HealthSync/Views/DashboardView.swift`, `HealthSync/AppState.swift`

- [ ] Write failing expectations for `Continue` and typed feedback copy.
- [ ] Run tests and confirm the expected failure.
- [ ] Implement the feedback model and compliant button label.
- [ ] Run tests and confirm they pass.

### Task 2: Visible permission and sync outcomes

**Files:** `HealthSync/AppState.swift`, `HealthSync/Views/OnboardingView.swift`, `HealthSync/Views/DashboardView.swift`

- [ ] Set feedback on permission success, empty sync, successful sync, and errors.
- [ ] Render feedback in onboarding and Dashboard using the existing card/banner style.
- [ ] Confirm old permission CTA wording is absent from user-facing permission buttons.

### Task 3: Release metadata checklist and verification

**Files:** `docs/release/app-review-resubmission.md`

- [ ] Record the exact App Store Connect subtitle and screenshot changes.
- [ ] Record clean-install physical-device scenarios for permission and sync behavior.
- [ ] Run the full Swift tests and a Release build.
