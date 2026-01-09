# Domain Upgrade Notes

This document describes how to safely update domain-related parameters
when deploying or upgrading CCTP contracts.

## When a domain update is required

- Adding support for a new chain
- Migrating to a new message transmitter
- Rotating domain identifiers after a protocol change

## Pre-upgrade checklist

- Verify the target chain ID and domain ID mapping
- Confirm the new domain is not already registered
- Ensure the caller has the correct admin role

## Upgrade steps

1. Deploy or identify the new contract instance.
2. Register the new domain with the appropriate on-chain registry.
3. Verify the domain mapping via a read-only call.
4. Run a small test message flow on the target chain.

## Post-upgrade validation

- Confirm messages are accepted from the new domain.
- Ensure old domains behave as expected (enabled or deprecated).
- Record transaction hashes and updated domain IDs.

Always test domain changes on a testnet before applying them to mainnet.
