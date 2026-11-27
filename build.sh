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
helper="$contents/Helpers/Quit.app"
mkdir -p "$helper/Contents/MacOS"
cp "$project_dir/Resources/QuitInfo.plist" "$helper/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string "$version" "$helper/Contents/Info.plist"
plutil -insert CFBundleVersion -string "$revision" "$helper/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$extension/Contents/Resources/AppIcon.icns"
cp "$project_dir/Resources/AppIcon.icns" "$contents/Resources/AppIcon.icns"
/usr/bin/osacompile -o "$contents/Resources/finder-directory.scpt" "$project_dir/Sources/App/finder-directory.applescript"

for arch in arm64 x86_64; do
    xcrun swiftc -O -target "$arch-apple-macosx11.0" -module-cache-path "$stage/module-cache" \
        "$project_dir/Sources/Quit/main.swift" "$project_dir/Sources/App/ExtensionElection.swift" -o "$stage/Quit-$arch"
    xcrun swiftc -O -parse-as-library -target "$arch-apple-macosx11.0" -module-cache-path "$stage/module-cache" \
        -o "$stage/FinderToITerm-$arch" "$project_dir/Sources/App/"*.swift "$project_dir/Sources/Shared/"*.swift
    xcrun swiftc -O -parse-as-library -application-extension -target "$arch-apple-macosx11.0" \
        -module-cache-path "$stage/module-cache" -Xlinker -e -Xlinker _NSExtensionMain -lextension \
        "$project_dir/FinderExtension/FinderMenu.swift" "$project_dir/Sources/Shared/"*.swift \
        -o "$stage/FinderMenu-$arch"
done
xcrun lipo -create "$stage/Quit-arm64" "$stage/Quit-x86_64" -output "$helper/Contents/MacOS/Quit"
xcrun lipo -create "$stage/FinderMenu-arm64" "$stage/FinderMenu-x86_64" -output "$extension/Contents/MacOS/FinderMenu"
xcrun lipo -create "$stage/FinderToITerm-arm64" "$stage/FinderToITerm-x86_64" \
    -output "$contents/MacOS/FinderToITerm"

if [[ -n "${APP_SIGNING_IDENTITY:-}${NOTARYTOOL_PROFILE:-}" ]]; then
    : "${APP_SIGNING_IDENTITY:?Set a Developer ID Application signing identity}"
    codesign --force --options runtime --timestamp --sign "$APP_SIGNING_IDENTITY" "$helper"
    codesign --force --options runtime --timestamp --sign "$APP_SIGNING_IDENTITY" \
        --entitlements "$project_dir/FinderExtension/Extension.entitlements" "$extension"
    codesign --force --options runtime --timestamp --sign "$APP_SIGNING_IDENTITY" \
        --entitlements "$project_dir/Resources/Automation.entitlements" "$stage/$app_name"
else
    codesign --force --sign - "$helper"
    codesign --force --sign - --entitlements "$project_dir/FinderExtension/Extension.entitlements" "$extension"
    codesign --force --sign - "$stage/$app_name"
fi
codesign --verify --deep --strict "$stage/$app_name"

image_root="$stage/image-root"
mkdir -p "$image_root"
ditto "$stage/$app_name" "$image_root/$app_name"
ln -s /Applications "$image_root/Applications"
cp "$project_dir/Installer/首次打开说明.html" "$image_root/"
cp "$project_dir/Installer/FinderLayout.dsstore" "$image_root/.DS_Store"
image_name="f2s.dmg"
hdiutil create -fs HFS+ -format UDZO -volname f2s -srcfolder "$image_root" "$stage/$image_name"

if [[ -n "${APP_SIGNING_IDENTITY:-}" ]]; then
    codesign --timestamp --sign "$APP_SIGNING_IDENTITY" --identifier local.finder-to-iterm.dmg "$stage/$image_name"
fi

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$stage/$image_name" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple "$stage/$image_name"
    xcrun stapler validate "$stage/$image_name"
fi

ditto "$stage/$app_name" "$build_dir/$app_name"
codesign --verify --strict "$build_dir/$app_name"
mv -f "$stage/$image_name" "$build_dir/$image_name"
printf '%s\n' "$build_dir/$image_name"
