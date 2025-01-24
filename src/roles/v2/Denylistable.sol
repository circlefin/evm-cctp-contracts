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

import {Ownable2Step} from "../Ownable2Step.sol";

/**
 * @title Denylistable
 * @notice Contract that allows the management and application of a denylist
 */
abstract contract Denylistable is Ownable2Step {
    // ============ Events ============
    /**
     * @notice Emitted when the denylister is updated
     * @param oldDenylister Address of the previous Denylister
     * @param newDenylister Address of the new Denylister
     */
    event DenylisterChanged(
        address indexed oldDenylister,
        address indexed newDenylister
    );

    /**
     * @notice Emitted when `account` is added to the denylist
     * @param account Address added to the denylist
     */
    event Denylisted(address indexed account);

    /**
     * @notice Emitted when `account` is removed from the denylist
     * @param account Address removed from the denylist
     */
    event UnDenylisted(address indexed account);

    // ============ Constants ============
    // A true boolean representation in uint256
    uint256 private constant _TRUE = 1;

    // A false boolean representation in uint256
    uint256 private constant _FALSE = 0;

    // ============ State Variables ============
    // The currently set denylister
    address internal _denylister;

    // A mapping indicating whether an account is on the denylist. 1 indicates that an
    // address is on the denylist; 0 otherwise.
    mapping(address => uint256) internal _denylist;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[20] private __gap;

    // ============ Modifiers ============
    /**
     * @dev Throws if called by any account other than the denylister.
     */
    modifier onlyDenylister() {
        require(
            msg.sender == _denylister,
            "Denylistable: caller is not denylister"
        );
        _;
    }

    /**
     * @dev Performs denylist checks on the msg.sender and tx.origin addresses
     */
    modifier notDenylistedCallers() {
        _requireNotDenylisted(msg.sender);
        if (msg.sender != tx.origin) {
            _requireNotDenylisted(tx.origin);
        }
        _;
    }

    // ============ External Functions  ============
    /**
     * @notice Updates the currently set Denylister
     * @dev Reverts if not called by the Owner
     * @dev Reverts if the new denylister address is the zero address
     * @param newDenylister The new denylister address
     */
    function updateDenylister(address newDenylister) external onlyOwner {
        _updateDenylister(newDenylister);
    }

    /**
     * @notice Adds an address to the denylist
     * @param account Address to add to the denylist
     */
    function denylist(address account) external onlyDenylister {
        _denylist[account] = _TRUE;
        emit Denylisted(account);
    }

    /**
     * @notice Removes an address from the denylist
     * @param account Address to remove from the denylist
     */
    function unDenylist(address account) external onlyDenylister {
        _denylist[account] = _FALSE;
        emit UnDenylisted(account);
    }

    /**
     * @notice Returns the currently set Denylister
     * @return Denylister address
     */
    function denylister() external view returns (address) {
        return _denylister;
    }

    /**
     * @notice Returns whether an address is currently on the denylist
     * @param account Address to check
     * @return True if the account is on the deny list and false if the account is not.
     */
    function isDenylisted(address account) external view returns (bool) {
        return _denylist[account] == _TRUE;
    }

    // ============ Internal Utils ============
    /**
     * @notice Updates the currently set denylister
     * @param _newDenylister The new denylister address
     */
    function _updateDenylister(address _newDenylister) internal {
        require(
            _newDenylister != address(0),
            "Denylistable: new denylister is the zero address"
        );
        address _oldDenylister = _denylister;
        _denylister = _newDenylister;
        emit DenylisterChanged(_oldDenylister, _newDenylister);
    }

    /**
     * @notice Checks an address against the denylist
     * @dev Reverts if address is on the denylist
     */
    function _requireNotDenylisted(address _address) internal view {
        require(
            _denylist[_address] == _FALSE,
            "Denylistable: account is on denylist"
        );
    }
}
