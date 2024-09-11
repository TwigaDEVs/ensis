import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { ethers } from 'https://cdn.ethers.io/lib/ethers-5.2.esm.min.js'

const ENSIS_CONTRACT_ADDRESS = Deno.env.get('ENSIS_CONTRACT_ADDRESS')!
const ENSIS_ABI_URL = Deno.env.get('ENSIS_ABI_URL')!
const RPC_URL = Deno.env.get('RPC_URL')!
const PRIVATE_KEY = Deno.env.get('PRIVATE_KEY')!

function validateAndFormatArgs(argTypes: string[], argNames: string[], jsonArgs: string): any[] {
  const args = JSON.parse(jsonArgs);
  const formattedArgs = [];

  for (let i = 0; i < argTypes.length; i++) {
    const type = argTypes[i];
    const name = argNames[i];
    const value = args[name];

    if (value === undefined) {
      throw new Error(`Missing argument: ${name}`);
    }

    switch (type) {
      case 'address':
        if (!ethers.utils.isAddress(value)) {
          throw new Error(`Invalid address for argument ${name}`);
        }
        formattedArgs.push(value);
        break;
      case 'uint256':
      case 'int256':
        try {
          formattedArgs.push(ethers.BigNumber.from(value).toString());
        } catch {
          throw new Error(`Invalid ${type} for argument ${name}`);
        }
        break;
      case 'bool':
        if (typeof value !== 'boolean') {
          throw new Error(`Invalid boolean for argument ${name}`);
        }
        formattedArgs.push(value);
        break;
      case 'string':
        if (typeof value !== 'string') {
          throw new Error(`Invalid string for argument ${name}`);
        }
        formattedArgs.push(value);
        break;
      default:
        if (type.endsWith('[]')) {
          if (!Array.isArray(value)) {
            throw new Error(`Invalid array for argument ${name}`);
          }
          formattedArgs.push(value);
        } else {
          console.warn(`Unhandled type ${type} for argument ${name}`);
          formattedArgs.push(value);
        }
    }
  }

  return formattedArgs;
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  try {
    // Parse the URL to get contract address and method name
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    if (pathParts.length !== 2) {
      throw new Error('Invalid URL format. Expected: /<contract-address>/<method-name>')
    }
    const [contractAddress, methodName] = pathParts

    // Get the JSON string from the request body
    const jsonArgs = await req.text()

    // Fetch the Ensis ABI from IPFS
    const ensisAbiResponse = await fetch(ENSIS_ABI_URL)
    const ensisAbi = await ensisAbiResponse.json()

    // Set up ethers provider and signer
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL)
    const signer = new ethers.Wallet(PRIVATE_KEY, provider)

    // Create Ensis contract instance
    const ensisContract = new ethers.Contract(ENSIS_CONTRACT_ADDRESS, ensisAbi, signer)

    // Get function details from Ensis contract
    const [selector, funcName, argTypes, argNames] = await ensisContract.getFunctionData(contractAddress, methodName)

    // Validate and format arguments
    const validatedArgs = validateAndFormatArgs(argTypes, argNames, jsonArgs)

    // Encode function parameters
    const abiCoder = new ethers.utils.AbiCoder()
    const encodedParams = abiCoder.encode(argTypes, validatedArgs)

    // Execute the function
    const tx = await ensisContract.executeFunction(contractAddress, methodName, encodedParams)
    const receipt = await tx.wait()

    return new Response(JSON.stringify(receipt), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})