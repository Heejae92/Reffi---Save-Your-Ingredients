#!/usr/bin/env python3
"""Run the opt-in iOS Vision + ReceiptParser corpus benchmark without changing stock.

Usage: python3 scripts/run-receipt-corpus.py CORPUS_DIR --device SIMULATOR_UUID
The directory must contain manifest.json and its referenced local image files.
Images are never uploaded. Download/ground-truth curation is a separate step.
"""
import argparse
import hashlib
import json
import plistlib
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("corpus", type=Path)
parser.add_argument("--device", required=True)
parser.add_argument("--derived-data", type=Path, default=Path("/tmp/reffi-receipt-corpus-build"))
parser.add_argument("--skip-build", action="store_true")
args = parser.parse_args()
root = args.corpus.resolve()
manifest = json.loads((root / "manifest.json").read_text())
for record in manifest:
    if record.get("status") != "downloaded":
        continue
    path = (root / record["path"]).resolve()
    if root not in path.parents:
        raise SystemExit(f"Image must be inside corpus directory: {record['id']}")
    if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        raise SystemExit(f"Image checksum mismatch: {record['id']}")
destination = f"platform=iOS Simulator,id={args.device}"
derived = args.derived_data.resolve()
if not args.skip_build:
    subprocess.run(["xcodegen", "generate"], cwd=REPO, check=True)
    subprocess.run(["xcodebuild", "-project", "Reffi.xcodeproj", "-scheme", "Reffi",
                    "-destination", destination, "-derivedDataPath", str(derived),
                    "build-for-testing"], cwd=REPO, check=True)
products = derived / "Build/Products"
base = sorted(p for p in products.glob("Reffi_*.xctestrun") if p.name != "ReffiCorpus.xctestrun")
if len(base) != 1:
    raise SystemExit(f"Expected one Reffi xctestrun, found {len(base)} in {products}")
config = plistlib.loads(base[0].read_bytes())
if "TestConfigurations" in config:
    targets = [target for c in config["TestConfigurations"] for target in c["TestTargets"]]
else:
    targets = [v for k, v in config.items() if not k.startswith("__") and isinstance(v, dict)]
for target in targets:
    target.setdefault("EnvironmentVariables", {})["REFFI_RECEIPT_CORPUS"] = str(root)
run_file = products / "ReffiCorpus.xctestrun"
run_file.write_bytes(plistlib.dumps(config))
sources = ["Reffi/Data/ReceiptParser.swift", "Reffi/Data/ReceiptRecognition.swift", "Reffi/Resources/receipt-products.json", "Reffi/Data/IngredientLexicon.swift",
           "Reffi/Features/AddIngredient/ReceiptScanView.swift",
           "Reffi/Resources/ingredient-lexicon.json", "ReffiTests/ReceiptCorpusTests.swift"]
metadata = {"sourceSHA256": {p: hashlib.sha256((REPO / p).read_bytes()).hexdigest() for p in sources},
            "manifestSHA256": hashlib.sha256((root / "manifest.json").read_bytes()).hexdigest(),
            "gitHEAD": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
            "device": args.device,
            "note": "Hashes include uncommitted working-tree changes; see sourceSHA256."}
(root / "run-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
output = root / "results.json"
if output.exists():
    output.rename(root / "results.previous.json")
subprocess.run(["xcodebuild", "test-without-building", "-xctestrun", str(run_file),
                "-destination", destination, "-only-testing:ReffiTests/ReceiptCorpusTests",
                "-parallel-testing-enabled", "NO"], cwd=REPO, check=True)
if not output.exists():
    raise SystemExit("Test finished without results.json; check test environment forwarding.")
print(f"Corpus results: {output}")
