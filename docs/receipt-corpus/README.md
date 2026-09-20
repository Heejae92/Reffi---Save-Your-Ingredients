# Public receipt evaluation metadata

18 public-image source pages, local image filenames and SHA-256 checksums, manual product transcriptions, accepted ingredient IDs, and final type-level scores are retained here. Raw photographs and raw OCR (which can contain receipt account details) stay in gitignored `output/receipt-verification-2026-09-20/`. Temporary signed download URLs are excluded from this repository.

To rerun, copy manifest.json to a local corpus directory and place the matching original images at each `path`, then run `scripts/run-receipt-corpus.py` with that directory and a simulator UUID. The runner verifies image hashes. Download permissions and availability are the source websites' responsibility; public access does not grant redistribution rights.

See ../RECEIPT_RELIABILITY_REVIEW.md for methodology, baseline comparison, and limitations. The final parser was tuned using these images, so these scores are regression evidence, not independent model validation. `correctAutomatic` scores ingredient identity only; the single automatically selected quantity was separately checked against the photograph.
