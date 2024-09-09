// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ensis is ERC721, Ownable {
    uint256 private _nextTokenId;
    uint256 public functionPrice;

    struct ContractFunctions {
        mapping(string => bytes4) methodIdentifiers;
        mapping(string => bool) registeredFunctions;
        string[] functionSignatures;
    }

    struct ExecutableContractData {
        uint256 contractId;
        address contractAddress;
        uint256 lastExecuted;
        bytes32 stateHash;
        uint256 balance;
    }

    // Mappings
    mapping(address => ContractFunctions) private _contractFunctions;
    mapping(uint256 => ExecutableContractData) private _registeredContracts;
    mapping(address => uint256[]) private _ownedContracts;
    mapping(address => bool) public allowedAddresses;

    // Events
    event ContractRegistered(uint256 indexed contractId, address indexed contractAddress, address indexed owner);
    event FunctionRegistered(address indexed contractAddress, string functionSignature, bytes4 methodIdentifier);
    event FunctionExecuted(uint256 indexed contractId, string functionSignature, bytes32 stateHash, uint256 timestamp);
    event ContractFunded(uint256 indexed contractId, address indexed funder, uint256 amount);
    event FundsWithdrawn(uint256 indexed contractId, address indexed recipient, uint256 amount);

    constructor(uint256 initialPrice) 
        ERC721("Ensis", "ENS") Ownable(msg.sender) {
        functionPrice = initialPrice;
        _nextTokenId = 1;
    }

    function registerContract(address contractAddress) public payable {
        require(msg.value >= functionPrice, "Insufficient payment");

        uint256 contractId = _nextTokenId++;
        _safeMint(msg.sender, contractId);

        _registeredContracts[contractId] = ExecutableContractData({
            contractId: contractId,
            contractAddress: contractAddress,
            lastExecuted: block.timestamp,
            stateHash: bytes32(0),
            balance: msg.value
        });

        _ownedContracts[msg.sender].push(contractId);

        emit ContractRegistered(contractId, contractAddress, msg.sender);
    }

    function registerFunction(uint256 contractId, string memory functionSignature) public {
        require(_isAuthorized(msg.sender, contractId), "Not authorized");
        address contractAddress = _registeredContracts[contractId].contractAddress;

        bytes4 methodIdentifier = bytes4(keccak256(bytes(functionSignature)));

        ContractFunctions storage contractFunctions = _contractFunctions[contractAddress];
        require(!contractFunctions.registeredFunctions[functionSignature], "Function already registered");

        contractFunctions.methodIdentifiers[functionSignature] = methodIdentifier;
        contractFunctions.registeredFunctions[functionSignature] = true;
        contractFunctions.functionSignatures.push(functionSignature);

        emit FunctionRegistered(contractAddress, functionSignature, methodIdentifier);
    }

    function executeFunction(uint256 contractId, string memory functionSignature, bytes memory params) public {
        require(_isAuthorized(msg.sender, contractId), "Not authorized");
        ExecutableContractData storage executableContract = _registeredContracts[contractId];
        
        bytes4 methodId = _contractFunctions[executableContract.contractAddress].methodIdentifiers[functionSignature];
        require(methodId != bytes4(0), "Function not registered");

        (bool success, bytes memory result) = executableContract.contractAddress.call(
            abi.encodePacked(methodId, params)
        );
        require(success, "Function execution failed");

        executableContract.stateHash = keccak256(result);
        executableContract.lastExecuted = block.timestamp;

        emit FunctionExecuted(contractId, functionSignature, executableContract.stateHash, block.timestamp);
    }

    function fundContract(uint256 contractId) public payable {
        require(_registeredContracts[contractId].contractId != 0, "Contract does not exist");
        _registeredContracts[contractId].balance += msg.value;
        emit ContractFunded(contractId, msg.sender, msg.value);
    }

    function setAllowedAddress(address addr, bool isAllowed) public onlyOwner {
        allowedAddresses[addr] = isAllowed;
    }

    function withdrawFunds(uint256 contractId, address payable recipient, uint256 amount) public {
        require(_isAuthorized(msg.sender, contractId), "Not authorized");
        require(allowedAddresses[recipient], "Recipient not allowed");
        require(amount <= _registeredContracts[contractId].balance, "Insufficient contract balance");
        
        _registeredContracts[contractId].balance -= amount;
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(contractId, recipient, amount);
    }

    function getContractDetails(uint256 contractId) public view returns (address, uint256, bytes32, uint256) {
        ExecutableContractData memory executableContract = _registeredContracts[contractId];
        return (
            executableContract.contractAddress,
            executableContract.lastExecuted,
            executableContract.stateHash,
            executableContract.balance
        );
    }

    function getContractFunctions(address contractAddress) public view returns (string[] memory) {
        return _contractFunctions[contractAddress].functionSignatures;
    }

    function getMethodIdentifier(address contractAddress, string memory functionSignature) public view returns (bytes4) {
        return _contractFunctions[contractAddress].methodIdentifiers[functionSignature];
    }

    function getContractsByOwner(address owner) public view returns (uint256[] memory) {
        return _ownedContracts[owner];
    }

    function updateFunctionPrice(uint256 newPrice) public onlyOwner {
        functionPrice = newPrice;
    }

    function _isAuthorized(address operator, uint256 contractId) internal view returns (bool) {
        address owner = ownerOf(contractId);
        return operator == owner || getApproved(contractId) == operator || isApprovedForAll(owner, operator);
    }

    receive() external payable {
        revert("Use fundContract function to add funds to a specific contract");
    }
}