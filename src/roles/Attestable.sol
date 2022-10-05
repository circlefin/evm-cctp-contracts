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

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

contract Attestable {
    /**
     * @notice Emitted when an attester is enabled
     * @param attester newly enabled attester
     */
    event AttesterEnabled(address attester);

    /**
     * @notice Emitted when an attester is disabled
     * @param attester newly disabled attester
     */
    event AttesterDisabled(address attester);

    /**
     * @notice Emitted when threshold number of attestations (m in m/n multisig) is updated
     * @param oldSignatureThreshold old signature threshold
     * @param newSignatureThreshold new signature threshold
     */
    event SignatureThresholdUpdated(
        uint256 oldSignatureThreshold,
        uint256 newSignatureThreshold
    );

    /**
     * @dev Emitted when attester manager address is updated
     * @param previousAttesterManager representing the address of the previous attester manager
     * @param newAttesterManager representing the address of the new attester manager
     */
    event AttesterManagerUpdated(
        address previousAttesterManager,
        address newAttesterManager
    );

    using EnumerableSet for EnumerableSet.AddressSet;

    // number of signatures from distinct attesters required for a message to be received (m in m/n multisig)
    uint256 public signatureThreshold;

    // 65-byte ECDSA signature: v (32) + r (32) + s (1)
    uint256 internal immutable signatureLength = 65;

    // enabled attesters (message signers)
    // (length of enabledAttesters is n in m/n multisig of message signers)
    EnumerableSet.AddressSet private enabledAttesters;

    // Attester Manager of the contract
    address private _attesterManager;

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
     * @dev The constructor sets the original attester manager of the contract to the sender account.
     * @param attester attester to initialize
     */
    constructor(address attester) public {
        _setAttesterManager(msg.sender);
        // Initially 1 signature is required. Threshold can be increased by attesterManager.
        signatureThreshold = 1;
        enableAttester(attester);
    }

    /**
     * @notice Enables an attester
     * @dev Only callable by attesterManager. New attester must be nonzero, and currently disabled.
     * @param newAttester attester to enable
     */
    function enableAttester(address newAttester) public onlyAttesterManager {
        require(newAttester != address(0), "New attester must be nonzero");
        require(enabledAttesters.add(newAttester), "Attester already enabled");
        emit AttesterEnabled(newAttester);
    }

    /**
     * @notice returns true if given `attester` is enabled, else false
     * @return true if given `attester` is enabled, else false
     */
    function isEnabledAttester(address attester) public view returns (bool) {
        return enabledAttesters.contains(attester);
    }

    /**
     * @notice returns the number of enabled attesters
     * @return number of enabled attesters
     */
    function getNumEnabledAttesters() public view returns (uint256) {
        return enabledAttesters.length();
    }

    /**
     * @dev Allows the current attester manager to transfer control of the contract to a newAttesterManager.
     * @param newAttesterManager The address to update attester manager to.
     */
    function updateAttesterManager(address newAttesterManager)
        external
        onlyAttesterManager
    {
        require(
            newAttesterManager != address(0),
            "Attestable: new attester manager is the zero address"
        );
        _setAttesterManager(newAttesterManager);
        emit AttesterManagerUpdated(newAttesterManager, newAttesterManager);
    }

    /**
     * @notice Disables an attester
     * @dev Only callable by attesterManager. Disabling the attester is not allowed if there is only one attester
     * enabled, or if it would cause the number of enabled attesters to become less than signatureThreshold.
     * (Attester must be currently enabled.)
     * @param attester attester to disable
     */
    function disableAttester(address attester) external onlyAttesterManager {
        // Disallow disabling attester if there is only 1 active attester
        require(
            getNumEnabledAttesters() > 1,
            "Unable to disable attester because 1 or less attesters are enabled"
        );

        // Disallow disabling an attester if it would cause the n in m/n multisig to fall below m (threshold # of signers).
        require(
            getNumEnabledAttesters() > signatureThreshold,
            "Unable to disable attester because signature threshold is too low"
        );

        require(enabledAttesters.remove(attester), "Attester already disabled");
        emit AttesterDisabled(attester);
    }

    /**
     * @notice Sets the threshold of signatures required to attest to a message.
     * (This is the m in m/n multisig.)
     * @dev new signature threshold must be nonzero, and must not exceed number
     * of enabled attesters.
     * @param newSignatureThreshold new signature threshold
     */
    function setSignatureThreshold(uint256 newSignatureThreshold)
        external
        onlyAttesterManager
    {
        require(
            newSignatureThreshold != 0,
            "New signature threshold must be nonzero"
        );

        require(
            newSignatureThreshold <= enabledAttesters.length(),
            "New signature threshold cannot exceed the number of enabled attesters"
        );

        require(
            newSignatureThreshold != signatureThreshold,
            "New signature threshold must not equal current signature threshold"
        );

        uint256 _oldSignatureThreshold = signatureThreshold;
        signatureThreshold = newSignatureThreshold;
        emit SignatureThresholdUpdated(
            _oldSignatureThreshold,
            signatureThreshold
        );
    }

    /**
     * @dev Returns the address of the attester manager
     * @return address of the attester manager
     */
    function attesterManager() external view returns (address) {
        return _attesterManager;
    }

    /**
     * @notice gets enabled attester at given `index`
     * @param index index of attester to check
     * @return enabled attester at given `index`
     */
    function getEnabledAttester(uint256 index) external view returns (address) {
        return enabledAttesters.at(index);
    }

    /**
     * @dev Sets a new attester manager address
     */
    function _setAttesterManager(address _newAttesterManager) internal {
        _attesterManager = _newAttesterManager;
    }

    /**
     * @notice reverts if the attestation, which is comprised of one or more concatenated 65-byte signatures, is invalid.
     *
     * @dev Rules for valid attestation:
     * 1. length of `_attestation` == 65 (signature length) * signatureThreshold
     * 2. addresses recovered from attestation must be in increasing order.
     * For example, if signature A is signed by address 0x1..., and signature B
     * is signed by address 0x2..., attestation must be passed as AB.
     * 3. no duplicate signers
     * 4. all signers must be enabled attesters
     *
     * Based on Christian Lundkvist's Simple Multisig
     * (https://github.com/christianlundkvist/simple-multisig/tree/560c463c8651e0a4da331bd8f245ccd2a48ab63d)
     */
    function _verifyAttestationSignatures(
        bytes memory _message,
        bytes calldata _attestation
    ) internal view {
        require(
            _attestation.length == signatureLength * signatureThreshold,
            "Invalid attestation length"
        );

        // (Attesters cannot be address(0))
        address _latestAttesterAddress = address(0);
        // Address recovered from signatures must be in increasing order, to prevent duplicates
        for (uint256 i = 0; i < signatureThreshold; i++) {
            bytes memory _signature = _attestation[i * signatureLength:i *
                signatureLength +
                signatureLength];
            address _recoveredAttester = _recoverAttesterSignature(
                _message,
                _signature
            );
            require(
                _recoveredAttester > _latestAttesterAddress,
                "Signature verification failed: signer is out of order or duplicate"
            );
            require(
                isEnabledAttester(_recoveredAttester),
                "Signature verification failed: signer is not enabled attester"
            );
            _latestAttesterAddress = _recoveredAttester;
        }
    }

    /**
     * @notice Checks that signature was signed by attester
     * @param _message unsigned message bytes
     * @param _signature message signature
     * @return address of recovered signer
     **/
    function _recoverAttesterSignature(
        bytes memory _message,
        bytes memory _signature
    ) internal view returns (address) {
        bytes32 _digest = keccak256(_message);
        return (ECDSA.recover(_digest, _signature));
    }
}
