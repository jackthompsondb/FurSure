const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FurCoin Lifecycle Test", function () {
  let creator, vet, sponsor, shelter, owner, carer, finder, publicAccount;
  let furCoin;

  beforeEach(async function () {
    // Deploy FurCoin contract
    const FurCoin = await ethers.getContractFactory("FurCoin");
    furCoin = await FurCoin.deploy();
    await furCoin.waitForDeployment();

    // Get signers
    [creator, vet, sponsor, shelter, owner, carer, finder, publicAccount] = await ethers.getSigners();

    // Assign roles
    await furCoin.connect(creator).assignPermissionedRole(shelter.address, 3); // Assign Shelter role
    await furCoin.connect(creator).assignPermissionedRole(vet.address, 1); // Assign Vet role
    await furCoin.connect(creator).assignPermissionedRole(sponsor.address, 2); // Assign Sponsor role
    await furCoin.connect(creator).assignPermissionedRole(owner.address, 4); // Assign Owner role
    await furCoin.connect(creator).assignPermissionedRole(carer.address, 5); // Assign Member of Public role
  });

  it("Should deploy FurCoin contract", async function () {
    expect(furCoin.target).to.be.properAddress;
  });

  it("Creator should be able to assign permissioned roles", async function () {
    await furCoin.connect(creator).assignPermissionedRole(vet.address, 1); // Assign Vet role
    const vetRole = await furCoin.roles(vet.address);
    expect(vetRole).to.equal(1);

    await furCoin.connect(creator).assignPermissionedRole(sponsor.address, 2); // Assign Sponsor role
    const sponsorRole = await furCoin.roles(sponsor.address);
    expect(sponsorRole).to.equal(2);

    await furCoin.connect(creator).assignPermissionedRole(shelter.address, 3); // Assign Shelter role
    const shelterRole = await furCoin.roles(shelter.address);
    expect(shelterRole).to.equal(3);
  });

  it("Shelter should be able to register a pet and set reward level", async function () {
    // Register a pet
    await furCoin.connect(shelter).registerPet(1, "Furry", 12, "Partially blind in left eye");
    const petOwner = await furCoin.connect(shelter).getOwner(1);
    expect(petOwner).to.equal(shelter.address);

    // Set reward level for the pet
    await furCoin.connect(shelter).changeRewardLevel(1, 5);

    // View reward level for the pet as a vet
    const rewardLevelVet = await furCoin.connect(vet).getRewardLevel(1);
    expect(rewardLevelVet).to.equal(5);

    // View reward level for the pet as a sponsor
    const rewardLevelSponsor = await furCoin.connect(sponsor).getRewardLevel(1);
    expect(rewardLevelSponsor).to.equal(5);
  });

  it("Shelter should be able to transfer a pet to an owner", async function () {
    // Register a pet
    await furCoin.connect(shelter).registerPet(2, "Buddy", 3, "Healthy");
    const initialPetOwner = await furCoin.connect(shelter).getOwner(2);
    expect(initialPetOwner).to.equal(shelter.address);

    // Transfer the pet to the owner
    await furCoin.connect(shelter).transferPet(2, owner.address);
    const newPetOwner = await furCoin.connect(shelter).getOwner(2);
    expect(newPetOwner).to.equal(owner.address);
  });
  // Add more tests specific to FurCoin functionality here
  it("Vet should be able to provide a multiplied reward to a pet's owner", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(3, "Max", 10, "Deaf");
    await furCoin.connect(shelter).changeRewardLevel(3, 2);
    await furCoin.connect(shelter).transferPet(3, owner.address);

    // Vet provides reward to the pet's owner
    await furCoin.connect(vet).giveReward(3, 100);
    const ownerBalance = await furCoin.getBalance(owner.address);
    expect(ownerBalance).to.equal(200);
  });

  it("Vet should be able to amend a pet record", async function () {
    // Register a pet
    await furCoin.connect(shelter).registerPet(4, "Bella", 5, "Healthy");
  
    // Vet amends the pet record
    await furCoin.connect(vet).amendPetRecord(4, "Bella", 6, "Updated medical history");
  
    // Verify the amended pet record
    const petRecord = await furCoin.connect(shelter).viewPetRecord(4);
    expect(petRecord.name).to.equal("Bella");
    expect(petRecord.age).to.equal(6);
    expect(petRecord.medicalHistory).to.equal("Updated medical history");
  });
  it("Owner should be able to spend FUR tokens at a store (Store Burns & Mints according)", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(5, "Charlie", 4, "Healthy");
    await furCoin.connect(shelter).transferPet(5, owner.address);
  
    // Vet provides reward to the pet's owner
    await furCoin.connect(vet).giveReward(5, 100);
    let ownerBalance = await furCoin.getBalance(owner.address);
    expect(ownerBalance).to.equal(100);
  
    // Owner spends FUR tokens at a store
    await furCoin.connect(sponsor).spendReward(owner.address, 50);
    ownerBalance = await furCoin.getBalance(owner.address);
    expect(ownerBalance).to.equal(50);
  });
  it("Owner should be able to flag a pet as lost", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(6, "Luna", 3, "Healthy");
    await furCoin.connect(shelter).transferPet(6, owner.address);
  
    // Owner flags the pet as lost
    await furCoin.connect(owner).lostPet(6, "123-456-7890");
  
    // Verify the pet is flagged as lost
    const isLost = await furCoin.petLost(6);
    expect(isLost).to.be.true;
  
    // Verify the lost pet phone number
    const lostPhoneNumber = await furCoin.petLostPhoneNumber(6);
    expect(lostPhoneNumber).to.equal("123-456-7890");
  });
  it("Member of public should be able to find a lost pet and receive owner's contact number", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(7, "Rocky", 2, "Healthy");
    await furCoin.connect(shelter).transferPet(7, owner.address);
  
    // Owner flags the pet as lost
    await furCoin.connect(owner).lostPet(7, "123-456-7890");
  
    // Member of public finds the lost pet
    const petOwner = await furCoin.connect(carer).findOwner(7);
    expect(petOwner).to.equal(owner.address);
  
    // Verify the lost pet phone number
    const lostPhoneNumber = await furCoin.petLostPhoneNumber(7);
    expect(lostPhoneNumber).to.equal("123-456-7890");
  });
  it("Owner should be able to register a pet as found and the phone number is no longer visible", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(8, "Shadow", 5, "Healthy");
    await furCoin.connect(shelter).transferPet(8, owner.address);
  
    // Owner flags the pet as lost
    await furCoin.connect(owner).lostPet(8, "123-456-7890");
  
    // Verify the pet is flagged as lost
    let isLost = await furCoin.petLost(8);
    expect(isLost).to.be.true;
  
    // Owner registers the pet as found
    await furCoin.connect(owner).foundPet(8);
  
    // Verify the pet is no longer flagged as lost
    isLost = await furCoin.petLost(8);
    expect(isLost).to.be.false;
  
    // Verify the lost pet phone number is no longer visible
    const lostPhoneNumber = await furCoin.petLostPhoneNumber(8);
    expect(lostPhoneNumber).to.equal("");
  });
  it("Owner should be able to transfer tokens to a member of the public as a reward", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(9, "Buddy", 3, "Healthy");
    await furCoin.connect(shelter).transferPet(9, owner.address);
  
    // Vet provides reward to the pet's owner
    await furCoin.connect(vet).giveReward(9, 100);
    let ownerBalance = await furCoin.getBalance(owner.address);
    expect(ownerBalance).to.equal(100);
  
    // Owner transfers tokens to a member of the public
    await furCoin.connect(owner).transfer(carer.address, 50);
    ownerBalance = await furCoin.getBalance(owner.address);
    expect(ownerBalance).to.equal(50);
  
    const carerBalance = await furCoin.getBalance(carer.address);
    expect(carerBalance).to.equal(50);
  });
  it("Owner should be able to assign and revoke carer roles", async function () {
    // Register a pet and transfer to owner
    await furCoin.connect(shelter).registerPet(10, "Max", 4, "Healthy");
    await furCoin.connect(shelter).transferPet(10, owner.address);
  
    // Owner assigns a carer role
    await furCoin.connect(owner).registerCarer(10, carer.address);
    let assignedCarer = await furCoin.petCarer(10);
    expect(assignedCarer).to.equal(carer.address);
  
    // Owner revokes the carer role
    await furCoin.connect(owner).deregisterCarer(10, carer.address);
    
    // Verify the carer's role is set to 5 (General Public)
    const carerRole = await furCoin.roles(carer.address);
    expect(carerRole).to.equal(5);
  });
});

