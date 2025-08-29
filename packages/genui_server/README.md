# `genui_server`

The `genui_server` package is the server-side component of the GenUI framework. It leverages the [Genkit framework](https://genkit.dev/) to interact with a Large Language Model (LLM), dynamically generating UI definitions based on a conversation history and a client-provided widget catalog. It is designed to be a stateless, scalable, and secure backend for any GenUI-compatible client.

## Getting Started

### Prerequisites

- Node.js
- pnpm

### Installation

1. Navigate to the `packages/genui_server` directory.
2. Install the dependencies:

   ```command-line
   pnpm install
   ```

### Running the Server

1. You will need to configure your environment with the necessary API keys for the desired AI provider (e.g., Google AI).
2. To run the server in development mode with hot-reloading, use the following command:

   ```command-line
   pnpm run genkit:dev
   ```

3. This will start the Genkit development UI, where you can inspect flows and interact with the server.

## Usage

The server exposes two primary HTTP endpoints, each corresponding to a Genkit flow.

### 1. `POST /startSession`

This endpoint initializes a new session for a client. It registers the client's UI capabilities (its widget catalog) with the server and establishes a unique session.

- **Request Body**:

  ```json
  {
    "protocolVersion": "string",
    "catalog": "any"
  }
  ```

- **Response Body**: A JSON object containing the unique session identifier.

  ```json
  {
    "result": "unique-session-identifier"
  }
  ```

### 2. `POST /generateUi` (Streaming)

This endpoint generates UI updates in real-time for a given conversation. It takes the current conversation state and generates the next UI to be displayed, streaming tool calls as they are produced by the LLM.

- **Request Body**:

  ```json
  {
    "sessionId": "string",
    "conversation": "Array<any>"
  }
  ```

- **Response Body**: A stream of JSON objects. The server yields a chunk for each UI tool call (`addOrUpdateSurface`, `deleteSurface`) requested by the LLM. The client is responsible for interpreting these tool requests and updating its UI accordingly.

- **Example Streamed Chunk**:

  ```json
  {
    "type": "toolRequest",
    "toolRequests": [
      {
        "name": "addOrUpdateSurface",
        "input": {
          "surfaceId": "some-surface",
          "definition": { ... }
        }
      }
    ]
  }
  ```
