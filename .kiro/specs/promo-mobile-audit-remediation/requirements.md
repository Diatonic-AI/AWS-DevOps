# Requirements Document

## Introduction

This document specifies requirements for remediating mobile performance, accessibility, security, and SEO issues identified in the Lighthouse audit of promo.mmptoledo.com, an AWS Amplify-hosted single-page application. The system must achieve target scores (Performance ≥80, Accessibility ≥95, Best Practices ≥95, SEO ≥95) while maintaining all existing functionality including forms, OTP flow, analytics attribution, reCAPTCHA, cookie consent, routing, and lead submission.

## Glossary

- **Promo Site**: The promo.mmptoledo.com marketing website hosted on AWS Amplify
- **LCP (Largest Contentful Paint)**: Core Web Vital measuring when the largest content element becomes visible
- **FCP (First Contentful Paint)**: Metric measuring when first content renders
- **TBT (Total Blocking Time)**: Sum of time between FCP and Time to Interactive where main thread was blocked
- **CLS (Cumulative Layout Shift)**: Metric measuring visual stability during page load
- **CSP (Content Security Policy)**: HTTP header that helps prevent XSS and other code injection attacks
- **HSTS (HTTP Strict Transport Security)**: HTTP header forcing browsers to use HTTPS
- **COOP (Cross-Origin-Opener-Policy)**: HTTP header providing process isolation for security
- **reCAPTCHA**: Google's bot protection service currently loading on initial page render
- **Hero Video**: The 1.66MB MP4 video currently loading on initial page render
- **Cookie Banner**: The consent dialog requiring accessible naming and contrast fixes
- **GTM (Google Tag Manager)**: Third-party analytics tag management system
- **Lighthouse**: Google's automated tool for measuring web quality metrics

## Requirements

### Requirement 1: SEO Indexing Enablement

**User Story:** As a marketing stakeholder, I want the production site to be crawlable and indexable by search engines, so that organic traffic can discover our content.

#### Acceptance Criteria

1. WHEN the Promo Site is deployed to production environment THEN the System SHALL remove the noindex and nofollow meta directives
2. WHEN the Promo Site is deployed to preview or staging environments THEN the System SHALL retain the noindex and nofollow meta directives
3. WHEN a search engine crawler requests robots.txt THEN the System SHALL allow crawling and provide a sitemap reference
4. WHEN the Promo Site serves the production homepage THEN the System SHALL include a valid canonical URL
5. WHEN a Lighthouse SEO audit runs against production THEN the System SHALL achieve a score of at least 95

### Requirement 2: Video Asset Optimization

**User Story:** As a mobile user, I want the site to load quickly without downloading large video files I may not watch, so that I can access content faster on limited bandwidth.

#### Acceptance Criteria

1. WHEN the Promo Site initial page loads THEN the System SHALL NOT download the full 1.66MB MP4 video file
2. WHEN the hero video element renders THEN the System SHALL display an optimized poster image with explicit width and height attributes
3. WHEN the hero video enters the viewport OR a user initiates playback THEN the System SHALL load the video asset
4. WHEN the hero video is configured THEN the System SHALL use preload="metadata" instead of preload="auto"
5. WHERE a mobile viewport is detected THEN the System SHALL serve a mobile-optimized video variant with reduced file size

### Requirement 3: reCAPTCHA Deferred Loading

**User Story:** As a mobile user, I want the site to load without heavy bot-protection scripts blocking the main thread, so that I can interact with content immediately while still being protected from spam.

#### Acceptance Criteria

1. WHEN the Promo Site initial page loads THEN the System SHALL NOT load reCAPTCHA scripts
2. WHEN a user focuses on a form field OR initiates form submission THEN the System SHALL load reCAPTCHA scripts exactly once
3. WHEN reCAPTCHA scripts are loaded multiple times in a session THEN the System SHALL prevent duplicate script injection using a single-flight guard
4. WHEN a form is submitted with deferred reCAPTCHA THEN the System SHALL validate the submission successfully
5. WHEN Lighthouse measures Total Blocking Time THEN the System SHALL show reduced main-thread blocking compared to baseline

