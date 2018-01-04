#!/bin/bash
echo "[*] Compiling Houdini.."
$(which xcodebuild) clean build CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -sdk `xcrun --sdk iphoneos --show-sdk-path` -arch arm64
mv build/Release-iphoneos/houdini.app houdini.app
mkdir Payload
mv houdini.app Payload/houdini.app
echo "[*] Zipping into .ipa"
zip -r9 Houdini.ipa Payload/houdini.app
rm -rf build Payload
echo "[*] Done! Install .ipa with Impactor"
