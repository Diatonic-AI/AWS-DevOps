# Implementation Plan

- [ ] 1. Phase 0: Baseline and Infrastructure Setup
  - Create directory structure for reports and documentation
  - Run baseline Lighthouse mobile audit against production and local build
  - Store baseline reports in /reports/lighthouse/ with timestamps
  - Create /docs/audits/mobile-fix-plan.md with task tracking table
  - Set up Vitest and fast-check for testing infrastructure
  - Configure Playwright for E2E testing
  - _Requirements: 19.1, 19.4_

- [ ] 1.1 Write property test for script loading idempotence
  - **Property 1: Script loading idempotence**
  - **Validates: Requirements 3.3**

- [ ] 2. Phase 1: SEO Indexing Enablement
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 2.1 Implement environment detection module
  - Create EnvironmentConfig interface and getEnvironmentConfig function
  - Detect environment from window.location.hostname or build-time env vars
  - Map promo.mmptoledo.com to production with allowIndexing: true
  - Map all other domains to preview/dev with allowIndexing: false
  - _Requirements: 1.1, 1.2_

- [ ] 2.2 Write unit tests for environment detection
  - Test production domain returns allowIndexing: true
  - Test preview domains return allowIndexing: false
  - Test localhost returns development mode
  - _Requirements: 1.1, 1.2_

- [ ] 2.3 Implement SEO meta manager component
  - Create SEOMetaManager interface with setRobotsDirective and setCanonicalUrl methods
  - Use react-helmet-async or similar for meta tag management
  - Inject index,follow meta on production
  - Inject noindex,nofollow meta on preview/dev
  - _Requirements: 1.1, 1.2, 1.4_

- [ ] 2.4 Write unit tests for SEO meta manager
  - Test correct meta tags injected for production
  - Test noindex meta tags injected for preview
  - Test canonical URL generation
  - _Requirements: 1.1, 1.2, 1.4_

- [ ] 2.5 Update robots.txt for production
  - Allow crawling in robots.txt
  - Add sitemap reference if available
  - Ensure file is served correctly
  - _Requirements: 1.3_

- [ ] 2.6 Validate SEO changes
  - Verify meta robots tags in view-source for both environments
  - Verify robots.txt is accessible and correct
  - Run Lighthouse SEO audit and verify score ≥ 95
  - _Requirements: 1.5_

- [ ] 3. Phase 2A: Video Asset Optimization
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 3.1 Create optimized poster image
  - Generate poster image from video frame
  - Optimize poster image (WebP/AVIF with JPEG fallback)
  - Ensure poster dimensions match video aspect ratio
  - _Requirements: 2.2_

- [ ] 3.2 Implement LazyVideo component
  - Create LazyVideoProps interface
  - Render video element with preload="metadata" and poster attribute
  - Add explicit width and height attributes to prevent CLS
  - Implement IntersectionObserver to detect viewport entry
  - Load video src on intersection or user click
  - Support mobileSrc prop for smaller mobile variant
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 3.3 Write unit tests for LazyVideo component
  - Test video does not load on initial render
  - Test video loads when entering viewport
  - Test poster image displays correctly
  - Test mobile variant selection based on viewport width
  - _Requirements: 2.1, 2.2, 2.3, 2.5_

- [ ] 3.4 Replace hero video with LazyVideo component
  - Update hero section to use LazyVideo
  - Provide poster image path
  - Provide mobile-optimized video variant if available
  - Verify no video download on initial page load
  - _Requirements: 2.1, 2.3_

- [ ] 3.5 Validate video optimization
  - Check network waterfall shows no video on initial load
  - Verify poster displays immediately
  - Verify video loads on scroll/interaction
  - Measure payload reduction (should see ~1.66MB savings)
  - _Requirements: 2.1_

- [ ] 4. Phase 2B: Deferred Script Loading Infrastructure
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 4.1 Implement DeferredScriptLoader class
  - Create ScriptLoaderOptions interface
  - Implement loadScript method with single-flight pattern
  - Track loaded scripts by ID to prevent duplicates
  - Return promise that resolves on load, rejects on error
  - Implement isLoaded method to check script status
  - _Requirements: 3.2, 3.3_

- [ ] 4.2 Write property test for script loading idempotence (if not done in 1.1)
  - **Property 1: Script loading idempotence**
  - **Validates: Requirements 3.3**

- [ ] 4.3 Write unit tests for DeferredScriptLoader
  - Test script injection on first call
  - Test script not re-injected on subsequent calls
  - Test error handling for failed loads
  - Test promise resolution/rejection
  - _Requirements: 3.2, 3.3_

