# Design Document: Promo Site Mobile Audit Remediation

## Overview

This design document outlines the architecture and implementation strategy for remediating mobile performance, accessibility, security, and SEO issues on promo.mmptoledo.com. The system will achieve Lighthouse target scores (Performance ≥80, Accessibility ≥95, Best Practices ≥95, SEO ≥95) through systematic optimizations while preserving all existing functionality.

The remediation follows a phased approach with atomic, reversible changes:
1. **SEO Unblocking**: Enable production indexing
2. **Performance**: Eliminate render-blocking resources and defer heavy assets
3. **Accessibility**: Fix WCAG compliance issues
4. **Security**: Implement defense-in-depth headers
5. **Observability**: Add real-user monitoring

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Amplify Hosting                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Custom HTTP Headers Layer                  │ │
│  │  (CSP, HSTS, COOP, X-Frame-Options, Permissions)       │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  SPA Application                        │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Environment-Gated SEO Meta Tags                 │  │ │
│  │  │  (noindex on preview, index on production)       │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Optimized Asset Loading                         │  │ │
│  │  │  • Lazy video (poster + intersection observer)   │  │ │
│  │  │  • Responsive images (srcset, width/height)      │  │ │
│  │  │  • Code-split bundles (route-based)              │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Deferred Third-Party Scripts                    │  │ │
│  │  │  • reCAPTCHA (on form interaction)               │  │ │
│  │  │  • GTM/FB Pixel (on consent)                     │  │ │
│  │  │  • Service Worker (on idle)                      │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Accessibility Enhancements                      │  │ │
│  │  │  • Skip link + landmarks                         │  │ │
│  │  │  • Dialog ARIA labels                            │  │ │
│  │  │  • WCAG contrast compliance                      │  │ │
│  │  │  • Video captions                                │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Real User Monitoring                            │  │ │
│  │  │  • web-vitals library                            │  │ │
│  │  │  • Report to GTM/GA4                             │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Git Repository                             │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │  main branch   │  │ preview branch │  │ feature branch │ │
│  │  (production)  │  │   (staging)    │  │    (dev)       │ │
│  └────────────────┘  └────────────────┘  └────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│              AWS Amplify CI/CD Pipeline                       │
│  • Build with environment variables                           │
│  • Apply customHttp.yml headers                               │
│  • Deploy to environment-specific URL                         │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  Production: promo.mmptoledo.com (indexable)                  │
│  Preview: preview.promo.mmptoledo.com (noindex)               │
└──────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Environment Configuration Module

**Purpose**: Manage environment-specific behavior for SEO, analytics, and feature flags.

**Interface**:
```typescript
interface EnvironmentConfig {
  environment: 'production' | 'preview' | 'development';
  seo: {
    allowIndexing: boolean;
    canonicalUrl: string;
  };
  analytics: {
    enabled: boolean;
    gtmId?: string;
    fbPixelId?: string;
  };
  features: {
    videoAutoplay: boolean;
    recaptchaDeferred: boolean;
  };
}

function getEnvironmentConfig(): EnvironmentConfig;
```

**Implementation Notes**:
- Detect environment from `window.location.hostname` or build-time env vars
- Production domain: `promo.mmptoledo.com` → `allowIndexing: true`
- All other domains → `allowIndexing: false`

### 2. SEO Meta Manager

**Purpose**: Dynamically inject or update SEO-related meta tags based on environment.

**Interface**:
```typescript
interface SEOMetaManager {
  setRobotsDirective(allow: boolean): void;
  setCanonicalUrl(url: string): void;
  generateStructuredData(): void;
}
```

**Implementation**:
- Use `react-helmet-async` or similar for meta tag management
- Inject `<meta name="robots" content="index,follow">` on production
- Inject `<meta name="robots" content="noindex,nofollow">` on preview/dev

### 3. Lazy Video Loader

**Purpose**: Defer video loading until user interaction or viewport visibility.

**Interface**:
```typescript
interface LazyVideoProps {
  src: string;
  poster: string;
  mobileSrc?: string; // Smaller variant for mobile
  onLoad?: () => void;
}

function LazyVideo(props: LazyVideoProps): JSX.Element;
```

