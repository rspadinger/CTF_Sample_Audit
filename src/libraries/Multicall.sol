// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AddressUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "forge-std/console.sol";

abstract contract MulticallUpgradeable is Initializable {
    //@audit-ok needs to call the unchaned function:
    //https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#initializing_the_implementation_contract
    //https://docs.openzeppelin.com/contracts/4.x/upgradeable
    function __Multicall_init() internal onlyInitializing {}

    function __Multicall_init_unchained() internal onlyInitializing {}

    function multicall(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            //@audit no delegate call in upgradeables && ETH is not sent along
            // https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/proxy/utils/UUPSUpgradeable.sol
            results[i] = AddressUpgradeable.functionDelegateCall(
                address(this), //proxy => calls functions on proxy contract : upgradeToAndCall
                data[i]
            );
        }
        return results;
    }
}
