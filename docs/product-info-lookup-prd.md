# PRD: Find Product Info Automatically

## Overview

Cosmetics Shelf should reduce manual product entry by letting the user type a product name, brand, barcode, or batch code, then choose from ranked product candidates. The feature should fill product names, brand, category, product image, official product page, and suggested shelf-life fields when confidence is high enough.

The feature must remain transparent: when the app cannot find reliable information, it should show why and keep manual entry available.

## Problem

Beauty, skincare, fragrance, and hair products often have inconsistent labeling across regions. A product may have a Chinese retail name, English official name, Japanese/Korean local name, or no translated name at all. Users also need an image to recognize the item quickly, but manually searching for product pages and image URLs is tedious.

Batch codes are a separate but related problem. They can sometimes reveal manufacture date, but formats are brand-specific and not always publicly documented.

## Goals

- Let users enter minimal text and get useful product candidates.
- Prefer official or high-quality product information.
- Fill both localized display name and English/official name where possible.
- Attach a recognizable product image without requiring manual URL entry.
- Preserve manual entry as a fallback.
- Clearly show result confidence and source.
- Support a phased implementation that works without a private backend first, then can grow into a more reliable lookup service.

## Non-Goals

- Guarantee every brand and every region will be found automatically.
- Scrape every official website directly from the iPhone app.
- Claim batch-code dates are official unless the data source is official.
- Store copyrighted product images locally unless explicitly allowed.
- Replace the user's judgment when search confidence is low.

## Target Users

- Users who own many skincare, makeup, fragrance, body, or hair products.
- Users buying products across North America and Asia, where names and labels vary.
- Users who want a visual inventory and expiry reminders without typing every field manually.

## User Stories

- As a user, I can type "Lancome Genifique serum" and see candidate products with image, brand, and source.
- As a user, I can choose a candidate and have the app fill the product name, English name, brand, image, and source URL.
- As a user, I can search using a Chinese or English product name and still get useful candidates.
- As a user, I can see whether a result came from an official site, public product database, or user-contributed source.
- As a user, I can reject all candidates and enter product information manually.
- As a user, I can enter brand and batch code and get a manufacture date only when the app has a reliable parsing rule.

## Proposed UX

### Entry Points

- Add/Edit Product screen: "Find Product Info Automatically"
- Batch tab: "Look Up Product + Batch"
- Optional future entry: barcode scanner or camera OCR

### Search Flow

1. User enters product name, brand, barcode, or batch code.
2. App shows search progress.
3. App returns ranked candidates.
4. Each candidate shows:
   - Product image
   - Display name in system language when available
   - English/official name
   - Brand
   - Category guess
   - Source label
   - Confidence label
5. User taps one candidate.
6. App previews fields that will be applied.
7. User confirms or edits before saving.

### Empty / Low Confidence Flow

If no strong candidate is found:

- Show "No reliable match found"
- Offer "Search web for official page"
- Keep manual fields visible
- Do not auto-fill suspicious data

## Ranking Rules

Priority should be:

1. Exact barcode match
2. Official brand domain match
3. Strong brand + product name match
4. Public product database match with image
5. Fuzzy text match without official source

Confidence labels:

- High: exact barcode or official page with matching brand/name
- Medium: public database result with image and matching brand/name
- Low: fuzzy text result, missing brand, or uncertain source

The app should auto-apply only after user confirmation. It should not silently overwrite existing fields.

## Data Fields To Fill

Current or near-term fields:

- Local name
- English or official name
- Brand
- Category
- Product image URL
- Official product page URL
- Batch code
- Manufacture date
- Manual expiry date when reliable
- Unopened shelf life months
- Period after opening months

Future fields:

- Barcode
- Region or market
- Size / volume
- Shade / color
- PAO label, such as 6M, 12M, 24M
- Source confidence
- Last lookup date

## Data Sources

### Phase 1: On-Device Public Sources

- Open Beauty Facts for product metadata and product images.
- User-entered official product page and image URL as fallback.
- Local brand/batch rule table for selected brands.

Benefits:

- No backend required.
- Simple privacy model.
- Works for a prototype.

Limitations:

- Coverage is incomplete.
- Data may be user-contributed.
- Official product pages are not guaranteed.

### Phase 2: Server-Assisted Official Lookup

Use a lightweight backend service to:

- Search the web using a licensed search API.
- Prefer known official domains.
- Extract page metadata from JSON-LD, Open Graph tags, and product schema.
- Return ranked candidates to the app.

Benefits:

- Better official-page matching.
- Can update source logic without shipping a new app.
- Can hide API keys from the iPhone app.

Limitations:

- Requires hosting and maintenance.
- Must respect site terms and rate limits.
- Needs careful privacy handling.

### Phase 3: Camera / Barcode / OCR

- Scan UPC/EAN barcode.
- Use Vision OCR to read batch code and PAO labels.
- Let the user confirm detected text.

## Success Metrics

- At least 70% of searches for common brands return one useful candidate.
- User can add a product with image and brand in under 30 seconds.
- Fewer than 5% of high-confidence candidates are clearly wrong in manual testing.
- Manual fallback remains available in every failed lookup path.

## Privacy And Trust

- Search terms should be sent only when the user taps search.
- The app should not upload the full inventory by default.
- If a backend is added, it should receive only the current query, not all stored products.
- Results should show source and confidence.
- Batch-code results should be labeled "estimated" unless sourced from official data.

## MVP Scope

MVP should include:

- Existing search sheet upgraded with better candidate display.
- Product candidate ranking and confidence.
- Category guess.
- Source labels.
- Manual fallback.
- Local batch-code parser infrastructure with a small starter set of rules.

MVP should not include:

- Fully automated official web crawling.
- User account sync.
- Cloud inventory backup.
- Camera OCR.

## Open Questions

- Which 10-20 brands should be supported first for batch-code parsing?
- Should official page lookup require a backend from the beginning, or start with public product database only?
- Should the app store image URLs only, or cache thumbnails locally?
- Should candidate source confidence be visible on product detail pages?
- Should a user be able to report a wrong candidate and correct it locally?