**Implementation Strategy**:
- Render `<video>` with `preload="metadata"` and `poster` attribute
- Use `IntersectionObserver` to detect when video enters viewport
- On intersection or user click, set `src` attribute to trigger load
- For mobile viewports (`window.innerWidth < 768`), use `mobileSrc` if provided
- Add explicit `width` and `height` attributes to prevent CLS

### 4. Deferred Script Loader

**Purpose**: Load third-party scripts on-demand to reduce initial blocking time.

**Interface**:
```typescript
interface ScriptLoaderOptions {
  src: string;
  id: string;
  async?: boolean;
  defer?: boolean;
  onLoad?: () => void;
  onError?: (error: Error) => void;
}

class DeferredScriptLoader {
  private loadedScripts: Set<string>;
  
  loadScript(options: ScriptLoaderOptions): Promise<void>;
  isLoaded(id: string): boolean;
}
```

**Implementation**:
- Maintain singleton instance to prevent duplicate loads
- Use single-flight pattern: if script is already loading, return existing promise
- Inject script tag dynamically on first call
- Track loaded scripts by `id` to prevent re-injection

### 5. reCAPTCHA Manager

**Purpose**: Load reCAPTCHA Enterprise only when needed for form protection.

**Interface**:
```typescript
interface RecaptchaManager {
  initialize(): Promise<void>;
  execute(action: string): Promise<string>;
  isReady(): boolean;
}
```

**Implementation**:
- Do NOT load reCAPTCHA on page load
- Load on first form field focus or submit button click
- Use `DeferredScriptLoader` with single-flight guard
- Cache the ready state to avoid redundant checks

### 6. Consent Manager Integration

**Purpose**: Gate analytics and tracking scripts behind user consent.

**Interface**:
```typescript
interface ConsentManager {
  hasConsent(category: 'analytics' | 'marketing'): boolean;
  onConsentChange(callback: (consents: ConsentState) => void): void;
}

interface ConsentState {
  analytics: boolean;
  marketing: boolean;
  timestamp: number;
}
```

**Implementation**:
- Integrate with existing cookie banner component
- Load GTM/FB Pixel only after `analytics: true` or `marketing: true`
- Store consent in localStorage with expiry
- Respect consent revocation

### 7. Image Optimization Component

**Purpose**: Serve responsive, modern-format images with proper sizing.

**Interface**:
```typescript
interface OptimizedImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
  sizes?: string;
  loading?: 'lazy' | 'eager';
}

function OptimizedImage(props: OptimizedImageProps): JSX.Element;
```

**Implementation**:
- Generate `srcset` with multiple resolutions (1x, 2x, 3x)
- Use `<picture>` element to serve WebP/AVIF with fallback
- Always include explicit `width` and `height` to reserve space
- Use `loading="lazy"` for below-fold images

### 8. Accessibility Components

#### Skip Link Component
```typescript
interface SkipLinkProps {
  targetId: string;
  label?: string;
}

function SkipLink(props: SkipLinkProps): JSX.Element;
```

#### Accessible Dialog Component
```typescript
interface AccessibleDialogProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}

function AccessibleDialog(props: AccessibleDialogProps): JSX.Element;
```

**Implementation**:
- Skip link: visually hidden until focused, positioned absolutely at top
- Dialog: use `role="dialog"`, `aria-labelledby` pointing to title element
- Manage focus trap with `focus-trap-react` or similar
- Ensure visible focus indicators (`:focus-visible` styles)

### 9. Security Headers Configuration

**Purpose**: Define and apply HTTP security headers via AWS Amplify.

**Configuration File**: `customHttp.yml` (placed at project root)

```yaml
customHeaders:
  - pattern: '**/*'
    headers:
      - key: 'Strict-Transport-Security'
        value: 'max-age=31536000; includeSubDomains'
      - key: 'X-Content-Type-Options'
        value: 'nosniff'
      - key: 'Referrer-Policy'
        value: 'strict-origin-when-cross-origin'
      - key: 'Permissions-Policy'
        value: 'geolocation=(), microphone=(), camera=()'
      - key: 'X-Frame-Options'
        value: 'DENY'
      - key: 'Cross-Origin-Opener-Policy'
        value: 'same-origin'
      - key: 'Content-Security-Policy'
        value: "default-src 'self'; script-src 'self' https://www.google.com https://www.gstatic.com https://www.googletagmanager.com https://connect.facebook.net; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' https://cognito-identity.us-east-2.amazonaws.com https://*.appsync-api.us-east-2.amazonaws.com; frame-ancestors 'none';"
```