- [ ] 4.4 Implement RecaptchaManager
  - Create RecaptchaManager interface with initialize, execute, isReady methods
  - Use DeferredScriptLoader to load reCAPTCHA on demand
  - Load on first form field focus or submit button click
  - Cache ready state to avoid redundant checks
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 4.5 Write unit tests for RecaptchaManager
  - Test no load on page init
  - Test load on form focus
  - Test single-load guard prevents duplicates
  - Test form submission with deferred load
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 4.6 Integrate RecaptchaManager with forms
  - Update form components to use RecaptchaManager
  - Attach focus listeners to form fields
  - Trigger reCAPTCHA load on first interaction
  - Ensure form submission waits for reCAPTCHA ready
  - _Requirements: 3.2, 3.4_

- [ ] 4.7 Validate reCAPTCHA optimization
  - Verify reCAPTCHA scripts absent from initial network requests
  - Verify scripts load on form interaction
  - Test form submission works correctly
  - Measure TBT reduction in Lighthouse
  - _Requirements: 3.1, 3.5_

- [ ] 5. Phase 2C: Consent-Gated Analytics
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 5.1 Implement ConsentManager integration
  - Create ConsentManager interface with hasConsent and onConsentChange methods
  - Integrate with existing cookie banner component
  - Store consent state in localStorage with expiry
  - Implement consent change callbacks
  - _Requirements: 4.2, 4.4_

- [ ] 5.2 Write unit tests for ConsentManager
  - Test consent state persistence
  - Test consent change callbacks
  - Test consent denial prevents script loading
  - _Requirements: 4.2, 4.4_

- [ ] 5.3 Defer GTM and Facebook Pixel loading
  - Remove GTM and FB Pixel from initial page load
  - Use DeferredScriptLoader to load after consent
  - Load GTM on analytics consent
  - Load FB Pixel on marketing consent
  - _Requirements: 4.1, 4.2_

- [ ] 5.4 Write unit tests for consent-gated analytics
  - Test scripts not loaded without consent
  - Test GTM loads after analytics consent
  - Test FB Pixel loads after marketing consent
  - _Requirements: 4.1, 4.2_

- [ ] 5.5 Validate analytics preservation
  - Test UTM parameters are preserved
  - Test attribution data flows correctly
  - Verify analytics events fire after consent
  - Measure initial payload reduction
  - _Requirements: 4.3, 4.5_

- [ ] 6. Phase 2D: Render-Blocking Elimination
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 6.1 Defer service worker registration
  - Move service worker registration to load or idle event
  - Ensure registration does not block initial render
  - Verify service worker still functions correctly
  - _Requirements: 5.1_

- [ ] 6.2 Add preconnect hints
  - Add preconnect for cognito-identity.us-east-2.amazonaws.com
  - Add preconnect for fonts.gstatic.com
  - Add dns-prefetch for other critical origins
  - Place hints in HTML head
  - _Requirements: 5.3_

- [ ] 6.3 Optimize critical CSS delivery
  - Ensure CSS is minified in production build
  - Verify only essential styles are in critical path
  - Consider extracting critical CSS if needed
  - _Requirements: 5.2_

- [ ] 6.4 Validate render-blocking elimination
  - Check Lighthouse for render-blocking resources
  - Verify LCP discovery time improved
  - Measure FCP and LCP improvements
  - _Requirements: 5.4, 5.5_

- [ ] 7. Phase 2E: Image Optimization
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 7.1 Implement OptimizedImage component
  - Create OptimizedImageProps interface
  - Generate srcset with multiple resolutions (1x, 2x, 3x)
  - Use picture element for WebP/AVIF with fallback
  - Always include explicit width and height attributes
  - Support loading="lazy" for below-fold images
  - _Requirements: 6.2, 6.3, 6.4_

- [ ] 7.2 Write property test for image dimension attributes
  - **Property 2: Image dimension attributes**
  - **Validates: Requirements 6.2**

- [ ] 7.3 Write unit tests for OptimizedImage
  - Test srcset generation
  - Test width/height attributes present
  - Test picture element with format fallbacks
  - Test lazy loading attribute
  - _Requirements: 6.2, 6.3, 6.4_

- [ ] 7.4 Optimize mmp-logo.png
  - Resize logo to appropriate dimensions
  - Convert to SVG if possible, or generate WebP/AVIF variants
  - Update logo usage with OptimizedImage component
  - _Requirements: 6.1_

