// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {HalbornToken} from "./HalbornToken.sol";
import {HalbornNFT} from "./HalbornNFT.sol";

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {MulticallUpgradeable} from "./libraries/Multicall.sol";

contract HalbornLoans is Initializable, UUPSUpgradeable, MulticallUpgradeable {
    HalbornToken public token;
    HalbornNFT public nft;

    //@audit no immutable in UUPS
    //https://forum.openzeppelin.com/t/uups-why-is-immutable-considered-unsafe/31300
    //https://docs.openzeppelin.com/upgrades-plugins/1.x/faq#why-cant-i-use-immutable-variables
    uint256 public immutable collateralPrice;

    mapping(address => uint256) public totalCollateral;
    mapping(address => uint256) public usedCollateral;
    mapping(uint256 => address) public idsCollateral;

    //@audit no constructor
    //https://ethereum.stackexchange.com/questions/132261/initializing-the-implementation-contract-when-using-uups-to-protect-against-atta
    constructor(uint256 collateralPrice_) {
        collateralPrice = collateralPrice_;
    }

    function initialize(address token_, address nft_) public initializer {
        __UUPSUpgradeable_init();
        __Multicall_init();

        token = HalbornToken(token_);
        nft = HalbornNFT(nft_);
    }

    function depositNFTCollateral(uint256 id) external {
        require(
            nft.ownerOf(id) == msg.sender,
            "Caller is not the owner of the NFT"
        );

        //@audit ??? do we need to veify success
        //@audit check aproval
        nft.safeTransferFrom(msg.sender, address(this), id);

        totalCollateral[msg.sender] += collateralPrice;
        idsCollateral[id] = msg.sender;
    }

    function withdrawCollateral(uint256 id) external {
        require(
            totalCollateral[msg.sender] - usedCollateral[msg.sender] >=
                collateralPrice,
            "Collateral unavailable"
        );
        require(idsCollateral[id] == msg.sender, "ID not deposited by caller");

        nft.safeTransferFrom(address(this), msg.sender, id);
        //@audit CEI => RE onERC721Received
        totalCollateral[msg.sender] -= collateralPrice;
        delete idsCollateral[id];
    }

    function getLoan(uint256 amount) external {
        //@audit must be >=
        require(
            totalCollateral[msg.sender] - usedCollateral[msg.sender] < amount,
            "Not enough collateral"
        );
        usedCollateral[msg.sender] += amount;
        token.mintToken(msg.sender, amount);
    }

    function returnLoan(uint256 amount) external {
        require(usedCollateral[msg.sender] >= amount, "Not enough collateral");
        require(token.balanceOf(msg.sender) >= amount);
        //@audit must be -=
        usedCollateral[msg.sender] += amount;
        token.burnToken(msg.sender, amount);
    }

    //@audit access control
    function _authorizeUpgrade(address) internal override {}
}