### Requirement 4: Third-Party Script Consent Gating

**User Story:** As a privacy-conscious user, I want analytics and tracking scripts to load only after I provide consent, so that my browsing is not tracked without permission.

#### Acceptance Criteria

1. WHEN the Promo Site initial page loads THEN the System SHALL NOT load GTM or Facebook Pixel scripts
2. WHEN a user provides cookie consent THEN the System SHALL load GTM and Facebook Pixel scripts
3. WHEN analytics scripts load after consent THEN the System SHALL preserve attribution data correctly
4. WHEN a user denies consent THEN the System SHALL NOT load tracking scripts during the session
5. WHEN Lighthouse measures initial payload THEN the System SHALL show reduced bytes transferred compared to baseline

### Requirement 5: Render-Blocking Resource Elimination

**User Story:** As a mobile user, I want critical content to render quickly without waiting for non-essential scripts, so that I can see and interact with the page faster.

#### Acceptance Criteria

1. WHEN the service worker registration executes THEN the System SHALL defer execution until after the load or idle event
2. WHEN critical CSS is delivered THEN the System SHALL include only above-the-fold styles in the critical path
3. WHEN the Promo Site connects to external origins THEN the System SHALL include preconnect hints for cognito-identity.us-east-2.amazonaws.com and fonts.gstatic.com
4. WHEN Lighthouse measures LCP THEN the System SHALL show improved discovery time compared to baseline
5. WHEN the Promo Site loads THEN the System SHALL eliminate render-blocking requests identified in the audit

### Requirement 6: Image Asset Optimization

**User Story:** As a mobile user, I want images to load at appropriate sizes without causing layout shifts, so that the page is stable and bandwidth-efficient.

#### Acceptance Criteria

1. WHEN the mmp-logo.png image is served THEN the System SHALL provide an appropriately sized asset matching rendered dimensions
2. WHEN image elements render THEN the System SHALL include explicit width and height attributes
3. WHERE modern image format support exists THEN the System SHALL serve WebP or AVIF formats with fallbacks
4. WHEN responsive images are needed THEN the System SHALL use srcset and sizes attributes
5. WHEN Lighthouse measures CLS THEN the System SHALL show no layout shift from images

### Requirement 7: Bundle Size Reduction

**User Story:** As a developer, I want production bundles to exclude unused code and split heavy dependencies, so that users download only what they need.

#### Acceptance Criteria

1. WHEN the production build executes THEN the System SHALL exclude development-only code chunks
2. WHEN AWS SDK or Amplify code is bundled THEN the System SHALL code-split these dependencies to load only on routes requiring them
3. WHEN Tailwind CSS is processed THEN the System SHALL purge unused classes based on content globs
4. WHEN Lighthouse measures unused JavaScript THEN the System SHALL show at least 40% reduction in unused bytes
5. WHEN the vendor bundle is analyzed THEN the System SHALL show reduced size compared to baseline

### Requirement 8: Cookie Banner Accessibility

**User Story:** As a screen reader user, I want the cookie consent dialog to be properly announced and navigable, so that I can make informed consent decisions.

#### Acceptance Criteria

1. WHEN the cookie banner dialog renders THEN the System SHALL include an accessible name via aria-labelledby or aria-label
2. WHEN the cookie banner dialog opens THEN the System SHALL manage focus appropriately without creating a focus trap
3. WHEN a user navigates the cookie banner with keyboard THEN the System SHALL provide a logical tab order
4. WHEN interactive elements receive focus THEN the System SHALL display visible focus indicators
5. WHEN Lighthouse measures accessibility THEN the System SHALL pass the dialog naming audit

### Requirement 9: Color Contrast Compliance

**User Story:** As a user with low vision, I want all text and interactive elements to have sufficient contrast, so that I can read and interact with all content.

#### Acceptance Criteria

