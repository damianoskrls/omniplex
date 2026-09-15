#!/usr/bin/env python3
"""
BookUp white-label tenant build script.
Fetches tenant config from Admin API, applies branding, and builds iOS/Android.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Install dependencies: pip install requests Pillow", file=sys.stderr)
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    Image = None


ROOT = Path(__file__).resolve().parents[1]
FLUTTER_ROOT = Path(os.environ.get("FLUTTER_ROOT", ROOT / "flutter-app"))


def fetch_tenant_config(tenant_id: str, api_base: str, secret: str) -> dict:
    url = f"{api_base.rstrip('/')}/api/tenants/{tenant_id}/build-config"
    headers = {"Authorization": f"Bearer {secret}"}
    res = requests.get(url, headers=headers, timeout=30)
    res.raise_for_status()
    data = res.json()
    data["api_base_url"] = api_base.rstrip("/")
    return data


def write_tenant_config(config: dict) -> None:
    assets = FLUTTER_ROOT / "assets"
    assets.mkdir(parents=True, exist_ok=True)

    payload = {
        "business_id": config["id"],
        "slug": config.get("slug", ""),
        "app_name": config.get("app_name", config.get("name", "BookUp")),
        "bundle_id": config.get("bundle_id", "com.bookup.app"),
        "api_base_url": config.get("api_base_url", "http://localhost:3001"),
        "primary_color": config.get("primary_color", "#6200EE"),
        "secondary_color": config.get("secondary_color", "#03DAC6"),
        "accent_color": config.get("accent_color", "#FF6D00"),
        "logo_url": config.get("logo_url"),
        "feature_online_booking": config.get("feature_online_booking", 1),
        "feature_loyalty_points": config.get("feature_loyalty_points", 0),
        "feature_memberships": config.get("feature_memberships", 0),
        "label_overrides": config.get("label_overrides") or {},
    }

    if isinstance(payload["label_overrides"], str):
        payload["label_overrides"] = json.loads(payload["label_overrides"])

    (assets / "tenant_config.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def download_logo(config: dict, api_base: str) -> None:
    logo_url = config.get("logo_url")
    if not logo_url:
        return

    dest = FLUTTER_ROOT / "assets" / "logo.png"
    full_url = logo_url if logo_url.startswith("http") else f"{api_base.rstrip('/')}{logo_url}"
    res = requests.get(full_url, timeout=30)
    res.raise_for_status()
    dest.write_bytes(res.content)

    if Image is None:
        return

    img = Image.open(dest).convert("RGBA")
    _generate_ios_icons(img, FLUTTER_ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset")
    _generate_android_icons(img, FLUTTER_ROOT / "android" / "app" / "src" / "main" / "res")


def _generate_ios_icons(img: Image.Image, iconset: Path) -> None:
    """Generate basic iOS app icons from tenant logo."""
    iconset.mkdir(parents=True, exist_ok=True)
    sizes = [20, 29, 40, 60, 76, 83.5, 1024]
    images = []
    for size in sizes:
        for scale in (1, 2, 3):
            px = int(size * scale)
            if px > 1024:
                continue
            filename = f"icon_{px}.png"
            resized = img.resize((px, px), Image.Resampling.LANCZOS)
            resized.save(iconset / filename)
            images.append({
                "size": f"{size}x{size}",
                "idiom": "iphone" if size != 76 else "ipad",
                "filename": filename,
                "scale": f"{scale}x",
            })

    contents = {"images": images, "info": {"version": 1, "author": "xcode"}}
    (iconset / "Contents.json").write_text(json.dumps(contents, indent=2))


def _generate_android_icons(img: Image.Image, res_root: Path) -> None:
    """Generate Android launcher icons in standard mipmap folders."""
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in densities.items():
        out_dir = res_root / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        resized = img.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_dir / "ic_launcher.png")


def patch_ios_bundle_id(bundle_id: str, app_name: str) -> None:
    pbxproj = FLUTTER_ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"
    text = pbxproj.read_text(encoding="utf-8")
    text = re.sub(
        r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;',
        f'PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};',
        text,
    )
    pbxproj.write_text(text, encoding="utf-8")

    info_plist = FLUTTER_ROOT / "ios" / "Runner" / "Info.plist"
    plist = info_plist.read_text(encoding="utf-8")
    plist = re.sub(
        r"<key>CFBundleDisplayName</key>\s*<string>[^<]*</string>",
        f"<key>CFBundleDisplayName</key>\n\t<string>{app_name}</string>",
        plist,
    )
    info_plist.write_text(plist, encoding="utf-8")


def patch_android_package(package: str, app_name: str) -> None:
    gradle = FLUTTER_ROOT / "android" / "app" / "build.gradle.kts"
    text = gradle.read_text(encoding="utf-8")
    text = re.sub(r'applicationId = "[^"]+"', f'applicationId = "{package}"', text)
    text = re.sub(r'namespace = "[^"]+"', f'namespace = "{package}"', text)
    gradle.write_text(text, encoding="utf-8")

    manifest = FLUTTER_ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if manifest.exists():
        m = manifest.read_text(encoding="utf-8")
        m = re.sub(r'android:label="[^"]*"', f'android:label="{app_name}"', m)
        manifest.write_text(m, encoding="utf-8")


def run_flutter_build(platform: str, output_dir: Path, tenant_id: str) -> None:
    subprocess.run(["flutter", "pub", "get"], cwd=FLUTTER_ROOT, check=True)

    tenant_out = output_dir / tenant_id
    tenant_out.mkdir(parents=True, exist_ok=True)

    if platform in ("android", "both"):
        subprocess.run(
            ["flutter", "build", "apk", "--release"],
            cwd=FLUTTER_ROOT,
            check=True,
        )
        apk = FLUTTER_ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        shutil.copy2(apk, tenant_out / f"{tenant_id}.apk")

    if platform in ("ios", "both"):
        subprocess.run(
            ["flutter", "build", "ipa", "--release"],
            cwd=FLUTTER_ROOT,
            check=True,
        )
        ipa_dir = FLUTTER_ROOT / "build" / "ios" / "ipa"
        for ipa in ipa_dir.glob("*.ipa"):
            shutil.copy2(ipa, tenant_out / f"{tenant_id}.ipa")
            break


def main() -> None:
    parser = argparse.ArgumentParser(description="Build white-label BookUp tenant app")
    parser.add_argument("--tenant-id", required=True)
    parser.add_argument("--platform", choices=["android", "ios", "both"], default="ios")
    parser.add_argument("--output-dir", default="./dist")
    parser.add_argument("--api-base", default=os.environ.get("ADMIN_API_BASE_URL", "http://localhost:3001"))
    parser.add_argument("--api-secret", default=os.environ.get("ADMIN_API_SECRET", ""))
    parser.add_argument("--skip-build", action="store_true", help="Only apply config, do not run flutter build")
    args = parser.parse_args()

    if not args.api_secret:
        print("Warning: ADMIN_API_SECRET not set — using local tenant_config.json", file=sys.stderr)
        config = json.loads((FLUTTER_ROOT / "assets" / "tenant_config.json").read_text())
        config["id"] = config.get("business_id", args.tenant_id)
    else:
        config = fetch_tenant_config(args.tenant_id, args.api_base, args.api_secret)

    write_tenant_config(config)
    download_logo(config, args.api_base)

    bundle_id = config.get("bundle_id", "com.bookup.app")
    app_name = config.get("app_name", config.get("name", "BookUp"))
    patch_ios_bundle_id(bundle_id, app_name)
    patch_android_package(bundle_id, app_name)

    print(f"Applied config for {app_name} ({bundle_id})")

    if not args.skip_build:
        run_flutter_build(args.platform, Path(args.output_dir), args.tenant_id)
        print(f"Build complete → {args.output_dir}/{args.tenant_id}/")


if __name__ == "__main__":
    main()
