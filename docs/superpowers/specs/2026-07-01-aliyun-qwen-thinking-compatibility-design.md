# Aliyun Qwen Thinking Compatibility Design

## Goal

Make every Pecker recognition stage work with Qwen models served by Alibaba
Cloud Model Studio. Pecker does not need model reasoning because every stage
forces a structured function call.

## Root Cause

The simulator reproduced an `invalid_parameter_error` during verification:
Alibaba Cloud rejects `tool_choice: "required"` or an object-valued
`tool_choice` while thinking mode is enabled. Classification and extraction
can succeed before verification reaches the incompatible required choice.

## Design

`OpenAIRecognitionProvider` will add `enable_thinking: false` to every request
whose configured host is an Alibaba Cloud Model Studio OpenAI-compatible
endpoint. This applies uniformly to classification, extraction, and
verification, and therefore to every Qwen model used through that endpoint.

The provider will not send this vendor-specific parameter to other
OpenAI-compatible services. This preserves compatibility with services that
reject unknown request fields.

Alibaba endpoint detection will be based on the parsed URL host:

- `maas.aliyuncs.com` and its subdomains;
- `dashscope.aliyuncs.com` and its subdomains.

## Tests

Provider request tests will verify:

1. Alibaba Cloud Model Studio hosts include `enable_thinking: false`.
2. Standard OpenAI and unrelated compatible hosts omit `enable_thinking`.
3. Existing endpoint construction, image input, and function-calling request
   tests continue to pass.

The final verification will run the focused provider tests, the complete
Swift package test suite, and a signed simulator request against
`qwen3.7-plus`.

## Security and Cleanup

The temporary simulator-only environment injection used to capture the
service error will be removed. No API key will be added to source files,
test fixtures, logs retained in the repository, or commits.