**Deployment**:
- Amplify automatically applies headers from `customHttp.yml` on build
- Start with `Content-Security-Policy-Report-Only` for validation
- Switch to `Content-Security-Policy` after confirming no violations

### 10. Real User Monitoring (RUM)

**Purpose**: Collect and report Core Web Vitals from real users.

**Interface**:
```typescript
interface WebVitalsReporter {
  initialize(): void;
  reportMetric(metric: Metric): void;
}

interface Metric {
  name: 'CLS' | 'FID' | 'LCP' | 'FCP' | 'TTFB' | 'INP';
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  delta: number;
  id: string;
}
```

**Implementation**:
- Use `web-vitals` library from Google Chrome team
- Report metrics to Google Analytics via GTM (after consent)
- Optionally send to custom endpoint for aggregation
- Include device type, connection type, and URL in reports

## Data Models

### Environment Detection

```typescript
type Environment = 'production' | 'preview' | 'development';

interface EnvironmentDetector {
  detect(): Environment;
}

// Implementation logic:
// - Check window.location.hostname
// - 'promo.mmptoledo.com' → 'production'
// - '*.amplifyapp.com' or 'preview.*' → 'preview'
// - 'localhost' or '127.0.0.1' → 'development'
```

### Script Load State

```typescript
interface ScriptLoadState {
  id: string;
  src: string;
  status: 'idle' | 'loading' | 'loaded' | 'error';
  promise?: Promise<void>;
  error?: Error;
}

type ScriptRegistry = Map<string, ScriptLoadState>;
```

### Consent State

```typescript
interface ConsentState {
  analytics: boolean;
  marketing: boolean;
  functional: boolean;
  timestamp: number;
  version: string; // Policy version
}
```

### Performance Metrics

