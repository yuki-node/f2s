#!/bin/bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "$0")" && pwd)
build_dir="$project_dir/build"
app_name='f2s.app'
stage=$(mktemp -d "${TMPDIR:-/tmp}/finder-to-iterm.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT

contents="$stage/$app_name/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources" "$build_dir"

cp "$project_dir/Resources/Info.plist" "$contents/Info.plist"
version=$(plutil -extract CFBundleShortVersionString raw "$contents/Info.plist")
revision=$(plutil -extract CFBundleVersion raw "$contents/Info.plist")
extension="$contents/PlugIns/FinderMenu.appex"
mkdir -p "$extension/Contents/MacOS" "$extension/Contents/Resources"
cp "$project_dir/FinderExtension/Info.plist" "$extension/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string "$version" "$extension/Contents/Info.plist"
plutil -insert CFBundleVersion -string "$revision" "$extension/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$extension/Contents/Resources/AppIcon.icns"
cp "$project_dir/Resources/AppIcon.icns" "$contents/Resources/AppIcon.icns"
/usr/bin/osacompile -o "$contents/Resources/finder-directory.scpt" "$project_dir/Sources/App/finder-directory.applescript"

for arch in arm64 x86_64; do
    xcrun swiftc -O -parse-as-library -target "$arch-apple-macosx11.0" -module-cache-path "$stage/module-cache" \
        -o "$stage/FinderToITerm-$arch" "$project_dir/Sources/App/"*.swift "$project_dir/Sources/Shared/"*.swift
    xcrun swiftc -O -parse-as-library -application-extension -target "$arch-apple-macosx11.0" \
        -module-cache-path "$stage/module-cache" -Xlinker -e -Xlinker _NSExtensionMain -lextension \
        "$project_dir/FinderExtension/FinderMenu.swift" "$project_dir/Sources/Shared/"*.swift \
        -o "$stage/FinderMenu-$arch"
done
xcrun lipo -create "$stage/FinderMenu-arm64" "$stage/FinderMenu-x86_64" -output "$extension/Contents/MacOS/FinderMenu"
xcrun lipo -create "$stage/FinderToITerm-arm64" "$stage/FinderToITerm-x86_64" \
    -output "$contents/MacOS/FinderToITerm"

package_signing=()
if [[ -n "${APP_SIGNING_IDENTITY:-}${INSTALLER_SIGNING_IDENTITY:-}${NOTARYTOOL_PROFILE:-}" ]]; then
    : "${APP_SIGNING_IDENTITY:?Set a Developer ID Application signing identity}"
    : "${INSTALLER_SIGNING_IDENTITY:?Set a Developer ID Installer signing identity}"
    codesign --force --options runtime --timestamp --sign "$APP_SIGNING_IDENTITY" \
        --entitlements "$project_dir/FinderExtension/Extension.entitlements" "$extension"
    codesign --force --options runtime --timestamp --sign "$APP_SIGNING_IDENTITY" \
        --entitlements "$project_dir/Resources/Automation.entitlements" "$stage/$app_name"
    package_signing=(--sign "$INSTALLER_SIGNING_IDENTITY")
else
    codesign --force --sign - --entitlements "$project_dir/FinderExtension/Extension.entitlements" "$extension"
    codesign --force --sign - "$stage/$app_name"
fi
codesign --verify --deep --strict "$stage/$app_name"

payload="$stage/payload"
installer="$project_dir/Installer"
mkdir -p "$payload" "$stage/scripts"
ditto "$stage/$app_name" "$payload/$app_name"
install -m 755 "$installer/postinstall" "$stage/scripts/postinstall"
pkgbuild --analyze --root "$payload" "$stage/components.plist"
plutil -replace 0.BundleIsRelocatable -bool NO "$stage/components.plist"
pkgbuild --root "$payload" --component-plist "$stage/components.plist" --scripts "$stage/scripts" \
    --identifier local.finder-to-iterm.pkg --version "$version" --install-location /Applications "$stage/FinderToITerm.pkg"

package_name="f2s-$version.pkg"
productbuild --distribution "$installer/Distribution.xml" --package-path "$stage" \
    --resources "$installer/Resources" ${package_signing[@]+"${package_signing[@]}"} "$stage/$package_name"

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$stage/$package_name" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple "$stage/$package_name"
    xcrun stapler validate "$stage/$package_name"
fi

ditto "$stage/$app_name" "$build_dir/$app_name"
codesign --verify --strict "$build_dir/$app_name"
mv -f "$stage/$package_name" "$build_dir/$package_name"
printf '%s\n' "$build_dir/$package_name"