1. WHEN text is displayed on the Promo Site THEN the System SHALL meet WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text)
2. WHEN links or buttons use the text-mmp-orange color THEN the System SHALL ensure sufficient contrast against background colors
3. WHEN interactive elements are styled THEN the System SHALL NOT rely on color alone to convey information
4. WHEN links are displayed THEN the System SHALL maintain underline decoration or other non-color indicators
5. WHEN Lighthouse measures accessibility THEN the System SHALL pass all contrast audits

### Requirement 10: Keyboard Navigation Support

**User Story:** As a keyboard-only user, I want to skip repetitive navigation and understand page structure, so that I can efficiently navigate to main content.

#### Acceptance Criteria

1. WHEN the Promo Site loads THEN the System SHALL provide a skip-to-content link as the first focusable element
2. WHEN the page structure is analyzed THEN the System SHALL include a main landmark element
3. WHEN headings are used THEN the System SHALL follow a logical hierarchy (h1, h2, h3, etc.)
4. WHEN a user presses Tab from page load THEN the System SHALL focus the skip link first
5. WHEN Lighthouse measures accessibility THEN the System SHALL pass the bypass mechanism audit

### Requirement 11: Video Accessibility

**User Story:** As a deaf or hard-of-hearing user, I want video content to include captions or transcripts, so that I can access the information conveyed in the video.

#### Acceptance Criteria

1. WHEN the hero video element is rendered THEN the System SHALL include a track element with kind="captions"
2. WHEN captions are provided THEN the System SHALL reference a valid WebVTT file
3. WHERE captions are not feasible THEN the System SHALL provide an accessible transcript link
4. WHEN Lighthouse measures accessibility THEN the System SHALL pass the video captions audit
5. WHEN a user enables captions THEN the System SHALL display synchronized text overlays

### Requirement 12: HTTP Security Headers

**User Story:** As a security engineer, I want the site to implement defense-in-depth security headers, so that users are protected from common web vulnerabilities.

#### Acceptance Criteria

1. WHEN the Promo Site serves responses THEN the System SHALL include Strict-Transport-Security header with appropriate max-age
2. WHEN the Promo Site serves responses THEN the System SHALL include X-Content-Type-Options: nosniff header
3. WHEN the Promo Site serves responses THEN the System SHALL include Referrer-Policy: strict-origin-when-cross-origin header
4. WHEN the Promo Site serves responses THEN the System SHALL include Permissions-Policy header disabling unused features
5. WHEN Lighthouse measures best practices THEN the System SHALL pass security header audits

### Requirement 13: Clickjacking Protection

**User Story:** As a user, I want the site to prevent malicious embedding in iframes, so that I am protected from clickjacking attacks.

#### Acceptance Criteria

1. WHEN the Promo Site serves responses THEN the System SHALL include Content-Security-Policy frame-ancestors directive set to 'none' or 'self'
2. WHERE legacy browser support is needed THEN the System SHALL include X-Frame-Options: DENY or SAMEORIGIN header
3. WHEN an attacker attempts to embed the site in an iframe THEN the System SHALL block the embedding
4. WHEN Lighthouse measures best practices THEN the System SHALL pass clickjacking protection audits
5. WHEN legitimate embedding is required THEN the System SHALL document and configure appropriate frame-ancestors values

### Requirement 14: Cross-Origin Isolation

**User Story:** As a security engineer, I want the site to implement process isolation, so that cross-origin attacks are mitigated.

#### Acceptance Criteria

1. WHEN the Promo Site serves responses THEN the System SHALL include Cross-Origin-Opener-Policy: same-origin header
2. WHEN authentication popups or OAuth flows are used THEN the System SHALL verify COOP does not break functionality
3. WHEN Lighthouse measures best practices THEN the System SHALL pass COOP audits
4. WHERE COOP causes breakage THEN the System SHALL document the issue and implement a safe alternative
5. WHEN cross-origin resources are loaded THEN the System SHALL verify compatibility with COOP policy

### Requirement 15: Content Security Policy

**User Story:** As a security engineer, I want a strict Content Security Policy to prevent XSS attacks, so that user data and sessions are protected.

#### Acceptance Criteria

