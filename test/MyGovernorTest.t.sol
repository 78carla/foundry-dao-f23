// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    GovToken public govToken;
    TimeLock public timeLock;
    Box public box;
    MyGovernor public governor;

    address public USER = makeAddr("user");
    uint256[] values;
    bytes[] functionCalls;
    address[] targets;

    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes, you have 1 hour before you can enact

    //uint256 public constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts
    uint256 public constant VOTING_DELAY = 1; // How many blocks till a proposal vote becomes active

    address[] proposers;
    address[] executors;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        //Abbiamo mintato i token ma ora devo avere il voting power con delegate
        govToken.delegate(USER);

        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timeLock);

        //Abilitiamo un pò di permessi e li rimuoviamo da user
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        //Tutti possono eseguire quindi address 0
        timeLock.grantRole(executorRole, address(0));
        //Rimuovo permessi all'user
        timeLock.revokeRole(adminRole, USER);

        vm.stopPrank();

        box = new Box();
        //trasferiamo owvership al timelock (the timelock owns the DAO e the DAO owns the timelock)
        box.transferOwnership(address(timeLock));
    }

    function testCantUopdateBoxWithoutGovernance() public {
        //Non posso fare l'update del box senza governance
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdateBox() public {
        uint256 valueToStore = 888;
        string memory description = "Store 888 in box";
        //Calldata che mi servono: chiamata alla funcione store con il valore da inserire
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0); //E' vuoto, non mando ETH
        functionCalls.push(encodedFunctionCall);
        targets.push(address(box));
        //Target

        //1. Faccio il proposal alla DAO
        uint256 proposalId = governor.propose(targets, values, functionCalls, description);
        //View the state of the proposal - è in stata pensing
        console.log("Proposal state: %s", uint256(governor.state(proposalId)));

        //Faccio passare il tempo nella nostra fake blockchain
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        //View the state of the proposal - è in stata active
        console.log("Proposal state: %s", uint256(governor.state(proposalId)));

        //2. Faccio il vote con reason
        string memory reason = "bcz blu frog is cool";
        uint8 voteWay = 1; //1 è a favore, 0 astenuto, 2 contrario

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        //Speed del voting period - hanno votato tutti
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        //4. Queue period
        //DEvo fare hash della descrizione
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, functionCalls, descriptionHash);

        //Deve passare il min delay prima di eseguire
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        //3. Esegue il voto
        governor.execute(targets, values, functionCalls, descriptionHash);

        //Controllo che il valore sia stato aggiornato
        assert(box.getNumber() == valueToStore);
        console.log("Box value: %s", box.getNumber());
    }
}
