# Apple Intelligence Plugin - Example App

This is a minimal Capacitor app that demonstrates how to use the `capacitor-apple-intelligence` plugin.

## Prerequisites

- **iOS 26+** (required for Apple Intelligence APIs)
- **Xcode** (latest version recommended)
- **Node.js** and **npm**
- An iOS device or simulator running iOS 26+

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Add iOS platform:**
   ```bash
   npm run add:ios
   ```

3. **Sync Capacitor:**
   ```bash
   npm run sync
   ```

4. **Open in Xcode:**
   ```bash
   npm run open:ios
   ```

5. **Build and Run:**
   - Select your target device/simulator in Xcode
   - Click the Run button (or press Cmd+R)
   - The app should launch on your device

## Features

The example app provides a simple interface to test all three plugin methods:

### 1. Generate JSON
- **Method:** `generateJSON()`
- **Input:** Prompt + JSON Schema
- **Output:** Structured JSON data matching the schema
- **Example:** Generate a user profile with name, age, and occupation

### 2. Generate Text
- **Method:** `generateText()`
- **Input:** Prompt only
- **Output:** Plain text response
- **Example:** Generate a creative story or description

### 3. Generate Text with Language
- **Method:** `generateTextWithLanguage()`
- **Input:** Prompt + Target Language
- **Output:** Plain text in the specified language
- **Example:** Generate text in Spanish, French, German, etc.

## Usage

1. Enter a prompt in the text field
2. For JSON generation, modify the schema if needed
3. For language-specific generation, select your target language
4. Click the appropriate button to test the method
5. View the results in the output section below

## Troubleshooting

### Plugin not found
- Make sure you ran `npm install` in the example directory
- Verify the parent plugin is built: `cd .. && npm run build`
- Re-sync Capacitor: `npm run sync`

### iOS 26+ requirement
- The Apple Intelligence APIs require iOS 26 or later
- Check your simulator/device iOS version
- Update to the latest iOS beta if needed

### Build errors in Xcode
- Clean build folder: Product → Clean Build Folder
- Delete derived data
- Ensure you have the latest Xcode version

## Project Structure

```
example/
├── www/
│   ├── index.html          # Main UI
│   └── js/
│       └── app.js          # Plugin integration logic
├── capacitor.config.ts     # Capacitor configuration
├── package.json            # Dependencies
└── README.md              # This file
```

## Learn More

- [Plugin Documentation](../README.md)
- [Capacitor Documentation](https://capacitorjs.com/docs)
- [Apple Intelligence APIs](https://developer.apple.com/documentation/foundation/foundationmodels)