- [ ] 7.5 Replace all images with OptimizedImage
  - Audit all img tags in the application
  - Replace with OptimizedImage component
  - Ensure all have explicit dimensions
  - Use lazy loading for below-fold images
  - _Requirements: 6.2, 6.4_

- [ ] 7.6 Validate image optimization
  - Verify image bytes reduced
  - Verify no CLS from images (Lighthouse CLS < 0.1)
  - Check all images have width/height
  - _Requirements: 6.5_

- [ ] 8. Phase 2F: Bundle Size Reduction
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 8.1 Configure code splitting
  - Implement route-based code splitting
  - Split AWS SDK and Amplify code to load only on routes needing them
  - Verify production build excludes dev-only chunks
  - _Requirements: 7.1, 7.2_

- [ ] 8.2 Optimize Tailwind CSS
  - Configure Tailwind content globs correctly
  - Ensure purge removes unused classes
  - Verify CSS size reduction in production build
  - _Requirements: 7.3_

- [ ] 8.3 Analyze and optimize vendor bundle
  - Run bundle analyzer to identify large dependencies
  - Remove unused libraries
  - Ensure tree-shaking works correctly
  - _Requirements: 7.5_

- [ ] 8.4 Validate bundle optimization
  - Compare bundle sizes to baseline
  - Verify at least 40% reduction in unused JS
  - Check Lighthouse unused JavaScript audit
  - _Requirements: 7.4_

- [ ] 9. Checkpoint - Verify performance improvements
  - Run Lighthouse performance audit
  - Verify Performance score ≥ 80 (stretch ≥ 90)
  - Verify LCP < 3.5s (stretch < 2.5s)
  - Verify total payload reduced by ≥ 40%
  - Ensure all tests pass, ask the user if questions arise

- [ ] 10. Phase 3A: Cookie Banner Accessibility
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 10.1 Implement AccessibleDialog component
  - Create AccessibleDialogProps interface
  - Use role="dialog" with aria-labelledby pointing to title
  - Implement focus management with focus-trap-react
  - Ensure visible focus indicators with :focus-visible styles
  - _Requirements: 8.1, 8.2, 8.4_

- [ ] 10.2 Write property test for focus indicator visibility
  - **Property 3: Focus indicator visibility**
  - **Validates: Requirements 8.4**

- [ ] 10.3 Write unit tests for AccessibleDialog
  - Test dialog has accessible name
  - Test focus management
  - Test keyboard navigation (tab order)
  - Test focus indicators visible
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 10.4 Update cookie banner to use AccessibleDialog
  - Replace existing dialog with AccessibleDialog component
  - Provide meaningful title for aria-labelledby
  - Ensure logical tab order through banner elements
  - _Requirements: 8.1, 8.3_

- [ ] 10.5 Validate cookie banner accessibility
  - Test with keyboard navigation
  - Test with screen reader (NVDA/JAWS/VoiceOver)
  - Run Lighthouse accessibility audit
  - _Requirements: 8.5_

- [ ] 11. Phase 3B: Color Contrast Compliance
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 11.1 Audit and fix text contrast issues
  - Identify all text elements with insufficient contrast
  - Adjust text-mmp-orange and other colors to meet WCAG AA (4.5:1 normal, 3:1 large)
  - Update color tokens in design system
  - _Requirements: 9.1, 9.2_

- [ ] 11.2 Write property test for text contrast compliance
  - **Property 4: Text contrast compliance**
  - **Validates: Requirements 9.1**

- [ ] 11.3 Ensure link visual indicators
  - Audit all links for underline or other non-color indicators
  - Add underline decoration or border to links missing indicators
  - Update link styles globally
  - _Requirements: 9.4_

- [ ] 11.4 Write property test for link visual indicators
  - **Property 5: Link visual indicators**
  - **Validates: Requirements 9.4**

- [ ] 11.5 Validate contrast compliance
  - Run automated contrast checker (axe-core)
  - Verify Lighthouse contrast audits pass
  - Manual spot-check with contrast analyzer tool
  - _Requirements: 9.5_

- [ ] 12. Phase 3C: Keyboard Navigation Support
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 12.1 Implement SkipLink component
  - Create SkipLinkProps interface
  - Render skip link visually hidden until focused
  - Position absolutely at top of page
  - Link to main content area
  - _Requirements: 10.1, 10.4_

- [ ] 12.2 Write unit tests for SkipLink
  - Test skip link is first focusable element
  - Test skip link becomes visible on focus
  - Test skip link navigates to main content
  - _Requirements: 10.1, 10.4_