1. WHEN the Promo Site serves responses THEN the System SHALL include a Content-Security-Policy header
2. WHEN CSP is initially deployed THEN the System SHALL use Content-Security-Policy-Report-Only mode for validation
3. WHEN CSP sources are defined THEN the System SHALL allow only required origins (self, google, recaptcha, gtm, facebook, s3, cognito, appsync)
4. WHEN CSP is validated without violations THEN the System SHALL switch from report-only to enforcement mode
5. WHEN Lighthouse measures best practices THEN the System SHALL pass CSP audits

### Requirement 16: Trusted Types Strategy

**User Story:** As a security engineer, I want to prevent DOM-based XSS through Trusted Types, so that injection attacks are blocked at the browser level.

#### Acceptance Criteria

1. WHEN the application code is ready for Trusted Types THEN the System SHALL include require-trusted-types-for 'script' in CSP
2. WHEN Trusted Types are not yet implemented THEN the System SHALL document a staged rollout plan
3. WHEN Trusted Types are enforced THEN the System SHALL ensure all DOM sinks use trusted type objects
4. WHEN third-party scripts are used THEN the System SHALL verify compatibility with Trusted Types policy
5. WHERE Trusted Types cause breakage THEN the System SHALL implement necessary code changes before enforcement

### Requirement 17: Real User Monitoring

**User Story:** As a performance engineer, I want to collect real-user performance metrics, so that I can validate improvements and detect regressions.

#### Acceptance Criteria

1. WHEN the Promo Site loads in a user's browser THEN the System SHALL measure Core Web Vitals (LCP, FID/INP, CLS)
2. WHEN Core Web Vitals are measured THEN the System SHALL report metrics to Google Analytics or a dedicated endpoint
3. WHEN RUM data is collected THEN the System SHALL respect user privacy and consent preferences
4. WHEN performance regressions occur THEN the System SHALL provide alerting through the RUM system
5. WHEN Lighthouse shows "No Data" for real users THEN the System SHALL populate the panel with RUM metrics

### Requirement 18: Atomic Deployment and Rollback

**User Story:** As a developer, I want each fix deployed in small reversible commits, so that issues can be quickly identified and rolled back.

#### Acceptance Criteria

1. WHEN a fix is completed THEN the System SHALL commit changes with a precise conventional commit message
2. WHEN multiple fixes are implemented THEN the System SHALL create separate commits for each logical change
3. WHEN a commit is made THEN the System SHALL include validation evidence (build pass, tests pass, targeted check)
4. WHEN a deployment causes issues THEN the System SHALL support rollback to the previous commit
5. WHEN commits are reviewed THEN the System SHALL show clear scope and impact for each change

### Requirement 19: Baseline and Progress Tracking

**User Story:** As a project manager, I want documented baseline metrics and progress tracking, so that I can verify improvements and report status.

#### Acceptance Criteria

1. WHEN the remediation project starts THEN the System SHALL capture baseline Lighthouse reports for mobile
2. WHEN major optimization phases complete THEN the System SHALL capture intermediate Lighthouse reports
3. WHEN the project completes THEN the System SHALL capture final Lighthouse reports showing improvements
4. WHEN reports are stored THEN the System SHALL organize them in /reports/lighthouse/ with timestamps
5. WHEN progress is tracked THEN the System SHALL maintain a task table in /docs/audits/mobile-fix-plan.md with status updates

### Requirement 20: Functionality Preservation

**User Story:** As a business stakeholder, I want all existing functionality to work after optimizations, so that lead generation and user flows are not disrupted.

#### Acceptance Criteria

1. WHEN optimizations are deployed THEN the System SHALL preserve form submission functionality
2. WHEN optimizations are deployed THEN the System SHALL preserve OTP flow functionality
3. WHEN optimizations are deployed THEN the System SHALL preserve analytics attribution
4. WHEN optimizations are deployed THEN the System SHALL preserve reCAPTCHA bot protection
5. WHEN optimizations are deployed THEN the System SHALL preserve cookie consent logic and routing
