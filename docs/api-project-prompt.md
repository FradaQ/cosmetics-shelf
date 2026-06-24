# Prompt For New API Project

Copy this prompt into a new Codex project when you are ready to build the backend API.

```text
I want to build a lightweight backend API for an iPhone app called Cosmetics Shelf.

Context:
- Cosmetics Shelf is a SwiftUI/SwiftData iOS app for tracking skincare, makeup, fragrance, hair/body products, batch codes, manufacture dates, expiry dates, and use-soon reminders.
- The iOS app already has local inventory, product editor, product image URL fields, Open Beauty Facts lookup, and a planned product lookup design.
- The API should help the app find product information automatically and eventually support batch-code lookup.

Primary goal:
Build a small, production-minded API service that receives a product lookup query and returns ranked product candidates with source, confidence, image URL, product page URL, brand, names, category guess, and match reasons.

Core endpoints:
1. GET /health
   - Return service status and version.

2. POST /v1/product-lookup
   Request:
   {
     "query": "Lancome Genifique serum",
     "brand": "Lancome",
     "barcode": "",
     "locale": "en-US",
     "preferredLanguage": "en"
   }
   Response:
   {
     "candidates": [
       {
         "id": "stable-id",
         "localName": "",
         "englishName": "Advanced Genifique Face Serum",
         "brand": "Lancome",
         "category": "skincare",
         "imageURL": "https://...",
         "productPageURL": "https://...",
         "barcode": "",
         "source": "officialWebsite",
         "confidence": "high",
         "matchReasons": ["official domain", "brand match", "name match"]
       }
     ]
   }

3. POST /v1/batch-lookup
   Request:
   {
     "brand": "Lancome",
     "batchCode": "40X600",
     "category": "skincare"
   }
   Response:
   {
     "manufactureDate": "2024-06-01",
     "expiryDate": "2027-06-01",
     "confidence": "medium",
     "source": "localRule",
     "sourceDescription": "Estimated from a brand-specific batch-code rule."
   }
   If unsupported, return a clear no-result response instead of guessing.

Implementation requirements:
- Choose a simple backend stack that is easy to deploy and maintain.
- Keep API keys server-side only. Do not expose search-provider keys to the iOS app.
- Start with a clean provider architecture:
  - OpenBeautyFactsProvider
  - OfficialSearchProvider
  - BatchRuleProvider
  - RankingService
- OfficialSearchProvider should prefer known official brand domains.
- Parse product pages using structured metadata first:
  - JSON-LD Product schema
  - Open Graph title/image/url
  - Twitter card metadata
  - HTML title fallback
- Do not scrape aggressively. Respect robots.txt, rate limits, and site terms.
- Add request validation, timeouts, retries where appropriate, and clear error responses.
- Add tests for ranking, validation, provider mapping, and unsupported batch-code cases.
- Add a README with local run instructions, environment variables, endpoint examples, and deployment notes.

Important product rules:
- Return candidates, not a single forced answer.
- Include source and confidence for every candidate.
- Never claim a batch-code result is official unless the source is actually official.
- For batch codes, use known brand-specific rules only; if no reliable rule exists, return no result and tell the app to use manual entry.
- The API should not store a user's full inventory. It should only process the current lookup query.

Recommended first milestone:
- Implement /health and /v1/product-lookup with Open Beauty Facts plus ranking.
- Stub OfficialSearchProvider behind an interface.
- Implement /v1/batch-lookup with no-result fallback and a small testable rule-engine skeleton.
- Add unit tests and an example curl collection.

Please first inspect the repo structure, then propose a short implementation plan, then create the API project files, tests, and README. After implementation, run tests and show me how to start the server locally.
```
