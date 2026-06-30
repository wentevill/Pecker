# Tolerant Recognition Scalar Design

**Date:** 2026-06-29  
**Status:** Approved

## Problem

The recognition service returned a valid train payload whose `price` field was
the JSON number `96.0`. `ExternalEventTemplatePayload` currently decodes
`fields` as `[String: String]`, so one non-string scalar rejects the complete
otherwise-valid ticket as a response-format error.

## Design

Recognition fields remain `[String: String]` throughout Pecker. At the payload
decoding boundary, JSON strings, numbers, and booleans are accepted and
normalized into strings:

- strings remain unchanged;
- integral numbers become compact decimal strings such as `96`;
- fractional numbers become strings such as `96.5`;
- booleans become `true` or `false`;
- `null` fields are omitted.

Arrays and objects remain invalid because flattening structured values would
hide a malformed model response. Encoding remains string-only, so extraction
and verification prompts continue receiving the preferred canonical shape.

## Verification

Tests use the reported train payload with `price: 96.0`, verify the provider
finishes all three recognition stages, and assert the final field is the
string `"96"`. Separate model tests cover strings, integers, fractional
numbers, booleans, null omission, and rejection of arrays or objects.
