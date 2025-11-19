#!/bin/bash
set -e

# Install Flutter if not present
if ! command -v flutter &> /dev/null; then
  echo "Flutter not found. Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
  export PATH="$HOME/flutter/bin:$PATH"
fi

# Verify Flutter installation
flutter --version

# Get dependencies
flutter pub get

# Build for web
flutter build web --release

echo "Build completed successfully!"




