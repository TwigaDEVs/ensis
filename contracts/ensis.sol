// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@ensdomains/ens-contracts/contracts/registry/ENSRegistry.sol";

contract ENSIS is ERC721, Ownable {
    uint256 private _nextTokenId;
    IERC20 public utilityToken;
    uint256 public functionPrice;

    ENSIS public ens;  // Using ENSRegistry for permission management

    // Define structure for LambdaFunction and permissions
    struct LambdaFunction {
        uint256 id;
        string functionURI;
        address owner;
        uint256 lastExecuted;
        bytes32 stateHash;
    }

    struct FunctionPermission {
        address allowedAddress;
        string functionName;
    }

    // Mappings
    mapping(uint256 => LambdaFunction) private _functions;             // For Lambda functions
    mapping(address => uint256[]) private _ownedFunctions;             // Functions owned by addresses
    mapping(bytes32 => FunctionPermission) public permissions;         // ENS node to permission mapping

    // Events
    event FunctionRegistered(uint256 indexed functionId, string functionURI, address indexed owner);
    event FunctionExecuted(uint256 indexed functionId, bytes32 stateHash, uint256 timestamp);
    event PermissionSet(bytes32 indexed node, address indexed allowedAddress, string functionName);

    // Constructor for initializing utility token, price, and ENS registry
    constructor(address tokenAddress, uint256 initialPrice, address ensAddress) 
        ERC721("ENSIS Function", "ENSIS") Ownable(msg.sender) {
        utilityToken = IERC20(tokenAddress);
        functionPrice = initialPrice;
        ens = ENSIS(ensAddress); // Initialize ENS registry
        _nextTokenId = 1;
    }

    // Register a new lambda function (tokenized function)
    function registerFunction(string memory functionURI) public {
        require(utilityToken.transferFrom(msg.sender, address(this), functionPrice), "Payment failed");

        uint256 functionId = _nextTokenId++;
        _safeMint(msg.sender, functionId);

        _functions[functionId] = LambdaFunction({
            id: functionId,
            functionURI: functionURI,
            owner: msg.sender,
            lastExecuted: block.timestamp,
            stateHash: bytes32(0)
        });

        _ownedFunctions[msg.sender].push(functionId);

        emit FunctionRegistered(functionId, functionURI, msg.sender);
    }

    // Execute the function and update its state
    function executeFunction(uint256 functionId, bytes32 newStateHash) public {
        require(_isAuthorized(msg.sender, functionId), "Not authorized");
        LambdaFunction storage lambda = _functions[functionId];
        lambda.stateHash = newStateHash;
        lambda.lastExecuted = block.timestamp;

        emit FunctionExecuted(functionId, newStateHash, block.timestamp);
    }

    // Get details of a function
    function getFunctionDetails(uint256 functionId) public view returns (string memory, address, uint256, bytes32) {
        LambdaFunction memory lambda = _functions[functionId];
        return (lambda.functionURI, lambda.owner, lambda.lastExecuted, lambda.stateHash);
    }

    // Set permissions for an ENS domain
    function setPermission(bytes32 node, address allowedAddress, string memory functionName) public onlyOwner {
        permissions[node] = FunctionPermission(allowedAddress, functionName);
        emit PermissionSet(node, allowedAddress, functionName);
    }

    // ENS-based function execution with permission check
    function executeENSFunction(bytes32 node, string memory functionName, bytes memory data) public {
        FunctionPermission memory perm = permissions[node];

        require(perm.allowedAddress == msg.sender, "Not allowed");
        require(keccak256(bytes(perm.functionName)) == keccak256(bytes(functionName)), "Function not allowed");

        // Call the function based on permission (assuming the data matches the function signature)
        (bool success, ) = address(this).call(data);
        require(success, "Function execution failed");
    }

    // Example function for type-checking
    function increment(uint256 number) public pure returns (uint256) {
        require(number >= 0, "Number must be positive");
        return number + 1;
    }

    // Example restricted function (only accessible via permissions)
    function restrictedFunction() public pure returns (string memory) {
        return "This is a restricted function";
    }

    // Get all functions owned by a specific address
    function getFunctionsByOwner(address owner) public view returns (uint256[] memory) {
        return _ownedFunctions[owner];
    }

    // Update function price
    function updateFunctionPrice(uint256 newPrice) public onlyOwner {
        functionPrice = newPrice;
    }

    // Withdraw tokens from the contract
    function withdrawTokens(uint256 amount) public onlyOwner {
        require(amount <= utilityToken.balanceOf(address(this)), "Insufficient tokens");
        utilityToken.transfer(owner(), amount);
    }

    // Check if the caller is the owner or has approval for a lambda function
    function _isAuthorized(address operator, uint256 functionId) internal view returns (bool) {
        address owner = ownerOf(functionId);
        return operator == owner || getApproved(functionId) == operator || isApprovedForAll(owner, operator);
    }
}
