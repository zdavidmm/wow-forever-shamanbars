import argparse
import re
from pathlib import Path
from urllib.request import urlopen

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
UI_COMMIT = "bebcb6bf309cf41b41bd74f8ca651e6a105b2676"
API_BASE = (
    f"https://raw.githubusercontent.com/Gethe/wow-ui-source/{UI_COMMIT}"
    "/Interface/AddOns/Blizzard_APIDocumentationGenerated"
)


def main():
    parser = argparse.ArgumentParser(description="Validate ShamanBars without running WoW.")
    parser.add_argument("--addon", type=Path, default=ROOT / "ShamanBars")
    parser.add_argument(
        "--check-apis",
        action="store_true",
        help="Also compare API names with public UI documentation for build 70938 (network required).",
    )
    args = parser.parse_args()
    addon = args.addon.resolve()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    print(f"Runtime: {runtime.eval('_VERSION')}; addon: {addon}", flush=True)

    toc = addon / "ShamanBars.toc"
    metadata = toc.read_text(encoding="utf-8-sig")
    assert re.search(r"^## Interface: 16001$", metadata, re.M), "Wrong client interface"
    assert re.search(r"^## SavedVariablesPerCharacter: ShamanBarsBackup$", metadata, re.M)
    references = [
        line.strip()
        for line in metadata.splitlines()
        if line.strip() and not line.startswith("#")
    ]
    for reference in references:
        path = addon / reference
        assert path.is_file(), f"Missing TOC reference: {reference}"
        if path.suffix == ".lua":
            runtime.compile(path.read_text(encoding="utf-8-sig"), name=f"@{path.name}")
    assert list(addon.rglob("*.toc")) == [toc], "Unexpected nested addon"
    print("PASS TOC references, backup metadata, folder layout, Lua 5.1 syntax", flush=True)

    source = (addon / "ShamanBars.lua").read_text(encoding="utf-8-sig")
    if args.check_apis:
        for namespace, filename in [
            ("C_SpellBook", "SpellBookDocumentation.lua"),
            ("C_Spell", "SpellDocumentation.lua"),
            ("C_ActionBar", "ActionBarFrameDocumentation.lua"),
        ]:
            with urlopen(f"{API_BASE}/{filename}", timeout=30) as response:
                docs = response.read().decode("utf-8-sig")
            documented = set(re.findall(r'Name = "(\w+)"', docs))
            used = set(re.findall(rf"\b{namespace}\.(\w+)", source))
            assert used <= documented, f"Undocumented {namespace} API: {used - documented}"
            print(f"PASS exact-build API names: {namespace}: {', '.join(sorted(used))}", flush=True)

    runtime.globals().ADDON_SOURCE = source
    tests, failures = runtime.execute(
        (ROOT / "tests" / "test_shamanbars.lua").read_text(encoding="utf-8")
    )
    if failures:
        raise SystemExit(1)
    print(f"PASS {tests} mocked behavior tests (not live in-game testing)", flush=True)


if __name__ == "__main__":
    main()
