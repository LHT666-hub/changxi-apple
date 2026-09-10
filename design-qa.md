# 常曦食养 Design QA

## Comparison setup

- Source visual truth:
  - `C:\\Users\\LHT\\.codex\\generated_images\\01a08a07-7ab7-7240-b188-f3638e62fc67\\exec-5f4d40bd-9b13-4169-97c2-668d9025c49b.png`（食养首页）
  - `C:\\Users\\LHT\\.codex\\generated_images\\01a08a07-7ab7-7240-b188-f3638e62fc67\\exec-d179e57c-f9a5-491f-880c-a8513a7263ff.png`（食材盘点）
  - `C:\\Users\\LHT\\.codex\\generated_images\\01a08a07-7ab7-7240-b188-f3638e62fc67\\exec-799e3891-9913-46c2-a445-693ed6accdd7.png`（分步做饭）
- Implementation screenshot: unavailable.
- Intended viewport: native iPhone portrait, app-owned content approximately 390 × 844 points.
- Source pixels: 853 × 1856 for each concept image.
- Implementation pixels / CSS size / density normalization: unavailable because this Windows host cannot run or capture an iOS 26 Simulator.
- State: local SwiftUI implementation is present, but no rendered implementation was available for visual comparison.

## Full-view comparison evidence

Blocked. The source mockups were inspected, but a same-state screenshot of the SwiftUI implementation could not be captured on this host. Code inspection, asset existence, image dimensions, JSON validity and whitespace checks are not substitutes for a rendered comparison.

## Focused-region comparison evidence

Blocked for the same reason. The hero crop, Dynamic Type wrapping, Liquid Glass appearance, bottom safe-area interaction, ingredient grid density and cooking timer layout require an iOS 26 render.

## Findings

- [P1] Native rendering and interaction remain unverified.
  - Location: `ChangXi/Features/Shiyang/ShiyangViews.swift`.
  - Evidence: the three source mockups are available, but there is no simulator capture of the implementation.
  - Impact: visual fidelity, safe-area behavior and interaction timing cannot be accepted yet.
  - Fix: regenerate the project on macOS, run the iPhone simulator UI flow, capture steps 15–22, then compare at the same state and viewport.

## Required fidelity surfaces

- Fonts and typography: source uses a strong Chinese serif display hierarchy; implementation maps display headings to SwiftUI serif, but wrapping and optical weight are unverified.
- Spacing and layout rhythm: 20-point page margins, 22-point section spacing and 18–30-point radii are implemented; rendered density is unverified.
- Colors and visual tokens: warm ivory/apricot/amber/tea-green tokens retain moonlight blue accents; actual Liquid Glass contrast is unverified.
- Image quality and asset fidelity: forty-two 1254 × 1254 bundled recipe images exist and match the warm cookbook direction; in-app crops are unverified.
- Copy and content: the introduction, three-layer consent, seven-question profile, editable confirmation, personalized recommendation, pantry prompt, substitutions and step-by-step cooking copy are implemented; Dynamic Type wrapping is unverified.

## Implementation checklist

1. Run `xcodegen generate` on macOS with Xcode 26.
2. Build and run `ChangXi` on an iPhone simulator.
3. Run `testShiyangPantryToCookingJourney` and retain screenshots 15–22.
4. Compare the implementation screenshots with the three source visuals.
5. Fix any P0/P1/P2 differences and repeat the comparison.

## Follow-up polish

- Tune hero height and ingredient-grid density after checking small iPhone and large-text screenshots.
- Confirm Reduce Motion changes the ingredient entrance into a short fade without losing sequence clarity.

final result: blocked