describe("Defended Against Malicous Attacks Test", function () {
  let creator, vet, sponsor, shelter, owner, carer, finder, publicAccount;
  let furCoin;

  beforeEach(async function () {
    // Deploy FurCoin contract
    const FurCoin = await ethers.getContractFactory("FurCoin");
    furCoin = await FurCoin.deploy();
    await furCoin.waitForDeployment();

    // Get signers
    [creator, vet, sponsor, shelter, owner, carer, finder, publicAccount] = await ethers.getSigners();

    // Assign roles
    await furCoin.connect(creator).assignPermissionedRole(shelter.address, 3); // Assign Shelter role
    await furCoin.connect(creator).assignPermissionedRole(vet.address, 1); // Assign Vet role
    await furCoin.connect(creator).assignPermissionedRole(sponsor.address, 2); // Assign Sponsor role
    await furCoin.connect(creator).assignPermissionedRole(owner.address, 4); // Assign Owner role
    await furCoin.connect(creator).assignPermissionedRole(carer.address, 5); // Assign Member of Public role
  });
  it("Unauthorised user trying to mint", async function () {
    await expect(furCoin.connect(carer).mint(1000)).to.be.revertedWith("Only creator can use this function");
  });

  it("Shelter attempting to use giveReward (mint) FURC", async function () {
    await furCoin.connect(shelter).registerPet(1, "Buddy", 3, "Healthy");
    await furCoin.connect(shelter).transferPet(1, owner.address);
    await expect(furCoin.connect(shelter).giveReward(1, 100)).to.be.revertedWith("Only Vet or Sponsor can use this function");
  });

  it("Trying to find owner of a pet that is not registered as lost", async function () {
    await furCoin.connect(shelter).registerPet(2, "Max", 4, "Healthy");
    await furCoin.connect(shelter).transferPet(2, owner.address);
    await expect(furCoin.connect(carer).findOwner(2)).to.be.revertedWith("Pet is not lost");
  });

  it("Member of public trying to register themselves as carer or owner", async function () {
    await furCoin.connect(shelter).registerPet(3, "Luna", 2, "Healthy");
    await furCoin.connect(shelter).transferPet(3, owner.address);
    await expect(furCoin.connect(carer).registerCarer(3, carer.address)).to.be.revertedWith("Only the owner can register a carer");
  });

  it("Owner trying to give themselves a reward", async function () {
    await furCoin.connect(shelter).registerPet(4, "Rocky", 5, "Healthy");
    await furCoin.connect(shelter).transferPet(4, owner.address);
    await expect(furCoin.connect(owner).giveReward(4, 100)).to.be.revertedWith("Only Vet or Sponsor can use this function");
  });
});