import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { ethers } from 'https://cdn.ethers.io/lib/ethers-5.2.esm.min.js'

const ENSIS_CONTRACT_ADDRESS = Deno.env.get('ENSIS_CONTRACT_ADDRESS')!
const ENSIS_ABI_URL = Deno.env.get('ENSIS_ABI_URL')!
const RPC_URL = Deno.env.get('RPC_URL')!

function convertArgument(value: any, type: string): any {
  switch (type) {
    case 'uint256':
    case 'int256':
      return ethers.BigNumber.from(value);
    case 'address':
      if (!ethers.utils.isAddress(value)) {
        throw new Error(`Invalid address: ${value}`);
      }
      return value;
    case 'bool':
      return Boolean(value);
    case 'string':
      return String(value);
    default:
      if (type.endsWith('[]') && Array.isArray(value)) {
        const baseType = type.slice(0, -2);
        return value.map(v => convertArgument(v, baseType));
      }
      console.warn(`Unhandled type: ${type}. Passing value as-is.`);
      return value;
  }
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  try {
    // Parse the URL to get the contract address and function name
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    if (pathParts.length !== 2) {
      throw new Error('Invalid URL format. Expected: /<contract-address>/<function-name>')
    }
    const [contractAddress, functionName] = pathParts

    // Parse the JSON body to get the arguments
    const argsJson = await req.text()
    const args = argsJson ? JSON.parse(argsJson) : []

    // Fetch the Ensis ABI from IPFS
    const ensisAbiResponse = await fetch(ENSIS_ABI_URL)
    const ensisAbi = await ensisAbiResponse.json()

    // Set up ethers provider
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL)

    // Create Ensis contract instance
    const ensisContract = new ethers.Contract(ENSIS_CONTRACT_ADDRESS, ensisAbi, provider)

    // Get function data
    const [selector, argTypes, argNames] = await ensisContract.getFunctionData(contractAddress, functionName)

    // Check if we have the correct number of arguments
    if (args.length !== argTypes.length) {
      throw new Error(`Expected ${argTypes.length} arguments, but got ${args.length}`)
    }

    // Convert and encode arguments
    const convertedArgs = argTypes.map((type, index) => convertArgument(args[index], type))
    const encodedParams = ethers.utils.defaultAbiCoder.encode(argTypes, convertedArgs)

    // Call the callContractFunction
    const [success, result] = await ensisContract.callContractFunction(contractAddress, functionName, encodedParams)

    if (!success) {
      throw new Error('Contract call failed')
    }

    // Decode the result
    const decodedResult = ethers.utils.defaultAbiCoder.decode(argTypes, result)

    // Format the result as an object
    const formattedResult = argNames.reduce((acc, name, index) => {
      acc[name] = decodedResult[index].toString()
      return acc
    }, {})

    return new Response(JSON.stringify(formattedResult), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})