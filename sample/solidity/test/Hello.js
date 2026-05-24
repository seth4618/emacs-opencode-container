const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Hello", function () {
  it("should return greeting with contract address", async function () {
    const Hello = await ethers.getContractFactory("Hello");
    const hello = await Hello.deploy();
    await hello.waitForDeployment();

    const contractAddress = await hello.getAddress();
    const greeting = await hello.greet();

    expect(greeting).to.include("Hello from Solidity in the container!");
    expect(greeting.toLowerCase()).to.include(contractAddress.toLowerCase());
  });
});
