# PhotoTinder

SwiftUI photo cleanup app refreshed for the iOS 26 Liquid Glass visual language.

## Build target

- Minimum deployment target: iOS 26.0
- Recommended toolchain: Xcode 26.4 with the iOS 26 SDK
- Project generation: `xcodegen generate`

## GitHub Release workflow

- Push a tag such as `v1.0.0` to build an unsigned IPA and publish a GitHub Release automatically.
- Or run the `Release Unsigned IPA` workflow manually and provide a release tag.
- The generated `.ipa` is unsigned. A device-installable build still needs your Apple signing certificate and provisioning profile.
