// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {CrewDistributor} from "../src/CrewDistributor.sol";
import {console} from "forge-std/console.sol";

contract CrewDistributorScript is Script {
    CrewDistributor public distributor;
    address public admin = address(0xf8Cb89455F148470C1188160c22763af9CEC3e58);
    address public owner = address(0x631046BC261e0b2e3DB480B87D2B7033d9720c90);
    address public recipient =
        address(0x631046BC261e0b2e3DB480B87D2B7033d9720c90);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        distributor = new CrewDistributor(owner, admin, recipient);
        console.log("CrewDistributorScript deployed at:", address(distributor));

        vm.stopBroadcast();
    }
}
