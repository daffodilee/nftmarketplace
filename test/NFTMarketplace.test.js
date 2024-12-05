const { expect } = require("chai");
const { ethers } = require("hardhat");
const Marketplace = require("../src/Marketplace.json");

describe("NFTMarketplace", function () {
  let nftMarketplace, owner, addr1, addr2, addrs;

  beforeEach(async function () {
    // Deploy the contract before each test
    const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");
    nftMarketplace = await NFTMarketplace.deploy();
    await nftMarketplace.deployed();
    // Define addresses for testing
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
      expect(await nftMarketplace.getOwner()).to.equal(owner.address);
    });

    it("Should initialize with the correct list price", async function () {
      expect(await nftMarketplace.getListPrice()).to.equal(ethers.utils.parseUnits("0.01", "ether"));
    });
  });

  describe("Transactions", function () {
    it("Should create and list a token", async function () {
      const tokenURI = "https://example.com";
      const price = ethers.utils.parseUnits("1", "ether");

      await nftMarketplace.connect(owner).createToken(tokenURI, price, { value: ethers.utils.parseUnits("0.01", "ether") });

      const listedToken = await nftMarketplace.getLatestIdToListedToken();
      expect(listedToken.tokenId).to.equal(1);
      expect(listedToken.price).to.equal(price);
      expect(listedToken.currentlyListed).to.be.true;
    });

    it("Should update the list price as the owner", async function () {
      const newListPrice = ethers.utils.parseUnits("0.02", "ether");
      await nftMarketplace.connect(owner).updateListPrice(newListPrice);
      expect(await nftMarketplace.getListPrice()).to.equal(newListPrice);
    });

    it("Should fail if a non-owner tries to update list price", async function () {
      const newListPrice = ethers.utils.parseUnits("0.02", "ether");
      await expect(nftMarketplace.connect(addr1).updateListPrice(newListPrice)).to.be.revertedWith("Only owner can update listing price");
    });

    it("Should execute sale and transfer ownership", async function () {
      const tokenURI = "https://example.com";
      const price = ethers.utils.parseUnits("1", "ether");

      await nftMarketplace.connect(owner).createToken(tokenURI, price, { value: ethers.utils.parseUnits("0.01", "ether") });
      await nftMarketplace.connect(addr1).executeSale(1, { value: price });

      const listedToken = await nftMarketplace.getListedTokenForId(1);
      expect(listedToken.owner).to.equal(addr1.address);
      expect(listedToken.currentlyListed).to.be.false;
    });

    it("Should emit TokenListedSuccess event on token listing", async function () {
      const tokenURI = "https://example.com";
      const price = ethers.utils.parseUnits("1", "ether");

      await expect(nftMarketplace.connect(owner).createToken(tokenURI, price, { value: ethers.utils.parseUnits("0.01", "ether") }))
        .to.emit(nftMarketplace, 'TokenListedSuccess')
        .withArgs(1, nftMarketplace.address, owner.address, price, true);
    });
  });

  describe("Edge Cases", function () {
    it("Should revert listing with a negative price", async function () {
      const tokenURI = "https://example.com";
      const negativePrice = ethers.BigNumber.from("-1");

      await expect(nftMarketplace.connect(owner).createToken(tokenURI, negativePrice, { value: ethers.utils.parseUnits("0.01", "ether") }))
        .to.be.revertedWith("Make sure the price isn't negative");
    });

    it("Should revert sale with incorrect price", async function () {
      const tokenURI = "https://example.com";
      const price = ethers.utils.parseUnits("1", "ether");

      await nftMarketplace.connect(owner).createToken(tokenURI, price, { value: ethers.utils.parseUnits("0.01", "ether") });
      await expect(nftMarketplace.connect(addr1).executeSale(1, { value: ethers.utils.parseUnits("0.5", "ether") }))
        .to.be.revertedWith("Please submit the asking price in order to complete the purchase");
    });

    it("Should manage multiple listings and sales", async function () {
      const tokenURI1 = "https://example1.com";
      const tokenURI2 = "https://example2.com";
      const price = ethers.utils.parseUnits("1", "ether");

      await nftMarketplace.connect(owner).createToken(tokenURI1, price, { value: ethers.utils.parseUnits("0.01", "ether") });
      await nftMarketplace.connect(owner).createToken(tokenURI2, price, { value: ethers.utils.parseUnits("0.01", "ether") });

      await nftMarketplace.connect(addr1).executeSale(1, { value: price });
      await nftMarketplace.connect(addr2).executeSale(2, { value: price });

      const listedToken1 = await nftMarketplace.getListedTokenForId(1);
      const listedToken2 = await nftMarketplace.getListedTokenForId(2);

      expect(listedToken1.owner).to.equal(addr1.address);
      expect(listedToken2.owner).to.equal(addr2.address);
      expect(listedToken1.currentlyListed).to.be.false;
      expect(listedToken2.currentlyListed).to.be.false;
    });

    it("Should handle invalid inputs correctly", async function () {
      await expect(nftMarketplace.connect(addr1).executeSale(9999, { value: ethers.utils.parseUnits("1", "ether") })).to.be.reverted;
      await expect(nftMarketplace.connect(addr1).executeSale(0, { value: ethers.utils.parseUnits("1", "ether") })).to.be.reverted;
    });

    it("Should restrict user roles", async function () {
      await expect(nftMarketplace.connect(addr1).updateListPrice(ethers.utils.parseUnits("0.02", "ether"))).to.be.revertedWith("Only owner can update listing price");
    });
  });
});
