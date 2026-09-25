# Identity MD seat compute contracts

This contribution implements the contract stage of the **imd-compute** Sepolia project
(chain ID **11155111**). It provides a fixed-supply ERC-20 and a small immutable companion
for the later dashboard to identify its live deployment. Compute usage stays off-chain.

| Artifact | Constructor | Behavior |
| --- | --- | --- |
| `src/SeatCompute.sol:SeatCompute` | `()` nonpayable | Name **Seat Compute**, symbol **COMPUTE**, 18 decimals; mints exactly **1,000,000,000 tokens = 10^27 minor units = 1000000000000000000000000000** to `msg.sender` only. |
| `src/ComputeProject.sol:ComputeProject` | `(address token_)` nonpayable | Immutable `token()`, `version() = 1`, `siteLabel() = "imd-compute"`. Requires deployed code at `token_`. |

The token inherits the vendored OpenZeppelin ERC-20 v5.0.2 implementation. There are no
mint, burn, tax, pause, blacklist, ownership, or upgrade entry points. Transfers move the
exact amount. Approvals replace the previous allowance; an unlimited allowance remains
unlimited when spent. As with standard ERC-20, clients should revoke an existing allowance
before changing it to mitigate the allowance replacement race. Token balances grant no
claim to API usage, billing, seat ownership, or compute service.

The companion is a version stub, not a usage ledger or mutable site registry. Its label
does not identify an IPFS CID, attest to hosted content, or grant control of the hosting
label. Both contracts have no admin, external callbacks, payable entry points, receive,
or fallback functions. Direct ETH sends revert. Forced ETH or mistakenly transferred
ERC-20 tokens cannot be recovered; these contracts are not deposit destinations.

## Build and test offline

Prerequisites: Foundry with Solidity **0.8.26** already installed and Python 3 for ABI and
vendor checks. Verification used Forge **1.7.1**. All imported Solidity sources and their
licenses are ordinary files in `lib/`; no package installation, submodule, RPC, wallet,
FFI, or filesystem cheatcode permission is needed. Compiler selection is a pinned version,
not an executable path. `foundry.toml` enables offline mode, Cancun EVM, optimizer 200,
`bytecode_hash = "none"`, and no CBOR metadata.

```sh
forge build
forge test
forge fmt --check
bash check.sh
```

`forge test` includes 1,000 cases per fuzz test and two stateful invariants, each with 128
runs of 64 actions. It covers mint recipient/supply, metadata and events, exact transfers,
zero and full amounts, self transfers, approvals/revocations, finite/infinite allowance,
failure atomicity, unauthorized/duplicate actions, absent admin selectors, no recipient
callbacks, supply conservation, and factory-style CREATE2 deployment. Companion tests
cover configuration, invalid dependencies, dependency order, nonpayable constructors,
ETH rejection, and forbidden runtime opcodes/size. No test forks a public chain.

ABI exports are [SeatCompute.json](docs/abi/SeatCompute.json) and
[ComputeProject.json](docs/abi/ComputeProject.json). After rebuilding, regenerate with
`python3 scripts/artifacts.py`; use `python3 scripts/artifacts.py --check` to check exports
and the vendored dependency hashes. [ABI details](docs/abi/README.md) describe integration.

## Deployment handoff and responsibilities

This is the implementation contribution. The separate manifest contributor writes
`launch.json`; the independent review examines both accepted source and that manifest.
This repository does not claim a deployment, independent approval, live address, or hosted
site. Services publish the source, bind signed artifacts/policy, attest, admit, deploy, and
then start the required frontend/hosting stage. Those later results are not needed to
build or test this contribution.

The manifest author and launch service must use:

- Kind `evm_project`, chain ID `11155111`, launch token artifact
  `src/SeatCompute.sol:SeatCompute`, name/symbol/decimals as above, no token constructor
  arguments, and zero ETH constructor value.
- Exactly one application, identifier `ComputeProject` (14 ASCII characters), artifact
  `src/ComputeProject.sol:ComputeProject`, with `constructorArgs: ["$token"]`. Deploy the
  token first, then this companion. No initialization call, owner argument, dynamic
  constructor argument, proxy, hook, or privileged wallet is needed.
- Do not put `totalSupply` or allocation basis points in the manifest. The factory receives
  the entire **10^27** before any policy distribution. The companion never touches that
  balance or requests approval. Protocol LP/reward distribution belongs to the factory
  and services; neither is implemented by this project.
- For the supplied native-ETH Sepolia pool guidance: quote asset zero address, fee `3000`,
  tick spacing `60`, no hook, legacy `initialPrice` `79228162514264337593543950336`.
  Services apply the pinned policy's effective opening price (including the supplied
  v5 20 ETH opening FDV guidance) and reward allocation; those are not token parameters.
  Policy and signed artifact linkage are service responsibilities.

Review must verify that `$token` resolves to the accepted SeatCompute deployment:
`ComputeProject` checks only that code exists, not its identity or ERC-20 interface.
It makes no external calls during construction. The contracts are chain-neutral for local
testing; the launch service must enforce Sepolia only. Factory address, CREATE2 salts,
policy owner, effective pool configuration, live addresses, and IPFS content CID remain
service-stage deployment parameters, not guessed constants in this source.

After deployment, services should verify the token metadata and supply, the factory's full
pre-distribution balance, and the companion's token/version/label; then publish actual
addresses and explorer links. No contributor needs a funded wallet or broadcasts a
transaction. An independent adversarial review of accepted source and final manifest is
required before release. Local tests and local review are evidence, not that approval.

## Required dashboard handoff

The later frontend stage must build a static/SPA dashboard against the live Sepolia token
and companion, display their addresses and Sepolia explorer links, and publish it on IPFS
under the label **imd-compute**. Hosting remains a required later deliverable.

- Read `GET https://api.imd.fun/contributors` for `tokenId`, `wallet`, `attempts`, `accepted`,
  `rejected`, `pending`, `wallClockMs`, `inputTokens`, `outputTokens`, `cachedInputTokens`,
  and `turns`. Read `GET https://api.imd.fun/workers` for `daemonVersion`, `lastHeartbeatAt`,
  `working`, and `runtimes`; join contributors' `tokenId` to workers' `seat.tokenId` using
  a consistent string representation. Missing worker data must not hide a contributor.
- Sort the table by `outputTokens` descending by default; allow sorting, online/runtime/
  minimum-accepted filters, tokenId/wallet search, refresh, and an `asOf` timestamp.
  State that counters are **plane-reported, not audited billing**. There is no on-chain
  usage accounting or API write endpoint in this contribution.
- Connect wallets through EIP-1193. Lowercase both the connected address and each
  contributors' `wallet`; highlight **every** matching row and show **"N seats linked"**.
  Account changes recompute matches; disconnect clears them. Never hardcode token IDs or
  a seat allowlist. Wallet connection is not authentication to a backend.
- Only if a wallet is missing, an optional nonblocking read-only mainnet `ownerOf` lookup
  may use collection `0x0000ec93127baa929e58e97dd0095a2bfb38ec1d`. This does not change the
  project's Sepolia launch chain. API availability, response freshness, heartbeat online
  threshold, hosting operations, and wallet-provider errors belong to the frontend.

See [dependency provenance](docs/dependencies.json) for pinned sources and file hashes,
and [verification notes](docs/verification.md) for the local evidence and limits.
