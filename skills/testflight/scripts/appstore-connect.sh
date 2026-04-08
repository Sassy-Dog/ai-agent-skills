#!/usr/bin/env bash

# App Store Connect API query tool
# Generates an ES256 JWT and queries TestFlight-related endpoints.
#
# Requirements: openssl, curl, jq, base64
# Env vars:
#   APPLE_APP_STORE_CONNECT_API_KEY_ID
#   APPLE_APP_STORE_CONNECT_ISSUER_ID
#   APPLE_APP_STORE_CONNECT_API_KEY_BASE64

set -euo pipefail

BUNDLE_ID="${1:?Usage: $0 <bundle-id> [feedback|testers|builds|groups|raw <path>]}"
COMMAND="${2:-feedback}"

# --- Validate env vars ---
for var in APPLE_APP_STORE_CONNECT_API_KEY_ID APPLE_APP_STORE_CONNECT_ISSUER_ID APPLE_APP_STORE_CONNECT_API_KEY_BASE64; do
    if [[ -z "${!var:-}" ]]; then
        echo "❌ Missing env var: $var" >&2
        echo "   Add Apple App Store Connect credentials to Doppler, then: direnv allow" >&2
        exit 1
    fi
done

KEY_ID="$APPLE_APP_STORE_CONNECT_API_KEY_ID"
ISSUER_ID="$APPLE_APP_STORE_CONNECT_ISSUER_ID"
API_KEY_BASE64="$APPLE_APP_STORE_CONNECT_API_KEY_BASE64"

# --- Decode key to temp file ---
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

API_KEY_FILE="$TEMP_DIR/AuthKey_${KEY_ID}.p8"
echo "$API_KEY_BASE64" | base64 --decode > "$API_KEY_FILE"

# --- Generate JWT (ES256, 20-min expiry) ---
b64url() { base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

JWT_HEADER=$(echo -n '{"alg":"ES256","kid":"'"$KEY_ID"'","typ":"JWT"}' | b64url)
ISSUED_AT=$(date +%s)
EXPIRATION=$((ISSUED_AT + 1200))
JWT_PAYLOAD=$(echo -n '{"iss":"'"$ISSUER_ID"'","iat":'"$ISSUED_AT"',"exp":'"$EXPIRATION"',"aud":"appstoreconnect-v1"}' | b64url)
JWT_SIGNING_INPUT="$JWT_HEADER.$JWT_PAYLOAD"
JWT_SIGNATURE=$(echo -n "$JWT_SIGNING_INPUT" | openssl dgst -binary -sha256 -sign "$API_KEY_FILE" | b64url)
JWT="$JWT_SIGNING_INPUT.$JWT_SIGNATURE"

# --- API helper ---
API_BASE="https://api.appstoreconnect.apple.com"

asc_get() {
    local url="$1"
    local response http_code body

    response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $JWT" "$url")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        echo "❌ HTTP $http_code from: $url" >&2
        echo "$body" | jq '.' 2>/dev/null || echo "$body" >&2
        return 1
    fi

    echo "$body"
}

# --- Resolve app ID ---
echo "===> Looking up app: $BUNDLE_ID" >&2
APP_RESPONSE=$(asc_get "$API_BASE/v1/apps?filter[bundleId]=$BUNDLE_ID")
APP_ID=$(echo "$APP_RESPONSE" | jq -r '.data[0].id // empty')

if [[ -z "$APP_ID" ]]; then
    echo "❌ No app found with bundle ID: $BUNDLE_ID" >&2
    echo "Available apps:" >&2
    ALL_APPS=$(asc_get "$API_BASE/v1/apps?limit=50" 2>/dev/null || true)
    echo "$ALL_APPS" | jq -r '.data[]? | "  \(.attributes.bundleId) — \(.attributes.name)"' 2>/dev/null >&2
    exit 1
fi

APP_NAME=$(echo "$APP_RESPONSE" | jq -r '.data[0].attributes.name')
echo "    Found: $APP_NAME (ID: $APP_ID)" >&2
echo "" >&2

# --- Commands ---
case "$COMMAND" in
    feedback)
        echo "===> TestFlight Builds" >&2
        BUILDS=$(asc_get "$API_BASE/v1/builds?filter[app]=$APP_ID&sort=-uploadedDate&limit=10")
        echo "$BUILDS" | jq -r '.data[] | "  v\(.attributes.version) (\(.attributes.uploadedDate[:10])) — \(.attributes.processingState)"' >&2
        echo "" >&2

        echo "===> Beta Feedback" >&2
        FEEDBACK=$(asc_get "$API_BASE/v1/apps/$APP_ID/betaFeedbacks?limit=25&sort=-timestamp" 2>/dev/null || echo '{"errors":[]}')
        FEEDBACK_COUNT=$(echo "$FEEDBACK" | jq '.data | length // 0' 2>/dev/null)

        if [[ "$FEEDBACK_COUNT" -gt 0 ]]; then
            echo "$FEEDBACK" | jq '.'
        else
            ERROR=$(echo "$FEEDBACK" | jq -r '.errors[0].title // empty' 2>/dev/null)
            if [[ -n "$ERROR" ]]; then
                echo "Note: betaFeedbacks endpoint returned: $ERROR" >&2
                echo "Shake-to-report feedback may only be available in App Store Connect UI." >&2
            else
                echo "No beta feedback found." >&2
            fi
            echo '{"data":[]}'
        fi
        ;;

    testers)
        echo "===> Beta Testers" >&2
        TESTERS=$(asc_get "$API_BASE/v1/betaTesters?filter[apps]=$APP_ID&limit=200")
        echo "$TESTERS" | jq '.'
        ;;

    builds)
        echo "===> Recent Builds" >&2
        BUILDS=$(asc_get "$API_BASE/v1/builds?filter[app]=$APP_ID&sort=-uploadedDate&limit=20")
        echo "$BUILDS" | jq '.'
        ;;

    groups)
        echo "===> Beta Groups" >&2
        GROUPS=$(asc_get "$API_BASE/v1/apps/$APP_ID/betaGroups")
        echo "$GROUPS" | jq '.'
        ;;

    raw)
        RAW_PATH="${3:?Usage: $0 <bundle-id> raw <api-path>}"
        # Replace {appId} placeholder with resolved app ID
        RAW_PATH="${RAW_PATH//\{appId\}/$APP_ID}"
        echo "===> GET $RAW_PATH" >&2
        asc_get "$API_BASE$RAW_PATH"
        ;;

    *)
        echo "Usage: $0 <bundle-id> [feedback|testers|builds|groups|raw <path>]" >&2
        exit 1
        ;;
esac
