// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

// import "./ConvertLib.sol";

// This is just a simple example of a coin-like contract.
// It is not ERC20 compatible and cannot be expected to talk to other
// coin/token contracts.

contract EnsisTestContract {
	struct User {
		uint id;
		string name;
	}
 
	mapping (uint => User) private users;
	uint private nextId;

	event UserCreated(uint id, string name);
	event UserUpdated(uint id, string name);
	event UserDeleted(uint id);
	
	// function to create a new user
	function createUser(string memory name) public {
		users[nextId] = User(nextId, name);
		emit UserCreated(nextId, name);
		nextId++;
	}

	// reading a user by their id
	function readUser(uint id) public view returns (uint, string memory) {
		require(id < nextId, "user does not exist");
		User memory user = users[id];
		return(user.id, user.name);
	}

	// let us now update users details
	function updateUser(uint id, string memory name) public {
		require(id < nextId, "user does not exist");
		users[id].name = name;
		emit UserUpdated(id, name);
	}

	// now let's create a function to delete user
	function deleteUser(uint id) public {
		require(id < nextId, "user does not exist");
		delete users[id];
		emit UserDeleted(id);
	}

	// getting the total number of users created
	function getTotalUsers() public view returns (uint) {
		return nextId;
	}
}