// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ensis is ERC721, Ownable {
    uint256 private _nextTokenId;
    uint256 public functionPrice;

    struct FunctionData {
        bytes4 selector;
        string functionName;
        string[] argTypes;
        string[] argNames;
    }

    struct ContractData {
        uint256 contractId;
        uint256 lastExecuted;
        bytes32 stateHash;
        uint256 balance;
        mapping(string => FunctionData) functions; // Map function name to FunctionData
    }

    // Mappings
    mapping(address => ContractData) private _registeredContracts;
    mapping(address => uint256[]) private _ownedContracts;
    mapping(address => bool) public allowedAddresses;

    // Events
    event ContractRegistered(uint256 indexed contractId, address indexed contractAddress, address indexed owner);
    event FunctionRegistered(address indexed contractAddress, bytes4 functionSelector, string functionName, string[] argTypes, string[] argNames);
    event FunctionExecuted(address indexed contractAddress, string functionName, bytes32 stateHash, uint256 timestamp);
    event ContractFunded(address indexed contractAddress, address indexed funder, uint256 amount);
    event FundsWithdrawn(address indexed contractAddress, address indexed recipient, uint256 amount);

    constructor(uint256 initialPrice) 
        ERC721("Ensis", "ENS") Ownable(msg.sender) {
        functionPrice = initialPrice;
        _nextTokenId = 1;
    }

    function registerContract(address contractAddress) public payable {
        require(msg.value >= functionPrice, "Insufficient payment");
        require(_registeredContracts[contractAddress].contractId == 0, "Contract already registered");

        uint256 contractId = _nextTokenId++;
        _safeMint(msg.sender, contractId);

        _registeredContracts[contractAddress].contractId = contractId;
        _registeredContracts[contractAddress].lastExecuted = block.timestamp;
        _registeredContracts[contractAddress].stateHash = bytes32(0);
        _registeredContracts[contractAddress].balance = msg.value;

        _ownedContracts[msg.sender].push(contractId);

        emit ContractRegistered(contractId, contractAddress, msg.sender);
    }

    function registerFunction(
        address contractAddress,
        bytes4 functionSelector,
        string memory functionName,
        string[] memory argTypes,
        string[] memory argNames
    ) public payable {
        require(_isAuthorized(msg.sender, _registeredContracts[contractAddress].contractId), "Not authorized");
        require(msg.value >= functionPrice, "Insufficient payment");
        require(argTypes.length == argNames.length, "Argument types and names length mismatch");
        require(_registeredContracts[contractAddress].functions[functionName].selector == bytes4(0), "Function already registered");

        _registeredContracts[contractAddress].functions[functionName] = FunctionData({
            selector: functionSelector,
            functionName: functionName,
            argTypes: argTypes,
            argNames: argNames
        });

        _registeredContracts[contractAddress].balance += msg.value;

        emit FunctionRegistered(contractAddress, functionSelector, functionName, argTypes, argNames);
    }

    function executeFunction(address contractAddress, string memory functionName, bytes memory params) public {
        require(_isAuthorized(msg.sender, _registeredContracts[contractAddress].contractId), "Not authorized");
        
        FunctionData storage funcData = _registeredContracts[contractAddress].functions[functionName];
        require(funcData.selector != bytes4(0), "Function not registered");

        (bool success, bytes memory result) = contractAddress.call(
            abi.encodePacked(funcData.selector, params)
        );
        require(success, "Function execution failed");

        _registeredContracts[contractAddress].stateHash = keccak256(result);
        _registeredContracts[contractAddress].lastExecuted = block.timestamp;

        emit FunctionExecuted(contractAddress, functionName, _registeredContracts[contractAddress].stateHash, block.timestamp);
    }

    function getFunctionData(address contractAddress, string memory functionName) public view returns (
        bytes4,
        string memory, 
        string[] memory, 
        string[] memory
    ) {
        FunctionData memory funcData = _registeredContracts[contractAddress].functions[functionName];
        return (funcData.selector, funcData.functionName, funcData.argTypes, funcData.argNames);
    }

    function fundContract(address contractAddress) public payable {
        require(_registeredContracts[contractAddress].contractId != 0, "Contract does not exist");
        _registeredContracts[contractAddress].balance += msg.value;
        emit ContractFunded(contractAddress, msg.sender, msg.value);
    }

    function setAllowedAddress(address addr, bool isAllowed) public onlyOwner {
        allowedAddresses[addr] = isAllowed;
    }

    function withdrawFunds(address contractAddress, address payable recipient, uint256 amount) public {
        require(_isAuthorized(msg.sender, _registeredContracts[contractAddress].contractId), "Not authorized");
        require(allowedAddresses[recipient], "Recipient not allowed");
        require(amount <= _registeredContracts[contractAddress].balance, "Insufficient contract balance");
        
        _registeredContracts[contractAddress].balance -= amount;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(contractAddress, recipient, amount);
    }

    function getContractDetails(address contractAddress) public view returns (uint256, uint256, bytes32, uint256) {
        ContractData storage contractData = _registeredContracts[contractAddress];
        return (
            contractData.contractId,
            contractData.lastExecuted,
            contractData.stateHash,
            contractData.balance
        );
    }

    function getContractsByOwner(address owner) public view returns (uint256[] memory) {
        return _ownedContracts[owner];
    }

    function updateFunctionPrice(uint256 newPrice) public onlyOwner {
        functionPrice = newPrice;
    }


    function callContractFunction(address contractAddress, string memory functionName, bytes memory params) public view returns (bool success, bytes memory result) {
        require(_registeredContracts[contractAddress].contractId != 0, "Contract not registered");
        FunctionData memory funcData = _registeredContracts[contractAddress].functions[functionName];
        require(funcData.selector != bytes4(0), "Function not registered");
        
        (success, result) = contractAddress.staticcall(abi.encodePacked(funcData.selector, params));
    }

    function _isAuthorized(address operator, uint256 contractId) internal view returns (bool) {
        address owner = ownerOf(contractId);
        return operator == owner || getApproved(contractId) == operator || isApprovedForAll(owner, operator);
    }

    receive() external payable {
        revert("Use fundContract function to add funds to a specific contract");
    }
}