/* SPDX-License-Identifier: UNLICENSED
 *
 * Copyright (c) 2022, Circle Internet Financial Trading Company Limited.
 * All rights reserved.
 *
 * Circle Internet Financial Trading Company Limited CONFIDENTIAL
 *
 * This file includes unpublished proprietary source code of Circle Internet
 * Financial Trading Company Limited, Inc. The copyright notice above does not
 * evidence any actual or intended publication of such source code. Disclosure
 * of this source code or any related proprietary information is strictly
 * prohibited without the express written permission of Circle Internet Financial
 * Trading Company Limited.
 */
pragma solidity ^0.7.6;

contract Attestable {
    // Attester Manager of the contract
    address private _attesterManager;

    /**
     * @dev Emitted when attester manager address is updated
     * @param previousAttesterManager representing the address of the previous attester manager
     * @param newAttesterManager representing the address of the new attester manager
     */
    event AttesterManagerUpdated(
        address previousAttesterManager,
        address newAttesterManager
    );

    /**
     * @dev The constructor sets the original attester manager of the contract to the sender account.
     */
    constructor() public {
        setAttesterManager(msg.sender);
    }

    /**
     * @dev Sets a new attester manager address
     */
    function setAttesterManager(address newAttesterManager) internal {
        _attesterManager = newAttesterManager;
    }

    /**
     * @dev Returns the address of the attester manager
     * @return address of the attester manager
     */
    function attesterManager() external view returns (address) {
        return _attesterManager;
    }

    /**
     * @dev Throws if called by any account other than the attester manager.
     */
    modifier onlyAttesterManager() {
        require(
            msg.sender == _attesterManager,
            "Attestable: caller is not the attester manager"
        );
        _;
    }

    /**
     * @dev Allows the current attester manager to transfer control of the contract to a newAttesterManager.
     * @param _newAttesterManager The address to update attester manager to.
     */
    function updateAttesterManager(address _newAttesterManager)
        external
        onlyAttesterManager
    {
        require(
            _newAttesterManager != address(0),
            "Attestable: new attester manager is the zero address"
        );
        setAttesterManager(_newAttesterManager);
        emit AttesterManagerUpdated(_newAttesterManager, _newAttesterManager);
    }
}
