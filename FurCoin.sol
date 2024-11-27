// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Info:  
// Roles: Creator (0), Vet (1), Sponsor (2), Shelter (3), Owner (4), General Public (5)

contract FurCoin {
    // initial supply of token
    
    uint256 supply = 100;
    string public name; 
    string public symbol;
    uint8 public decimals;    
    // Token-related event
    event TokenTransferred(address indexed _from, address indexed _to, uint256 _value);

    // Approval-related events
    event OwnerApproved(address indexed _shelter, address indexed _newOwner);
    event PermissionedRoleApproved(address indexed _from, address indexed _to, uint256 _role);
    event PermissionedRoleRevoked(address indexed _from, address indexed _to, uint256 _role);

    // Pet lifecycle events
    event PetRegistered(address indexed _shelter, address indexed _pet);
    event PetAdopted(address indexed _shelter, address indexed _adopter, address indexed _pet);
    event CarerRegistered(address indexed pet, address indexed carer);
    event CarerDeregistered(address indexed pet, address indexed carer);
    event PetLost(address indexed _pet);
    event PetFound(address indexed _pet);

   

    // create mappings
    mapping(address => uint256) public balances; // Maps an address to a balance
    mapping(address => uint256) public roles;  // Maps an address to a role
    mapping(address => uint256) public petRewardLevel; // Maps pet address to its reward level
    mapping(address => address) public petOwner; // Maps a pet to its owner  
    mapping(address => address) public petCarer; // Maps a pet to its carer  
    mapping(address => bool) public petAdopted; // Tracks if an address is an adopter
    mapping(address => bool) public petLost;    // Tracks if a pet is lost


     // create constructor
     constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balances[msg.sender] = supply;
        roles[msg.sender] = 0;
    }

    // create modifiers to optimise function size and reduce redundancy 
    modifier onlyCreator() {
        require(roles[msg.sender] == 0, "Only creator can use this function");
        _;
    }
    modifier onlyVetOrShelter() {
        require(roles[msg.sender] == 1 || roles[msg.sender] == 3, "Only Vet or Shelter can use this function");
        _;
    }
    modifier onlyVetOrSponsor() {
        require(roles[msg.sender] == 1 || roles[msg.sender] == 2, "Only Vet or Sponsor can use this function");
        _;
    }
    modifier onlyShelter() {
        require(roles[msg.sender] == 3, "Only Shelter can use this function");
        _;
    }
    modifier onlySponsor() {
        require(roles[msg.sender] == 2, "Only Sponsor Stores can use this function");
        _;
    }

   

    // functions to be implemented 

    function assignPermissionedRole(address _address, uint256 _role) public onlyCreator {
        // Function for system manager to assign roles permissioned roles
        // such as Vet, Sponsor, Shelter or anything else
        require(_role >= 0 && _role <= 5, "Invalid role");
        roles[_address] = _role;
        emit PermissionedRoleApproved(msg.sender, _address, _role);
    }

    function revokePermissionedRole(address _address) public onlyCreator {
        // Function for system manager to revoke permissioned roles
        // such as Vet, Sponsor, Shelter or anything else
        uint256 previous_role = roles[_address];
        roles[_address] = 5;
        emit PermissionedRoleRevoked(msg.sender, _address, previous_role);
    }

    function totalSupply() public view returns (uint256) {
        // return total supply of FurCoin
        return supply;
    }
    function getOwner(address _pet) public onlyVetOrShelter view returns (address) {
        // Function to check the owner of a pet
        return petOwner[_pet];
    }
    function registerPet(address _pet) public onlyShelter {
        // Function for Shelters to register a new pet in system
        petOwner[_pet] = msg.sender;
        petAdopted[_pet] = false;
        petRewardLevel[_pet] = 1;
        emit PetRegistered(msg.sender, _pet);
    }
    function changeRewardLevel(address _pet, uint256 _rewardLevel) public onlyShelter {
        // Function for Shelters to change the reward level of a pet
        petRewardLevel[_pet] = _rewardLevel;
    }
    function approveAsOwner(address _allowedOwner) public onlyShelter {
        // Function for Shelters to approve a new owner so they can adopt a pet
        roles[_allowedOwner] = 4;
        emit OwnerApproved(msg.sender, _allowedOwner);
    }
    function transferPet(address _pet, address _newOwner) public onlyShelter {
        // Function for Shelters to transfer ownership of a pet to a new owner
        require(petOwner[_pet] == msg.sender, "Only the owner can transfer the pet");
        petOwner[_pet] = _newOwner;
        petAdopted[_pet] = true;
        emit PetAdopted(msg.sender, _newOwner, _pet);
    }

    function registerCarer(address _pet, address _carer) public  {
        // Function for Owners to register a carer for a pet
        require(petOwner[_pet] == msg.sender, "Only the owner can register a carer");
        petCarer[_pet] = _carer;
        emit CarerRegistered(_pet, _carer);
    }
    function deregisterCarer(address _pet, address _carer) public {
        // Function for Owners to deregister a carer for a pet
        require(petOwner[_pet] == msg.sender, "Only the owner can deregister a carer");
        petCarer[_pet] = address(0);
        emit CarerDeregistered(_pet, _carer);
    }
    function lostPet(address _pet) public {
        // Function for Vets or Shelters to mark a pet as lost
        require(petOwner[_pet] == msg.sender, "Only the owner can mark a pet as lost");
        petLost[_pet] = true;
        emit PetLost(_pet);
    }
    function foundPet(address _pet) public {
        require(petOwner[_pet] == msg.sender, "Only the owner can mark a pet as found");
        petLost[_pet] = false;
        emit PetFound(_pet);
    }
    function findOwner(address _pet) public view returns (address) {
        // Function for General Public to find the owner of a lost pet
        require(petLost[_pet] == true, "Pet is not lost");
        return petOwner[_pet];
    }
    function getRewardLevel(address _pet) public view onlyVetOrSponsor returns (uint256) {
        // Function for General Public to find the reward level of a pet
        return petRewardLevel[_pet];
    }
    function giveReward(address _pet,uint256 _value) public onlyVetOrSponsor {
        // Function for Vets or Sponsors to give a token reward to a pet's owner
        uint256 multiplier = petRewardLevel[_pet];
        uint256 reward = _value * multiplier;
        supply += reward;
        balances[petOwner[_pet]] += reward;
        emit TokenTransferred(msg.sender, petOwner[_pet], reward);
    }
    function spentReward(address _owner, uint256 _value) public onlySponsor {
        // Function for Owners to spend their token rewards
        require(balances[_owner] >= _value, "Insufficient balance");
        supply -= _value;
        balances[_owner] -= _value;

    }
    function transferCoin(address _to, uint256 _value) public {
        // Function for Owners to transfer tokens to another address
        require(balances[msg.sender] >= _value, "Insufficient balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit TokenTransferred(msg.sender, _to, _value);
    }
    function getBalance(address _address) public view returns (uint256) {
        // Function for General Public to check their token balance
        return balances[_address];
    }
}