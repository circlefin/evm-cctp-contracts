/*
 * Copyright (c) 2022, Circle Internet Financial Limited.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;

import "./Ownable2Step.sol";

/**
 * @notice Base contract which allows children to implement an emergency stop
 * mechanism
 * @dev Forked from https://github.com/centrehq/centre-tokens/blob/0d3cab14ebd133a83fc834dbd48d0468bdf0b391/contracts/v1/Pausable.sol
 * Modifications:
 * 1. Update Solidity version from 0.6.12 to 0.7.6 (8/23/2022)
 * 2. Change pauser visibility to private, declare external getter (11/19/22)
 */
contract Pausable is Ownable2Step {
    event Pause();
    event Unpause();
    event PauserChanged(address indexed newAddress);

    address private _pauser;
    bool public paused = false;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    /**
     * @dev throws if called by any account other than the pauser
     */
    modifier onlyPauser() {
        require(msg.sender == _pauser, "Pausable: caller is not the pauser");
        _;
    }

    /**
     * @notice Returns current pauser
     * @return Pauser's address
     */
    function pauser() external view returns (address) {
        return _pauser;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external onlyPauser {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyPauser {
        paused = false;
        emit Unpause();
    }

    /**
     * @dev update the pauser role
     */
    function updatePauser(address _newPauser) external onlyOwner {
        require(
            _newPauser != address(0),
            "Pausable: new pauser is the zero address"
        );
        _pauser = _newPauser;
        emit PauserChanged(_pauser);
    }
}
