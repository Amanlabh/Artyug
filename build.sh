#!/bin/bash
set -e

# â”€â”€â”€ Generate .env from Vercel environment variables â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# The .env file is gitignored but required as a Flutter asset (pubspec.yaml).
# On Vercel, set these as Environment Variables in the project settings.
echo "Generating .env from Vercel environment variables..."
cat > .env << EOF
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
API_BASE_URL=${API_BASE_URL:-https://app.artyug.art}
ARTYUG_APP_MODE=${ARTYUG_APP_MODE:-live}
ARTYUG_CHAIN_MODE=${ARTYUG_CHAIN_MODE:-devnet}
ENABLE_NFC=${ENABLE_NFC:-false}
ENABLE_SOLANA=${ENABLE_SOLANA:-true}
SOLANA_RPC_URL=${SOLANA_RPC_URL:-}
SOLANA_PRIVATE_KEY=${SOLANA_PRIVATE_KEY:-}
RAZORPAY_KEY_ID=${RAZORPAY_KEY_ID:-}
CHECKOUT_ENABLE_DODO=${CHECKOUT_ENABLE_DODO:-true}
CHECKOUT_ENABLE_STRIPE=${CHECKOUT_ENABLE_STRIPE:-true}
CHECKOUT_ENABLE_ARC_PAY=${CHECKOUT_ENABLE_ARC_PAY:-false}
DODO_PAYMENTS_API_KEY=${DODO_PAYMENTS_API_KEY:-}
STRIPE_PUBLISHABLE_KEY=${STRIPE_PUBLISHABLE_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
GEMINI_MODEL=${GEMINI_MODEL:-gemini-2.5-flash}
EOF
echo ".env generated with $(wc -l < .env) lines"

# â”€â”€â”€ Install Flutter if not present â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if ! command -v flutter &> /dev/null; then
  echo "Flutter not found. Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
  export PATH="$HOME/flutter/bin:$PATH"
fi

# Verify Flutter installation
flutter --version

# â”€â”€â”€ Clean stale generated files â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
rm -rf .dart_tool build

# â”€â”€â”€ Get dependencies â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
flutter pub get

# â”€â”€â”€ Build for web â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
flutter build web --release --no-wasm-dry-run

echo "Build completed successfully!"
