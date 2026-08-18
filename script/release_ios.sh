#!/usr/bin/env bash
set -euo pipefail

mode="${1:-build}"
case "$mode" in
build | upload) ;;
*)
	echo "Usage: script/release_ios.sh [build|upload]" >&2
	exit 64
	;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive="$root/dist/ios/jellyboy.xcarchive"
export_dir="$root/dist/ios/export"
started_at="$(date +%s)"
signing_dir="${JELLYBOY_SIGNING_DIR:-$HOME/.appstoreconnect/signing/jellyboy}"
release_keychain="$signing_dir/jellyboy.keychain-db"
release_password_file="$signing_dir/keychain-password"
release_certificate="$signing_dir/distribution.p12"
release_profile="$signing_dir/jellyboy_App_Store.mobileprovision"
profile_uuid="deb40493-2aaf-425d-ba27-1320058d3e55"
profile_name="jellyboy App Store"
original_keychains=()

restore_keychain_search_list() {
	if ((${#original_keychains[@]} > 0)); then
		security list-keychains -d user -s "${original_keychains[@]}"
	fi
}

prepare_signing() {
	for required_file in "$release_password_file" "$release_certificate" "$release_profile"; do
		if [[ ! -f "$required_file" ]]; then
			echo "Missing jellyboy signing file: $required_file" >&2
			exit 1
		fi
	done

	release_password="$(sed -n '1p' "$release_password_file")"
	if [[ ! -f "$release_keychain" ]]; then
		security create-keychain -p "$release_password" "$release_keychain"
		security import "$release_certificate" \
			-k "$release_keychain" \
			-P "$release_password" \
			-T /usr/bin/codesign \
			-T /usr/bin/security >/dev/null
	fi

	security unlock-keychain -p "$release_password" "$release_keychain"
	security set-keychain-settings -lut 21600 "$release_keychain"
	security set-key-partition-list \
		-S apple-tool:,apple: \
		-s \
		-k "$release_password" \
		"$release_keychain" >/dev/null

	while IFS= read -r keychain; do
		original_keychains+=("$keychain")
	done < <(security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"$//')
	security list-keychains -d user -s "$release_keychain" "${original_keychains[@]}"
	trap restore_keychain_search_list EXIT

	profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
	mkdir -p "$profile_dir"
	cp "$release_profile" "$profile_dir/$profile_uuid.mobileprovision"
	chmod 600 "$profile_dir/$profile_uuid.mobileprovision"
}

cd "$root"

if [[ "$mode" == "upload" ]] && [[ -n "$(git status --porcelain)" ]]; then
	echo "Refusing to upload from a dirty working tree. Commit the release first." >&2
	exit 1
fi

"$root/script/verify.sh"
prepare_signing

xcodebuild \
	-project "$root/jellyboy.xcodeproj" \
	-scheme jellyboy \
	-configuration Release \
	-destination "generic/platform=iOS" \
	-archivePath "$archive" \
	CODE_SIGN_STYLE=Manual \
	CODE_SIGN_IDENTITY="Apple Distribution" \
	PROVISIONING_PROFILE_SPECIFIER="$profile_name" \
	OTHER_CODE_SIGN_FLAGS="--keychain $release_keychain" \
	archive

xcodebuild \
	-exportArchive \
	-archivePath "$archive" \
	-exportPath "$export_dir" \
	-exportOptionsPlist "$root/distribution/AppStoreExportOptions.plist"

ipa="$(find "$export_dir" -maxdepth 1 -type f -name '*.ipa' -print -quit 2>/dev/null || true)"
if [[ -z "$ipa" ]] || [[ "$(stat -f %m "$ipa")" -lt "$started_at" ]]; then
	echo "No fresh App Store IPA was exported." >&2
	exit 1
fi

echo "Exported $ipa"

if [[ "$mode" == "upload" ]]; then
	key_id="${APP_STORE_CONNECT_KEY_ID:-DC6F5JMNM3}"
	issuer_id="${APP_STORE_CONNECT_ISSUER_ID:-19bebb70-4123-40d3-9379-1476fcc51b60}"
	key_dir="${API_PRIVATE_KEYS_DIR:-$HOME/.appstoreconnect/private_keys}"

	if [[ ! -f "$key_dir/AuthKey_$key_id.p8" ]]; then
		echo "Missing App Store Connect key: $key_dir/AuthKey_$key_id.p8" >&2
		exit 1
	fi

	xcrun altool --validate-app \
		--file "$ipa" \
		--type ios \
		--apiKey "$key_id" \
		--apiIssuer "$issuer_id"

	xcrun altool --upload-app \
		--file "$ipa" \
		--type ios \
		--apiKey "$key_id" \
		--apiIssuer "$issuer_id"
fi
