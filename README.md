# MyNFT (MNFT)

A minimal ERC-721 collection built with [Foundry](https://book.getfoundry.sh/)
and [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) 5.x.

- **Name:** MyNFT
- **Symbol:** MNFT
- **Standard:** ERC-721 (non-fungible, one owner per token ID)
- **Metadata:** per-token URI via `ERC721URIStorage`
- **Minting:** owner-only (`Ownable`)
- **Burning:** holders can burn their own tokens (`ERC721Burnable`)

## Extensions

`MyNFT` composes three OpenZeppelin building blocks:

| Extension | Purpose |
| :--- | :--- |
| `ERC721URIStorage` | Base `ERC721` + per-token `tokenURI` metadata |
| `ERC721Burnable` | Public `burn(tokenId)` entry point; authorization inherited from `ERC721` |
| `Ownable` | Restricts `safeMint` to the deployer |

## Design

`MyNFT` inherits two parents that both override `tokenURI` and
`supportsInterface` (`ERC721` via `ERC721URIStorage`, and `ERC721` again
via `ERC721Burnable`). Solidity requires the resolution order to be
declared explicitly:

```solidity
function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
{
    return super.tokenURI(tokenId);
}

function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (bool)
{
    return super.supportsInterface(interfaceId);
}
```

`ERC721Burnable` is **not** in either override list because it does not
override these functions — it only *inherits* them from `ERC721` and adds
a public `burn` wrapper that calls `_burn`. Adding it to the list would
trigger a "no virtual/override" error.

`_burn` also needs no override in `MyNFT`: only `ERC721URIStorage`
overrides it (to delete the stored URI), so the compiler can resolve the
call unambiguously.

### Why no `totalSupply()`

The base ERC-721 standard does **not** define `totalSupply()`. Supply
tracking is provided by `ERC721Enumerable`, an optional extension that
adds per-owner and global enumeration at significant gas cost. This
collection does not inherit it, so `totalSupply()` is intentionally
absent. The fuzz test below therefore expresses the "no silent mint/burn"
invariant via balance-pair conservation rather than global supply.

## Test coverage

`test/MyNFT.t.sol` — 6 tests, all passing under `forge test`:

| Test | What it verifies |
| :--- | :--- |
| `test_MintAssignsOwnership` | `safeMint` assigns `ownerOf(tokenId)` and increments the recipient's balance |
| `test_RevertWhen_NonOwnerMints` | Non-owners revert with `OwnableUnauthorizedAccount` on `safeMint` |
| `test_TransferUpdatesBalances` | `transferFrom` updates `ownerOf` and both balances |
| `test_TokenURIReturnsCorrectMetadata` | `tokenURI` returns the URI set at mint |
| `test_BurnClearsOwnership` | `burn` zeroes the balance; subsequent `ownerOf` reverts |
| `testFuzz_TransferConservesBalances(address,address)` | Transfer conserves `balanceOf(from) + balanceOf(to)` across random addresses |

The fuzz test runs 256 iterations by default; the invariant catches any
future change that would silently mint or burn during a transfer.

## Usage

```bash
forge build         # compile
forge test -vv      # run tests (with traces)
forge fmt --check   # verify formatting (same check CI runs)
```

### Deploy locally

```bash
# Terminal 1 — local chain
anvil

# Terminal 2 — deploy (replace the initial owner with your address)
forge create src/MyNFT.sol:MyNFT \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --constructor-args <INITIAL_OWNER>
```

## Engineering process

This repo follows the same first-principles approach as the companion
`my-erc-20-token` repo: build the minimal contract, then earn each
behavior with a test.

- Baseline: `MyNFT` with `safeMint`, `ERC721URIStorage`, `Ownable`
- Add three validation tests: non-owner mint reverts, transfer updates
  balances, `tokenURI` returns the stored URI
- Genuine Red → Green cycle: add `test_BurnClearsOwnership`, watch the
  compiler reject `burn`, then inherit `ERC721Burnable`
- Resolve the diamond-inheritance conflict introduced by `ERC721Burnable`
  (two overrides: `tokenURI`, `supportsInterface`)
- Add a fuzz invariant — and in doing so discover that `totalSupply()` is
  not part of base ERC-721

The commit history records the reasoning, not just the code.

## What this does not include

- `ERC721Enumerable` (`totalSupply`, `tokenOfOwnerByIndex`, etc.)
- Royalties (EIP-2981)
- Signature-based minting (EIP-4494 / permit)
- On-chain SVG art or generative rendering

Each is a standard extension in OpenZeppelin and follows the same
composition pattern if needed later.

## CI

Every push runs `forge fmt --check`, `forge build`, and `forge test` via
`.github/workflows/test.yml`.

## License

MIT
