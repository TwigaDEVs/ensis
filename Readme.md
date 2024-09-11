# Ensis

## Overview

Ensis is a tool that bridges the gap between Web2 and Web3 technologies. It allows smart contract developers to create simple HTTP interfaces for their Ethereum smart contracts, enabling interaction from any system capable of making HTTP requests - no web3 knowledge required!

ensis-smart-contract - 0xaFA5Ca570DFFCe3Fa36c874270ccae176eA0B0ac

## Key Features

- Simple contract and function registration
- Automatic HTTP endpoint generation for registered functions
- Handles all web3 interactions behind the scenes
- Supports both read and write operations on smart contracts
- Easy to integrate with existing Web2 infrastructure

## How It Works

1. **Contract Registration**: Developers register their smart contract with Ensis.
2. **Function Registration**: Developers specify which functions of their contract should be exposed via HTTP.
3. **Endpoint Generation**: Ensis automatically creates HTTP endpoints for each registered function.
4. **User Interaction**: Any system can now interact with the smart contract using simple HTTP requests.

## For Developers

### Registering Your Contract

1. Deploy your smart contract to Base Sepolia.


### Exposing Contract Functions

For each function you want to expose:

### Generated Endpoints

Ensis will generate endpoints in the format:

```
https://api.ensis.com/call/{contractId}/{functionName}
```

## For Users (Non-Web3 Systems)

### Interacting with a Contract

To call a function on a registered contract, simply make an HTTP POST request:

```
POST https://api.ensis.com/call/{contractId}/{functionName}
Content-Type: application/json

{
  "params": ["0x123...", "1000000000000000000"]
}
```

### Reading Contract Data

For read operations:

```
GET https://api.ensis.com/call/{contractId}/{functionName}?param1=value1&param2=value2
```


## Benefits

- **For Developers**: Easily make your smart contracts accessible to a wider range of applications and users.

- **For Businesses**: Integrate blockchain functionality into existing systems without overhauling your infrastructure.

## Future Works

We're constantly working to improve Ensis and expand its capabilities. Here are some features and improvements we're considering for future releases:

1. **User interfacw**: impliment user interface.

2. **complete endpoint autogeneration**: 

3. **Custom Gas Strategies**: Provide options for users to define their own gas price strategies for transactions.

4. **Support for More Networks**: Expand beyond Ethereum to support other blockchain networks like Binance Smart Chain, Polygon, etc.



## License

MIT License

Copyright (c) [year] [fullname]



