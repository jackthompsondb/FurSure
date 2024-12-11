// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Info:  
// Roles: Creator (0), Vet (1), Sponsor (2), Shelter (3), Owner (4), General Public (5 or "")

contract FurCoin {
    // initial supply of token
    
    uint256 public supply = 1000000;
    string public name = "FurCoin"; 
    string public symbol = "FUR";
    uint8 public decimals = 1;

    // Token-related event
    event TokenTransferred(address indexed _from, address indexed _to, uint256 _value);

    // Approval-related events
    event OwnerApproved(address indexed _shelter, address indexed _newOwner);
    event PermissionedRoleApproved(address indexed _from, address indexed _to, uint256 _role);
    event PermissionedRoleRevoked(address indexed _from, address indexed _to, uint256 _role);

    // Pet lifecycle events
    event PetRegistered(address indexed _shelter, uint256 indexed _petId);
    event PetAdopted(address indexed _shelter, address indexed _adopter, uint256 indexed _petId);
    event CarerRegistered(uint256 indexed petId, address indexed carer);
    event CarerDeregistered(uint256 indexed petId, address indexed carer);
    event PetLost(uint256 indexed _petId);
    event PetFound(uint256 indexed _petId);

    // create mappings
    mapping(address => uint256) public balances; // Maps an address to a balance
    mapping(address => uint256) public roles;  // Maps an address to a role
    mapping(uint256 => uint256) public petRewardLevel; // Maps pet ID to its reward level
    mapping(uint256 => address) public petOwner; // Maps a pet ID to its owner  
    mapping(uint256 => address) public petCarer; // Maps a pet ID to its carer  
    mapping(uint256 => bool) public petAdopted; // Tracks if a pet ID is adopted
    mapping(uint256 => bool) public petLost;    // Tracks if a pet ID is lost
    mapping(uint256 => string) public petLostPhoneNumber; // Maps a pet ID to a phone number when lost
    mapping(uint256 => PetRecord) private petRecords; // Maps a pet ID to its record
    
    // pet record structure
    struct PetRecord {
        string name;
        uint256 age;
        string medicalHistory;
        bool exists; // To ensure the pet record exists before accessing
    }

    // create constructor
    constructor() {
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
    modifier onlyAuthorized(uint256 _petId) {
        require(msg.sender == petOwner[_petId] || msg.sender == petCarer[_petId] || roles[msg.sender] == 3, 
            "Access restricted to Owner, Carer, or Shelter");
        _;
    }

    function mint(uint256 _amount) public onlyCreator {
        // Function for the creator to mint new tokens
        supply += _amount;
        balances[msg.sender] += _amount;
        emit TokenTransferred(address(0), msg.sender, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyCreator {
        // Function for the creator to burn tokens
        require(balances[_from] >= _amount, "Insufficient balance to burn");
        supply -= _amount;
        balances[_from] -= _amount;
        emit TokenTransferred(_from, address(0), _amount);
    }

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

    function getOwner(uint256 _petId) public onlyVetOrShelter view returns (address) {
        // Function to check the owner of a pet
        return petOwner[_petId];
    }

    function registerPet(uint256 _petId, string memory _name, uint256 _age, string memory _medicalHistory) public onlyShelter {
        require(!petRecords[_petId].exists, "Pet is already registered");
        // Function for Shelters to register a new pet
        petOwner[_petId] = msg.sender;
        petAdopted[_petId] = false;
        petRewardLevel[_petId] = 1;

        // Initialize a basic pet record
        petRecords[_petId] = PetRecord({
            name: _name,
            age: _age,
            medicalHistory: _medicalHistory,
            exists: true
        });

        // Emit events for registration and record initialization
        emit PetRegistered(msg.sender, _petId);
    }

    function viewPetRecord(uint256 _petId) public view onlyAuthorized(_petId) returns (PetRecord memory) {
        require(petRecords[_petId].exists, "Pet record does not exist");
        return petRecords[_petId];
    }

    function amendPetRecord(uint256 _petId, string memory _name, uint256 _age, string memory _medicalHistory) public onlyVetOrShelter {
        require(petRecords[_petId].exists, "Pet record does not exist");
        // Function for Vets to amend a pet's record
        petRecords[_petId].name = _name;
        petRecords[_petId].age = _age;
        petRecords[_petId].medicalHistory = _medicalHistory;
    }

    function changeRewardLevel(uint256 _petId, uint256 _rewardLevel) public onlyShelter {
        // Function for Shelters to change the reward level of a pet
        petRewardLevel[_petId] = _rewardLevel;
    }

    function approveAsOwner(address _allowedOwner) public onlyShelter {
        // Function for Shelters to approve a new owner so they can adopt a pet
        require(roles[_allowedOwner] != 0, "Cannot change system manager's role");
        require(roles[_allowedOwner] != 1, "Cannot change Vet's role");
        require(roles[_allowedOwner] != 2, "Cannot change Sponsor's role");
        roles[_allowedOwner] = 4;
        emit OwnerApproved(msg.sender, _allowedOwner);
    }

    function transferPet(uint256 _petId, address _newOwner) public onlyShelter {
        // Function for Shelters to transfer ownership of a pet to a new owner
        require(petOwner[_petId] == msg.sender, "Only the owner can transfer the pet");
        petOwner[_petId] = _newOwner;
        petAdopted[_petId] = true;
        emit PetAdopted(msg.sender, _newOwner, _petId);
    }

    function registerCarer(uint256 _petId, address _carer) public {
        // Function for Owners to register a carer for a pet
        require(petOwner[_petId] == msg.sender, "Only the owner can register a carer");
        petCarer[_petId] = _carer;
        emit CarerRegistered(_petId, _carer);
    }

    function deregisterCarer(uint256 _petId, address _carer) public {
        // Function for Owners to deregister a carer for a pet
        require(petOwner[_petId] == msg.sender, "Only the owner can deregister a carer");
        petCarer[_petId] = address(0);
        emit CarerDeregistered(_petId, _carer);
    }

    function lostPet(uint256 _petId,string memory _phonenumber) public {
        // Function for Vets or Shelters to mark a pet as lost
        require(petOwner[_petId] == msg.sender, "Only the owner can mark a pet as lost");
        petLost[_petId] = true;
        petLostPhoneNumber[_petId] = _phonenumber;
        emit PetLost(_petId);
    }

    function foundPet(uint256 _petId) public {
        require(petOwner[_petId] == msg.sender, "Only the owner can mark a pet as found");
        petLost[_petId] = false;
        petLostPhoneNumber[_petId] = "";
        emit PetFound(_petId);
    }

    function findOwner(uint256 _petId) public view returns (address) {
        // Function for General Public to find the owner of a lost pet
        require(petLost[_petId] == true, "Pet is not lost");
        return petOwner[_petId];
    }

    function getRewardLevel(uint256 _petId) public view onlyVetOrSponsor returns (uint256) {
        // Function for General Public to find the reward level of a pet
        return petRewardLevel[_petId];
    }

    function giveReward(uint256 _petId, uint256 _value) public onlyVetOrSponsor {
        // Function for Vets or Sponsors to give a token reward to a pet's owner
        uint256 multiplier = petRewardLevel[_petId];
        uint256 reward = _value * multiplier;
        supply += reward;
        balances[petOwner[_petId]] += reward;
        emit TokenTransferred(msg.sender, petOwner[_petId], reward);
    }

    function spendReward(address _owner, uint256 _value) public onlySponsor {
        // Function for Owners to spend their token rewards
        require(balances[_owner] >= _value, "Insufficient balance");
        supply -= _value;
        balances[_owner] -= _value;
        emit TokenTransferred(_owner, address(0), _value);
    }

    function transfer(address _to, uint256 _value) public {
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