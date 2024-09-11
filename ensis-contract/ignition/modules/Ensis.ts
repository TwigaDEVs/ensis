import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const INITIAL_PRICE: bigint = 1_000_000_000n;

const EnsisModule = buildModule("EnsisModule", (m) => {
 
  const initialPrice = m.getParameter("initialPrice", INITIAL_PRICE);

  const ensis = m.contract("Lock", [initialPrice]);

  return { ensis };
});

export default EnsisModule;
