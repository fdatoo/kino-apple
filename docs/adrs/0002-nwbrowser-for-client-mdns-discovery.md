# ADR-0002 — NWBrowser for client-side mDNS discovery

## Status
Accepted

## Date
2026-05-16

## Context

Kino Apple clients need to find local Kino servers without requiring users to type an address. The server advertises `_kino._tcp` over Bonjour with TXT values for `version`, `api`, and `instance_id`, and the client needs those TXT values before it resolves a concrete host and port.

## Decision

Use `NWBrowser` from Network.framework for client-side mDNS discovery. `NWBrowser` is the modern API for Bonjour browsing, works naturally with `NWEndpoint` values that can later be resolved by `NWConnection`, and exposes Bonjour TXT records through `NWBrowser.Result.metadata`.

## Consequences

This avoids `NetServiceBrowser`, which is deprecated and not shaped for Swift concurrency. Discovery remains Apple-platform-native and testable with an in-process `NWListener`, while CI can skip the Bonjour end-to-end test on hosts that do not permit local service discovery.
