import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";


describe("NFTClaimWithPermit", function () {
  async function deployNFTClaimWithPermitFixture() {
    const [owner, user] = await ethers.getSigners();

    const maxTotalSupply = 10000; // Example value for max total supply
    const baseURI = "https://example.com/api/token/"; // Example base URI

    const MockERC1155 = await ethers.getContractFactory("MyToken");
    const mockERC1155 = await MockERC1155.deploy(owner.address, owner.address, maxTotalSupply, baseURI);

    const NFTClaimWithPermit = await ethers.getContractFactory("NFTClaim");
    const nftClaimWithPermit = await NFTClaimWithPermit.deploy(mockERC1155.target);

    // Mint ERC1155 tokens to the owner
    const tokenId = 1;
    const amount = 100; // Arbitrary amount
    await mockERC1155.connect(owner).mint(owner.address, tokenId, amount, "0x");

    // Approve NFTClaimWithPermit contract to transfer tokens on behalf of owner
    await mockERC1155.connect(owner).setApprovalForAll(await nftClaimWithPermit.getAddress(), true);

    return { nftClaimWithPermit, mockERC1155, owner, user };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { nftClaimWithPermit, owner } = await loadFixture(deployNFTClaimWithPermitFixture);
      expect(await nftClaimWithPermit.owner()).to.equal(owner.address);
    });
  });

  describe("Claim NFT With Permit", function () {
    it("Should fail with invalid signature", async function () {
      const { nftClaimWithPermit, user } = await loadFixture(deployNFTClaimWithPermitFixture);
      const invalidSignature = "0x" + "00".repeat(65);
      await expect(
        nftClaimWithPermit.connect(user).claimNFTWithPermit(
          1, // tokenId
          1, // amount
          Math.floor(Date.now() / 1000) + 3600, // deadline (1 hour from now)
          invalidSignature
        )
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should successfully claim NFT with valid signature", async function () {
      const { nftClaimWithPermit, owner, user } = await loadFixture(deployNFTClaimWithPermitFixture);
      const tokenId = 1;
      const amount = 1;
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const chainId = Number((await owner.provider.getNetwork()).chainId); // Fetch the actual chainId
      const nonce = await nftClaimWithPermit._nonces(user.address);
  
      const signature = await generateSignature(
        await nftClaimWithPermit.getAddress(), // Use direct address
        owner,
        user.address,
        tokenId,
        amount,
        Number(nonce.toString()),
        deadline,
        chainId
      );
  
      await expect(
        nftClaimWithPermit.connect(user).claimNFTWithPermit(
          tokenId,
          amount,
          deadline,
          signature
        )
      ).not.to.be.reverted;
    });

  });

  async function generateSignature(
    nftClaimAddress: string,
    owner: SignerWithAddress,
    spender: string,
    tokenId: number,
    amount: number,
    nonce: number,
    deadline: number,
    chainId: number
  ): Promise<string> {
    const domain = {
      name: "NFTClaim",
      version: "1",
      chainId: chainId,
      verifyingContract: nftClaimAddress
    };

    const types = {
      Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "tokenId", type: "uint256" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
        { name: "chainId", type: "uint256" }
      ]
    };

    const value = {
      owner: owner.address,
      spender,
      tokenId,
      amount,
      nonce,
      deadline,
      chainId
    };

    return await owner.signTypedData(domain, types, value);
  }
});
