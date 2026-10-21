// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFTTest is Test {
    MyNFT internal nft;
    address internal owner;
    address internal victor;
    address internal iyke;

    function setUp() public {
        owner = makeAddr("owner");
        victor = makeAddr("victor");
        iyke = makeAddr("iyke");
        nft = new MyNFT(owner);
    }

    // RED: safeMint does not exist yet, or ownership is not assigned
    function test_MintAssignsOwnership() public {
        vm.prank(owner);
        uint256 tokenId = nft.safeMint(victor, "ipfs://example/1.json");

        assertEq(nft.ownerOf(tokenId), victor);
        assertEq(nft.balanceOf(victor), 1);
    }

    // 1. onlyOwner guard on safeMint
    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(victor);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, victor));
        nft.safeMint(victor, "ipfs://example/1.json");
    }

    // 2. transfer updates ownerOf and both balances
    function test_TransferUpdatesBalances() public {
        vm.prank(owner);
        uint256 tokenId = nft.safeMint(victor, "ipfs://example/1.json");

        vm.prank(victor);
        nft.transferFrom(victor, iyke, tokenId);

        assertEq(nft.ownerOf(tokenId), iyke);
        assertEq(nft.balanceOf(victor), 0);
        assertEq(nft.balanceOf(iyke), 1);
    }

    // 3. tokenURI returns what was set at mint
    function test_TokenURIReturnsCorrectMetadata() public {
        string memory uri = "ipfs://example/1.json";
        vm.prank(owner);
        uint256 tokenId = nft.safeMint(victor, uri);
        assertEq(nft.tokenURI(tokenId), uri);
    }

    function test_BurnClearsOwnership() public {
        vm.prank(owner);
        uint256 tokenId = nft.safeMint(victor, "ipfs://example/1.json");

        vm.prank(victor);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(victor), 0);
        vm.expectRevert();
        nft.ownerOf(tokenId);
    }

    function testFuzz_TransferConservesBalances(address from, address to) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);

        vm.prank(owner);
        uint256 tokenId = nft.safeMint(from, "ipfs://example/1.json");

        uint256 sumBefore = nft.balanceOf(from) + nft.balanceOf(to);

        vm.prank(from);
        nft.transferFrom(from, to, tokenId);

        assertEq(nft.ownerOf(tokenId), to);
        assertEq(nft.balanceOf(from), 0);
        assertEq(nft.balanceOf(to), 1);
        assertEq(nft.balanceOf(from) + nft.balanceOf(to), sumBefore);
    }
}
