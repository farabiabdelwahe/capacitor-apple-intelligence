# capacitor-apple-intelligence

A production-ready Capacitor v8 plugin that exposes **Apple Intelligence** with **schema-constrained JSON generation** for structured AI responses.

## Features

- **On-device AI** - Uses Apple's Foundation Models framework for local, private inference
- **Schema-constrained output** - Guarantees JSON output matching your provided schema
- **Automatic retry** - Retries generation once if validation fails
- **Runtime validation** - Validates output against JSON schema before returning
- **Privacy-first** - No network calls, all processing happens on-device
- **iOS only** - Designed specifically for Apple Intelligence on iOS 26+

## Requirements

- **iOS 26+** (Apple Intelligence requires iOS 26 or later)
- **Capacitor 8.0+**
- **Xcode 26+**
- **Apple Silicon device** (iPhone 15 Pro or later, or M-series iPads)

**Note**: Apple Intelligence must be enabled on the device for this plugin to work.

## Example App

A fully functional example app is included in the [`example/`](./example) directory. It demonstrates all plugin methods with a clean UI:

- JSON generation with schema validation
- Plain text generation
- Language-specific text generation
- Availability checking

See the [example README](./example/README.md) for setup instructions.

## Installation

```bash
npm install capacitor-apple-intelligence
npx cap sync
```

## Usage

### Basic Example

```typescript
import { AppleIntelligence } from 'capacitor-apple-intelligence';

const result = await AppleIntelligence.generate({
  messages: [
    { role: "user", content: "List 3 popular programming languages" }
  ],
  response_format: {
    type: "json_schema",
    schema: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          paradigm: { type: "string" },
          yearCreated: { type: "number" }
        },
        required: ["name", "paradigm", "yearCreated"]
      }
    }
  }
});

if (result.success) {
  console.log(result.data);
  // [
  //   { name: "Python", paradigm: "Multi-paradigm", yearCreated: 1991 },
  //   { name: "JavaScript", paradigm: "Event-driven", yearCreated: 1995 },
  //   { name: "Rust", paradigm: "Systems", yearCreated: 2010 }
  // ]
} else {
  console.error(result.error?.code, result.error?.message);
}
```

### With System Prompt

```typescript
const result = await AppleIntelligence.generate({
  messages: [
    { 
      role: "system", 
      content: "You are a helpful assistant that organizes tasks." 
    },
    { 
      role: "user", 
      content: "Create a list of tasks for planning a project" 
    }
  ],
  response_format: {
    type: "json_schema",
    schema: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          priority: { type: "string" },
          estimatedHours: { type: "number" }
        },
        required: ["title", "priority"]
      }
    }
  }
});
```

### Nested Object Schema

```typescript
const result = await AppleIntelligence.generate({
  messages: [
    { role: "user", content: "Create a sample user profile" }
  ],
  response_format: {
    type: "json_schema",
    schema: {
      type: "object",
      properties: {
        user: {
          type: "object",
          properties: {
            name: { type: "string" },
            email: { type: "string" },
            age: { type: "number" }
          },
          required: ["name", "email"]
        },
        preferences: {
          type: "object",
          properties: {
            theme: { type: "string" },
            notifications: { type: "boolean" }
          }
        }
      },
      required: ["user"]
    }
  }
});
```

### Plain Text Generation

Generate plain text responses without JSON schema constraints:

```typescript
const result = await AppleIntelligence.generateText({
  messages: [
    { role: "system", content: "You are a creative writing assistant." },
    { role: "user", content: "Write a short poem about the ocean" }
  ]
});

if (result.success) {
  console.log(result.content);
  // "Waves crash upon the shore,
  //  Endless depths forevermore..."
}
```

### Text Generation with Language

Generate text in a specific language using either language codes or full names:

```typescript
const result = await AppleIntelligence.generateTextWithLanguage({
  messages: [
    { role: "user", content: "Describe a beautiful sunset" }
  ],
  language: "es"  // or "Spanish"
});

if (result.success) {
  console.log(result.content);
  // "El atardecer pinta el cielo con tonos dorados y rosados..."
}
```

Supported language codes: `en`, `es`, `fr`, `de`, `ja`, `zh`, `it`, `pt`, `ru`, `ar`, `ko`