- [ ] 12.3 Add semantic landmarks
  - Ensure main landmark element exists
  - Add header, nav, footer landmarks as appropriate
  - Verify landmark structure is logical
  - _Requirements: 10.2_

- [ ] 12.4 Fix heading hierarchy
  - Audit all headings for proper nesting
  - Fix any skipped levels (e.g., h1 → h3)
  - Ensure single h1 per page
  - _Requirements: 10.3_

- [ ] 12.5 Write property test for heading hierarchy
  - **Property 6: Heading hierarchy**
  - **Validates: Requirements 10.3**

- [ ] 12.6 Validate keyboard navigation
  - Test skip link with keyboard
  - Test tab order through entire page
  - Run Lighthouse bypass mechanism audit
  - _Requirements: 10.5_

- [ ] 13. Phase 3D: Video Accessibility
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [ ] 13.1 Create video captions file
  - Generate WebVTT captions file for hero video
  - Ensure captions are synchronized with video
  - Include speaker identification and sound descriptions
  - _Requirements: 11.2_

- [ ] 13.2 Add captions track to video
  - Update LazyVideo component to support track elements
  - Add track element with kind="captions" to hero video
  - Reference the WebVTT file in track src
  - _Requirements: 11.1, 11.2_

- [ ] 13.3 Write unit tests for video captions
  - Test track element present
  - Test track src references valid file
  - Test captions display when enabled
  - _Requirements: 11.1, 11.5_

- [ ] 13.4 Validate video accessibility
  - Test captions display correctly
  - Run Lighthouse video captions audit
  - Test with screen reader
  - _Requirements: 11.4_

- [ ] 14. Checkpoint - Verify accessibility improvements
  - Run Lighthouse accessibility audit
  - Verify Accessibility score ≥ 95
  - Run axe-core automated tests
  - Perform manual keyboard navigation testing
  - Ensure all tests pass, ask the user if questions arise

- [ ] 15. Phase 4A: Baseline Security Headers
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [ ] 15.1 Create customHttp.yml configuration
  - Create customHttp.yml at project root
  - Define pattern matching all routes
  - Add Strict-Transport-Security header (start with 1 year max-age)
  - Add X-Content-Type-Options: nosniff
  - Add Referrer-Policy: strict-origin-when-cross-origin
  - Add Permissions-Policy disabling unused features
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [ ] 15.2 Write integration tests for security headers
  - Test HSTS header present with correct value
  - Test X-Content-Type-Options present
  - Test Referrer-Policy present
  - Test Permissions-Policy present
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [ ] 15.3 Deploy and validate baseline headers
  - Deploy customHttp.yml to Amplify
  - Verify headers in browser DevTools Network tab
  - Run Lighthouse best practices audit
  - _Requirements: 12.5_

- [ ] 16. Phase 4B: Clickjacking Protection
  - _Requirements: 13.1, 13.2, 13.3, 13.4_

- [ ] 16.1 Add frame-ancestors and X-Frame-Options
  - Add X-Frame-Options: DENY to customHttp.yml
  - Add Content-Security-Policy frame-ancestors 'none' directive
  - _Requirements: 13.1, 13.2_

- [ ] 16.2 Write integration tests for clickjacking protection
  - Test X-Frame-Options header present
  - Test frame-ancestors directive in CSP
  - Test iframe embedding is blocked
  - _Requirements: 13.2, 13.3_

- [ ] 16.3 Validate clickjacking protection
  - Attempt to embed site in iframe (should fail)
  - Run Lighthouse clickjacking audit
  - _Requirements: 13.4_

- [ ] 17. Phase 4C: Cross-Origin Isolation
  - _Requirements: 14.1, 14.2, 14.3, 14.5_

- [ ] 17.1 Add COOP header
  - Add Cross-Origin-Opener-Policy: same-origin to customHttp.yml
  - _Requirements: 14.1_

- [ ] 17.2 Write integration tests for COOP
  - Test COOP header present
  - Test auth popups still work (if applicable)
  - Test cross-origin resources load correctly
  - _Requirements: 14.1, 14.2, 14.5_

- [ ] 17.3 Validate COOP deployment
  - Verify COOP header in browser
  - Test authentication flows
  - Run Lighthouse COOP audit
  - _Requirements: 14.3_

- [ ] 18. Phase 4D: Content Security Policy
  - _Requirements: 15.1, 15.2, 15.3, 15.5_

