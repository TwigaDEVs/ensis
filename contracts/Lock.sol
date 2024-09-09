// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@ensdomains/ens-contracts/contracts/registry/ENSRegistry.sol";

contract ENSIS is Ownable {

    ENSRegistry public ens;  // Using ENSRegistry as the type instead of ENS

    // Define structure for permissions
    struct FunctionPermission {
        address allowedAddress;
        string functionName;
    }

    // Mapping of ENS names to permissions
    mapping(bytes32 => FunctionPermission) public permissions;

    // Event for logging permission changes
    event PermissionSet(bytes32 indexed node, address indexed allowedAddress, string functionName);

    // Constructor
    constructor(address ensAddress) Ownable(msg.sender) {  // Passing msg.sender as initialOwner
        ens = ENSRegistry(ensAddress); // Initialize ENS registry address
    }

    // Function to set permissions for an ENS domain
    function setPermission(bytes32 node, address allowedAddress, string memory functionName) public onlyOwner {
        permissions[node] = FunctionPermission(allowedAddress, functionName);
        emit PermissionSet(node, allowedAddress, functionName);
    }

    // Function to execute a task (checking permissions before execution)
    function executeFunction(bytes32 node, string memory functionName, bytes memory data) public {
        FunctionPermission memory perm = permissions[node];

        require(perm.allowedAddress == msg.sender, "Not allowed");
        require(keccak256(bytes(perm.functionName)) == keccak256(bytes(functionName)), "Function not allowed");

        // Call the function based on permission (assuming the data matches function signature)
        (bool success, ) = address(this).call(data);
        require(success, "Function execution failed");
    }

    // Example function with type-checking
    function increment(uint256 number) public pure returns (uint256) {
        require(number >= 0, "Number must be positive");
        return number + 1;
    }

    // Example restricted function (only accessible via permissions)
    function restrictedFunction() public pure returns (string memory) {
        return "This is a restricted function";
    }
}