## API

### `checkAvailability()`

Check if Apple Intelligence is available on the current device. **Call this first** before using other methods.

#### Response

| Property | Type | Description |
|----------|------|-------------|
| `available` | `boolean` | Whether Apple Intelligence is available |
| `error` | `GenerateError` | Error details (if unavailable) |

#### Example

```typescript
const result = await AppleIntelligence.checkAvailability();

if (result.available) {
  console.log('Apple Intelligence is ready!');
} else {
  console.log('Not available:', result.error?.message);
  // "Apple Intelligence requires iOS 26 or later..."
}
```

---

### `generate(request)`

Generate structured JSON output using Apple Intelligence.

#### Request

| Property | Type | Description |
|----------|------|-------------|
| `messages` | `Message[]` | Array of conversation messages |
| `response_format` | `ResponseFormat` | Schema specification for the output |

#### Message

| Property | Type | Description |
|----------|------|-------------|
| `role` | `"system" \| "user"` | The role of the message sender |
| `content` | `string` | The text content of the message |

#### ResponseFormat

| Property | Type | Description |
|----------|------|-------------|
| `type` | `"json_schema"` | Must be `"json_schema"` |
| `schema` | `object` | JSON Schema specification |

#### Response

| Property | Type | Description |
|----------|------|-------------|
| `success` | `boolean` | Whether generation succeeded |
| `data` | `any` | The parsed JSON data (on success) |
| `error` | `GenerateError` | Error details (on failure) |

#### Error Codes

| Code | Description |
|------|-------------|
| `UNAVAILABLE` | iOS < 26 or Apple Intelligence not available |
| `INVALID_JSON` | Model output was not valid JSON |
| `SCHEMA_MISMATCH` | JSON valid but doesn't match schema |
| `NATIVE_ERROR` | Other Swift/Foundation Models errors |

### `generateText(request)`

Generate plain text output using Apple Intelligence.

#### Request

| Property | Type | Description |
|----------|------|-------------|
| `messages` | `Message[]` | Array of conversation messages |

#### Response

| Property | Type | Description |
|----------|------|-------------|
| `success` | `boolean` | Whether generation succeeded |
| `content` | `string` | The generated text (on success) |
| `error` | `GenerateError` | Error details (on failure) |

### `generateTextWithLanguage(request)`

Generate plain text output in a specific language using Apple Intelligence.

#### Request

| Property | Type | Description |
|----------|------|-------------|
| `messages` | `Message[]` | Array of conversation messages |
| `language` | `string` | Target language - supports codes ("en", "es", "de") or full names ("English", "Spanish", "German") |

#### Response

| Property | Type | Description |
|----------|------|-------------|
| `success` | `boolean` | Whether generation succeeded |
| `content` | `string` | The generated text (on success) |
| `error` | `GenerateError` | Error details (on failure) |

## How It Works

1. **Schema Injection**: The plugin injects your JSON schema into the system prompt with strict instructions
2. **Generation**: Uses Apple's Foundation Models framework to generate a response
3. **Parsing**: Parses the raw text output as JSON
4. **Validation**: Validates the JSON against your provided schema
5. **Retry**: If validation fails, retries once with a corrective prompt
6. **Return**: Returns structured success/error response

## Supported Schema Types

- `object` - With `properties` and `required` fields
- `array` - With `items` schema and optional `minItems`/`maxItems`
- `string`
- `number` / `integer`
- `boolean`
- `null`

## Error Handling

The plugin always returns a structured response, never throws:

```typescript
const result = await AppleIntelligence.generate({...});

if (!result.success) {
  switch (result.error?.code) {
    case 'UNAVAILABLE':
      // Show fallback UI or use alternative
      break;
    case 'INVALID_JSON':
    case 'SCHEMA_MISMATCH':
      // Retry with different prompt or handle gracefully
      break;
    case 'NATIVE_ERROR':
      // Log error for debugging
      console.error(result.error.message);
      break;
  }
}
```

## Web Support

This plugin is iOS-only. On web platforms, it returns:

```typescript
{
  success: false,
  error: {
    code: 'UNAVAILABLE',
    message: 'Apple Intelligence is only available on iOS 26+ devices...'
  }
}
```

## License

MIT

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.
