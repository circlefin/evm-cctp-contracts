/*
 * Copyright 2024 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;

import {UpgradeableProxy, Address} from "@openzeppelin/contracts/proxy/UpgradeableProxy.sol";

/**
 * @title AdminUpgradeableProxy
 * @notice This contract combines an upgradeable proxy with an authorization
 * mechanism for administrative tasks.
 *
 * @dev Forked from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/8e0296096449d9b1cd7c5631e917330635244c37/contracts/proxy/TransparentUpgradeableProxy.sol#L1
 * Modifications (10/1/2024):
 * - Remove ifAdmin modifier from admin() and implementation() and updated natspec.
 * - Update admin() and implementation() functions to be view functions.
 * - Pin Solidity to 0.7.6.
 * - Remove constructor visibility specifier.
 * - Remove overriden _beforeFallback() implementation.
 * - Bump constants, modifiers, and event declarations above constructor for consistency.
 * - Use "AdminUpgradableProxy" in revert string
 */
contract AdminUpgradableProxy is UpgradeableProxy {
    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data`.
     */
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable UpgradeableProxy(_logic, _data) {
        assert(
            _ADMIN_SLOT ==
                bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        );
        _setAdmin(admin_);
    }

    /**
     * @dev Returns the current admin.
     */
    function admin() external view returns (address admin_) {
        admin_ = _admin();
    }

    /**
     * @dev Returns the current implementation.
     */
    function implementation() external view returns (address implementation_) {
        implementation_ = _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     * @dev Only the admin can call this function; other callers are delegated
     */
    function changeAdmin(address newAdmin) external virtual ifAdmin {
        require(
            newAdmin != address(0),
            "AdminUpgradableProxy: new admin is the zero address"
        );
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the implementation of the proxy.
     * @dev Only the admin can call this function; other callers are delegated
     */
    function upgradeTo(address newImplementation) external virtual ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified
     * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the
     * proxied contract.
     * @dev Only the admin can call this function; other callers are delegated
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external payable virtual ifAdmin {
        _upgradeTo(newImplementation);
        Address.functionDelegateCall(newImplementation, data);
    }

    /**
     * @dev Returns the current admin.
     */
    function _admin() internal view virtual returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}
