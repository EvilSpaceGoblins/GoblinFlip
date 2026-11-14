"""Build a clean addon ZIP from the actual TOC, with bundled license files."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent.parent
manifest = root / "GoblinFlip.toc"
version = re.search(r"^## Version: (.+)$", manifest.read_text(), re.M).group(1)
files = [manifest, root / "README.md", root / "THIRD_PARTY.md", root / "docs" / "IMPLEMENTATION.md"]
files += [root / line.replace("\\", "/") for line in manifest.read_text().splitlines() if line.endswith(".lua")]
files += list((root / "Libs").rglob("LICENSE*"))
if (root / "LICENSE").exists():
    files.append(root / "LICENSE")
for path in files:
    if not path.is_file():
        raise SystemExit(f"Missing release file: {path}")
destination = root / "dist" / f"GoblinFlip-{version}.zip"
destination.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(set(files)):
        archive.write(path, Path("GoblinFlip") / path.relative_to(root))
print(destination)