- [ ] 18.1 Define CSP in report-only mode
  - Add Content-Security-Policy-Report-Only header to customHttp.yml
  - Define directives: default-src 'self'
  - Allow required origins: google, recaptcha, gtm, facebook, s3, cognito, appsync
  - Add frame-ancestors 'none'
  - Configure report-uri or report-to for violation reports
  - _Requirements: 15.1, 15.2, 15.3_

- [ ] 18.2 Write integration tests for CSP
  - Test CSP header present
  - Test allowed origins load correctly
  - Test unauthorized origins are blocked (in enforcement mode)
  - _Requirements: 15.1, 15.3_

- [ ] 18.3 Monitor CSP violations
  - Deploy CSP in report-only mode
  - Monitor violation reports for 7 days
  - Fix any legitimate violations (update CSP or code)
  - _Requirements: 15.2_

- [ ] 18.4 Switch CSP to enforcement mode
  - Change Content-Security-Policy-Report-Only to Content-Security-Policy
  - Keep violation reporting enabled
  - Deploy and monitor
  - _Requirements: 15.1_

- [ ] 18.5 Validate CSP enforcement
  - Verify CSP header in enforcement mode
  - Test all functionality works
  - Run Lighthouse CSP audit
  - _Requirements: 15.5_

- [ ] 19. Checkpoint - Verify security improvements
  - Run Lighthouse best practices audit
  - Verify Best Practices score ≥ 95
  - Verify all security headers present
  - Test with Mozilla Observatory
  - Ensure all tests pass, ask the user if questions arise

- [ ] 20. Phase 5: Real User Monitoring
  - _Requirements: 17.1, 17.2, 17.3_

- [ ] 20.1 Install web-vitals library
  - Add web-vitals package to dependencies
  - Import web-vitals functions (onCLS, onFID, onLCP, onFCP, onTTFB, onINP)
  - _Requirements: 17.1_

- [ ] 20.2 Implement WebVitalsReporter
  - Create WebVitalsReporter interface
  - Implement initialize method to set up metric listeners
  - Implement reportMetric method to send to analytics
  - _Requirements: 17.1, 17.2_

- [ ] 20.3 Write unit tests for WebVitalsReporter
  - Test metrics collection initialization
  - Test metric reporting to endpoint
  - Test consent gating of RUM
  - _Requirements: 17.1, 17.2, 17.3_

- [ ] 20.4 Integrate RUM with analytics
  - Report metrics to GTM/GA4 after consent
  - Include device type, connection type, and URL
  - Respect user privacy and consent preferences
  - _Requirements: 17.2, 17.3_

- [ ] 20.5 Validate RUM implementation
  - Verify metrics are collected
  - Verify metrics appear in GA4
  - Verify consent gating works
  - _Requirements: 17.1, 17.2, 17.3_

- [ ] 21. Phase 6: Final Validation and Documentation
  - _Requirements: 19.2, 19.3, 19.4, 20.1, 20.2, 20.3, 20.4, 20.5_

- [ ] 21.1 Run comprehensive E2E tests
  - Test complete user flow: load → consent → scroll → form submit
  - Test form submission end-to-end
  - Test OTP flow
  - Test analytics attribution
  - Test routing
  - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5_

- [ ] 21.2 Run all unit and property tests
  - Execute full test suite
  - Verify all tests pass
  - Check code coverage
  - _Requirements: All_

- [ ] 21.3 Run final Lighthouse audits
  - Run Lighthouse mobile audit on production
  - Capture final report in /reports/lighthouse/
  - Verify all target scores met (Perf ≥80, A11y ≥95, BP ≥95, SEO ≥95)
  - _Requirements: 19.3_

- [ ] 21.4 Compare metrics to baseline
  - Calculate improvements in FCP, LCP, TBT, CLS
  - Calculate payload reduction percentage
  - Calculate request count reduction
  - Document improvements in task table
  - _Requirements: 19.3_

- [ ] 21.5 Update task tracking table
  - Mark all tasks as DONE or WON'T FIX with justification
  - Record final commit SHAs
  - Document any known limitations
  - Add notes on future improvements
  - _Requirements: 19.4, 19.5_

- [ ] 21.6 Create operations runbook
  - Document deployment verification steps
  - Document rollback procedures
  - Document monitoring approach
  - Document troubleshooting for common issues
  - _Requirements: Documentation_

- [ ] 22. Final Checkpoint - Project Complete
  - Verify all target metrics achieved
  - Verify all functionality preserved
  - Verify all documentation complete
  - Ensure all tests pass, ask the user if questions arise
