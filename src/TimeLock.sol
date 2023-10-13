// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    //minDelay: tempo da attendeere prima che venga eseguito
    //proposer: è la lista degli indirizzi che possono proporre
    //executors: è la lista degli indirizzi che possono eseguire
    //admin: è l'indirizzo che può cambiare i parametri
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