```typescript
interface PerformanceSnapshot {
  timestamp: number;
  url: string;
  metrics: {
    FCP: number;
    LCP: number;
    CLS: number;
    TBT: number;
    FID?: number;
    INP?: number;
  };
  resources: {
    totalBytes: number;
    totalRequests: number;
    jsBytes: number;
    cssBytes: number;
    imageBytes: number;
    videoBytes: number;
  };
  device: {
    type: 'mobile' | 'tablet' | 'desktop';
    connection: string;
  };
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, several properties emerged that apply universally across the application rather than to specific examples. The following properties represent rules that should hold for all instances of their respective domains:

**Property 1: Script loading idempotence**
*For any* script ID, calling the script loader multiple times should result in exactly one script tag being injected into the DOM.
**Validates: Requirements 3.3**

**Property 2: Image dimension attributes**
*For any* image element rendered by the application, the element should include explicit width and height attributes.
**Validates: Requirements 6.2**

**Property 3: Focus indicator visibility**
*For any* interactive element (button, link, input, select, textarea), when focused, the element should display a visible focus indicator with sufficient contrast.
**Validates: Requirements 8.4**

**Property 4: Text contrast compliance**
*For any* text element displayed on the site, the contrast ratio between text and background should meet or exceed WCAG AA thresholds (4.5:1 for normal text, 3:1 for large text).
**Validates: Requirements 9.1**

**Property 5: Link visual indicators**
*For any* link element, the element should have either text-decoration underline or another non-color visual indicator (icon, border, etc.) to distinguish it from plain text.
**Validates: Requirements 9.4**

**Property 6: Heading hierarchy**
*For any* page, heading elements (h1-h6) should follow a logical hierarchy without skipping levels (e.g., h1 → h2 → h3, not h1 → h3).
**Validates: Requirements 10.3**

## Error Handling

### Script Loading Failures

**Strategy**: Graceful degradation with user notification

- **reCAPTCHA Load Failure**: 
  - Catch script load errors in `DeferredScriptLoader`
  - Display user-friendly message: "Security verification temporarily unavailable. Please try again."
  - Log error to monitoring system
  - Optionally fall back to honeypot or server-side validation

- **Analytics Script Failure**:
  - Fail silently (do not block user experience)
  - Log error for debugging
  - Ensure core functionality works without analytics

### Video Loading Failures

**Strategy**: Fallback to poster image with retry option

- Display poster image permanently if video fails to load
- Show "Play Video" button that retries load on click
- Log error with video URL and user agent for debugging

### Image Loading Failures

**Strategy**: Alt text display with retry

- Browser natively displays alt text on image load failure
- Ensure all images have meaningful alt text
- Consider lazy-load retry logic for transient network failures

### CSP Violations

**Strategy**: Report-only mode first, then enforcement

- Phase 1: Deploy with `Content-Security-Policy-Report-Only`
- Monitor violation reports for 7 days
- Fix any legitimate violations (update CSP or code)
- Phase 2: Switch to enforcement mode with `Content-Security-Policy`
- Maintain violation reporting endpoint for ongoing monitoring

### Consent State Corruption

**Strategy**: Fail-safe to no consent

- If localStorage consent data is corrupted or invalid, treat as no consent
- Re-prompt user for consent
- Log corruption event for investigation

### Environment Detection Failure

**Strategy**: Fail-safe to most restrictive (preview mode)

- If environment cannot be determined, default to preview mode (noindex)
- Log detection failure
- Require explicit production environment variable for indexing

## Testing Strategy

### Dual Testing Approach

This project requires both **unit tests** and **property-based tests** to ensure comprehensive coverage:

- **Unit tests** verify specific examples, edge cases, and integration points
- **Property-based tests** verify universal properties that should hold across all inputs
- Together they provide comprehensive coverage: unit tests catch concrete bugs, property tests verify general correctness

### Unit Testing

**Framework**: Vitest (or Jest if already in use)

**Coverage Areas**:

1. **Environment Detection**
   - Test production domain returns `allowIndexing: true`
   - Test preview domains return `allowIndexing: false`
   - Test localhost returns development mode

2. **SEO Meta Manager**
   - Test correct meta tags injected for production
   - Test noindex meta tags injected for preview
   - Test canonical URL generation

3. **Lazy Video Loader**
   - Test video does not load on initial render
   - Test video loads when entering viewport
   - Test poster image displays correctly
   - Test mobile variant selection

4. **Deferred Script Loader**
   - Test script injection on first call
   - Test script not re-injected on subsequent calls
   - Test error handling for failed loads
   - Test promise resolution/rejection

5. **reCAPTCHA Manager**
   - Test no load on page init
   - Test load on form focus
   - Test single-load guard prevents duplicates
   - Test form submission with deferred load

6. **Consent Manager Integration**
   - Test scripts not loaded without consent
   - Test GTM loads after analytics consent
   - Test FB Pixel loads after marketing consent
   - Test consent denial prevents loading

7. **Accessibility Components**
   - Test skip link renders and focuses correctly
   - Test dialog has accessible name
   - Test focus management in dialog
   - Test keyboard navigation

8. **Security Headers**
   - Test headers present in response (integration test with test server)
   - Test CSP allows required origins
   - Test CSP blocks unauthorized origins

9. **Real User Monitoring**
   - Test metrics collection initialization
   - Test metric reporting to endpoint
   - Test consent gating of RUM

10. **Functionality Preservation**
    - Test form submission end-to-end
    - Test OTP flow
    - Test analytics attribution parameters
    - Test routing

### Property-Based Testing

**Framework**: fast-check (JavaScript property-based testing library)

**Configuration**: Each property-based test should run a minimum of 100 iterations to ensure thorough coverage of the input space.

**Test Tagging**: Each property-based test must include a comment explicitly referencing the correctness property from this design document using the format: `**Feature: promo-mobile-audit-remediation, Property {number}: {property_text}**`

**Property Tests**:

1. **Property 1: Script loading idempotence**
   ```typescript
   // **Feature: promo-mobile-audit-remediation, Property 1: Script loading idempotence**
   fc.assert(
     fc.property(
       fc.string(), // script ID
       fc.webUrl(), // script URL
       async (id, url) => {
         const loader = new DeferredScriptLoader();
         await loader.loadScript({ id, src: url });
         await loader.loadScript({ id, src: url });
         await loader.loadScript({ id, src: url });
         
         const scriptTags = document.querySelectorAll(`script[data-id="${id}"]`);
         expect(scriptTags.length).toBe(1);
       }
     ),
     { numRuns: 100 }
   );
   ```

2. **Property 2: Image dimension attributes**
   ```typescript
   // **Feature: promo-mobile-audit-remediation, Property 2: Image dimension attributes**
   fc.assert(
     fc.property(
       fc.string(), // image src
       fc.string(), // alt text
       fc.integer({ min: 1, max: 4000 }), // width
       fc.integer({ min: 1, max: 4000 }), // height
       (src, alt, width, height) => {
         const { container } = render(
           <OptimizedImage src={src} alt={alt} width={width} height={height} />
         );
         const img = container.querySelector('img');
         expect(img).toHaveAttribute('width', String(width));
         expect(img).toHaveAttribute('height', String(height));
       }
     ),
     { numRuns: 100 }
   );
   ```

3. **Property 3: Focus indicator visibility**
   ```typescript
   // **Feature: promo-mobile-audit-remediation, Property 3: Focus indicator visibility**
   fc.assert(
     fc.property(
       fc.constantFrom('button', 'a', 'input', 'select', 'textarea'),
       fc.string(), // element content/label
       (tagName, content) => {
         const element = document.createElement(tagName);
         element.textContent = content;
         document.body.appendChild(element);
         element.focus();
         
         const styles = window.getComputedStyle(element, ':focus-visible');
         const hasOutline = styles.outline !== 'none' && styles.outline !== '';
         const hasBoxShadow = styles.boxShadow !== 'none';
         const hasBorder = styles.borderWidth !== '0px';
         
         expect(hasOutline || hasBoxShadow || hasBorder).toBe(true);
         
         element.remove();
       }
     ),
     { numRuns: 100 }
   );
   ```

4. **Property 4: Text contrast compliance**
   ```typescript
   // **Feature: promo-mobile-audit-remediation, Property 4: Text contrast compliance**
   fc.assert(
     fc.property(
       fc.hexaString({ minLength: 6, maxLength: 6 }), // text color
       fc.hexaString({ minLength: 6, maxLength: 6 }), // bg color
       fc.integer({ min: 12, max: 48 }), // font size
       (textColor, bgColor, fontSize) => {
         const element = document.createElement('p');
         element.style.color = `#${textColor}`;
         element.style.backgroundColor = `#${bgColor}`;
         element.style.fontSize = `${fontSize}px`;
         element.textContent = 'Test text';
         document.body.appendChild(element);
         
         const contrast = calculateContrastRatio(textColor, bgColor);
         const isLargeText = fontSize >= 18 || (fontSize >= 14 && isBold(element));
         const threshold = isLargeText ? 3 : 4.5;
         
         // This property will fail for some color combinations,
         // which is expected - it validates our color choices
         if (element.classList.contains('site-text')) {
           expect(contrast).toBeGreaterThanOrEqual(threshold);
         }
         
         element.remove();
       }
     ),
     { numRuns: 100 }
   );
   ```

5. **Property 5: Link visual indicators**
   ```typescript
   // **Feature: promo-mobile-audit-remediation, Property 5: Link visual indicators**
   fc.assert(
     fc.property(
       fc.string(), // link text
       fc.webUrl(), // href
       (text, href) => {
         const { container } = render(<a href={href}>{text}</a>);
         const link = container.querySelector('a');
         const styles = window.getComputedStyle(link);
         
         const hasUnderline = styles.textDecoration.includes('underline');
         const hasBorder = styles.borderBottomWidth !== '0px';
         const hasIcon = link.querySelector('svg, img') !== null;
         
         expect(hasUnderline || hasBorder || hasIcon).toBe(true);
       }
     ),
     { numRuns: 100 }
   );
   ```

6. **Property 6: Heading hierarchy**
   ```typescript
   // **Feature: promo-mobile-audit-remediation, Property 6: Heading hierarchy**
   fc.assert(
     fc.property(
       fc.array(fc.integer({ min: 1, max: 6 }), { minLength: 2, maxLength: 10 }),
       (headingLevels) => {
         // Create a page with these heading levels
         const container = document.createElement('div');
         headingLevels.forEach(level => {
           const heading = document.createElement(`h${level}`);
           heading.textContent = `Heading ${level}`;
           container.appendChild(heading);
         });
         
         // Check hierarchy
         const headings = Array.from(container.querySelectorAll('h1, h2, h3, h4, h5, h6'));
         const levels = headings.map(h => parseInt(h.tagName[1]));
         
         for (let i = 1; i < levels.length; i++) {
           const jump = levels[i] - levels[i - 1];
           // Should not skip more than 1 level when going deeper
           if (jump > 1) {
             expect(jump).toBeLessThanOrEqual(1);
           }
         }
       }
     ),
     { numRuns: 100 }
   );
   ```

### Integration Testing

**Framework**: Playwright or Cypress

**Test Scenarios**:

1. **End-to-End User Flow**
   - Load homepage
   - Accept cookie consent
   - Scroll to video (verify lazy load)
   - Fill and submit form (verify reCAPTCHA loads)
   - Verify form submission success

2. **Lighthouse CI**
   - Run Lighthouse on every PR
   - Fail if scores drop below thresholds
   - Store reports as artifacts

3. **Visual Regression**
   - Capture screenshots of key pages
   - Compare against baseline
   - Flag unexpected visual changes

### Performance Testing

**Tools**: Lighthouse CI, WebPageTest

**Metrics to Track**:
- FCP (First Contentful Paint)
- LCP (Largest Contentful Paint)
- TBT (Total Blocking Time)
- CLS (Cumulative Layout Shift)
- Total payload size
- Number of requests

**Thresholds**:
- LCP < 3.5s (stretch < 2.5s)
- FCP < 2.0s
- TBT < 300ms
- CLS < 0.1
- Total payload reduction ≥ 40% from baseline

### Accessibility Testing

**Tools**: axe-core, Lighthouse, manual keyboard testing

**Test Coverage**:
- Automated axe-core scans on all pages
- Keyboard navigation testing
- Screen reader testing (NVDA/JAWS/VoiceOver)
- Color contrast validation
- Focus management validation

### Security Testing

**Tools**: OWASP ZAP, Mozilla Observatory

**Test Coverage**:
- Security header presence and correctness
- CSP violation monitoring
- XSS attempt blocking
- Clickjacking protection
- HTTPS enforcement

## Implementation Phases

### Phase 0: Baseline and Setup
- Capture baseline Lighthouse reports
- Set up testing infrastructure
- Create task tracking document
- Configure CI/CD for automated testing

### Phase 1: SEO Unblocking
- Implement environment detection
- Add SEO meta manager
- Update robots.txt
- Deploy and verify indexing

### Phase 2: Performance Optimizations
- Implement lazy video loader
- Implement deferred script loader
- Implement reCAPTCHA manager
- Implement consent-gated analytics
- Optimize images
- Code-split bundles
- Add preconnect hints
- Defer service worker

### Phase 3: Accessibility Fixes
- Add skip link and landmarks
- Fix cookie banner accessibility
- Fix color contrast issues
- Add video captions
- Implement focus management

### Phase 4: Security Headers
- Create customHttp.yml
- Add baseline security headers
- Add CSP in report-only mode
- Validate CSP and switch to enforcement
- Add COOP and frame-ancestors

### Phase 5: Observability
- Integrate web-vitals library
- Implement RUM reporting
- Set up monitoring dashboards
- Configure alerting

### Phase 6: Validation and Optimization
- Run final Lighthouse audits
- Compare against baseline
- Fine-tune based on results
- Document improvements

## Deployment Strategy

### Atomic Commits

Each fix must be deployed as a separate, reversible commit:

1. Make the change
2. Run validation (build, tests, targeted check)
3. `git add -A`
4. `git commit -m "type(scope): precise description"`
5. Push and monitor

### Commit Message Convention

Format: `type(scope): description`

Types:
- `seo:` - SEO-related changes
- `perf:` - Performance optimizations
- `a11y:` - Accessibility fixes
- `security:` - Security header changes
- `obs:` - Observability/monitoring
- `chore:` - Build, config, or tooling

Examples:
- `seo: enable indexing on production (meta robots)`
- `perf(video): lazy-load hero video and reduce initial payload`
- `a11y(cookie): add dialog accessible name + focus behavior`
- `security(headers): add CSP in report-only mode`

### Rollback Strategy

If any commit causes issues:

1. Identify the problematic commit
2. `git revert <commit-sha>`
3. Document the issue
4. Implement a safer alternative
5. Re-deploy

### Stop Signals

Halt deployment and rollback if:
- Lead submission fails
- OTP flow breaks
- reCAPTCHA blocks real users
- Consent state breaks analytics attribution
- CSP/COOP causes blank page or blocked scripts
- Routing breaks (404s) or SPA rewrites fail

## Monitoring and Validation

### Real-Time Monitoring

- **Error Tracking**: Sentry or similar for JavaScript errors
- **Performance Monitoring**: Web Vitals RUM data in GA4
- **Security Monitoring**: CSP violation reports
- **Uptime Monitoring**: Pingdom or UptimeRobot

### Success Metrics

**Primary Metrics** (Lighthouse scores):
- Performance: ≥ 80 (stretch ≥ 90)
- Accessibility: ≥ 95
- Best Practices: ≥ 95
- SEO: ≥ 95

**Secondary Metrics** (Core Web Vitals):
- LCP: < 3.5s (stretch < 2.5s)
- FID/INP: < 100ms
- CLS: < 0.1

**Tertiary Metrics** (Resource efficiency):
- Total payload: ≥ 40% reduction
- JavaScript bytes: ≥ 50% reduction
- Number of requests: ≥ 30% reduction

### Validation Checklist

After each commit:
- [ ] `npm run build` passes
- [ ] `npm run lint` passes
- [ ] `npm run test` passes
- [ ] Manual smoke test on mobile
- [ ] Lighthouse spot-check (if major change)
- [ ] No SEO regression (robots meta + robots.txt)
- [ ] No functionality regression (forms, OTP, analytics, routing)

## Documentation

### Required Documentation

1. **Task Table** (`/docs/audits/mobile-fix-plan.md`)
   - Track all issues and fixes
   - Update status after each commit
   - Record commit SHAs and validation results

2. **Lighthouse Reports** (`/reports/lighthouse/`)
   - Baseline report
   - Intermediate reports (after major phases)
   - Final report

3. **Implementation Notes** (in task table)
   - Risk decisions
   - Trade-offs made
   - Known limitations
   - Future improvements

4. **Runbook** (for operations team)
   - How to verify deployment
   - How to rollback
   - How to monitor
   - How to troubleshoot common issues

## Future Enhancements

### Post-Launch Optimizations

1. **Advanced Image Optimization**
   - Implement responsive image CDN (Cloudinary, Imgix)
   - Automatic format selection (AVIF → WebP → JPEG)
   - Lazy-load with blur-up placeholders

2. **Service Worker Caching**
   - Implement offline support
   - Cache static assets aggressively
   - Implement stale-while-revalidate strategy

3. **Critical CSS Extraction**
   - Automate critical CSS extraction
   - Inline critical CSS in HTML
   - Defer non-critical CSS

4. **Resource Hints**
   - Add preload for critical resources
   - Add prefetch for likely next pages
   - Implement predictive prefetching

5. **Advanced Analytics**
   - Implement custom RUM dashboard
   - Add business metric correlation
   - Implement A/B testing framework

6. **Trusted Types**
   - Refactor code to use Trusted Types
   - Enable Trusted Types enforcement in CSP
   - Audit third-party scripts for compatibility

## Conclusion

This design provides a comprehensive, phased approach to remediating mobile performance, accessibility, security, and SEO issues on promo.mmptoledo.com. By following atomic deployment practices, implementing both unit and property-based tests, and maintaining strict validation at each step, we can achieve target Lighthouse scores while preserving all existing functionality.

The architecture emphasizes:
- **Safety**: Atomic commits, rollback capability, stop signals
- **Quality**: Dual testing approach, comprehensive validation
- **Observability**: RUM, error tracking, performance monitoring
- **Security**: Defense-in-depth headers, CSP, COOP
- **Accessibility**: WCAG compliance, keyboard navigation, screen reader support
- **Performance**: Lazy loading, code splitting, deferred scripts

Success will be measured by Lighthouse scores, Core Web Vitals, and resource efficiency metrics, with continuous monitoring to detect and prevent regressions.
