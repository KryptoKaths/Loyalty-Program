pragma solidity >=0.8.2 <0.9.0;

contract LoyaltyProgram {
    // State Variables
    uint256 internal constant INITIAL_POINTS = 100;

    address internal owner;
    bool internal lock; // re-entrancy guard

    address[] internal customersAddresses;
    string[] internal rewardNames;

    mapping(address => uint256) internal loyaltyPoints;
    mapping(string => Reward) internal rewards;

    struct Reward {
        string name;
        uint256 prize;
        uint256 pointsNeeded;
        uint256 quantity;
    }

    // Events
    event AccountCreated(address indexed _addr);
    event PointsEarned(address indexed _addr, uint256 pointsEarned);
    event PointsRedeemed(address indexed _addr, uint256 pointsRedeemed, string rewardName);

    // Functional Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyCustomer() {
        require(customerExists(msg.sender), "You are not a customer!");
        _;
    }

    modifier onlyNewCustomer() {
        require(!customerExists(msg.sender), "You are already a customer!");
        _;
    }

    modifier reEntrancyGuard() {
        require(!lock, "This smart contract is locked at the moment");
        lock = true;
        _;
        lock = false;
    }

    // Helper Functions
    function customerExists(address _customerAddr) internal view returns (bool) {
        for (uint256 idx = 0; idx < customersAddresses.length; idx++) {
            if (customersAddresses[idx] == _customerAddr) {
                return true;
            }
        }
        return false;
    }

    function rewardExists(string memory _rewardName) internal view returns (bool) {
        for (uint256 idx = 0; idx < rewardNames.length; idx++) {
            if (keccak256(abi.encodePacked(rewardNames[idx])) == keccak256(abi.encodePacked(_rewardName))) {
                return true;
            }
        }
        return false;
    }

    // Constructor
    constructor() payable {
        owner = msg.sender;
        lock = false;
    }

    // Functions
    function createAccount() public onlyNewCustomer {
        customersAddresses.push(msg.sender);
        loyaltyPoints[msg.sender] = INITIAL_POINTS;
        emit AccountCreated(msg.sender);
    }

    function getPointsBalance() public view onlyCustomer returns (uint256) {
        return loyaltyPoints[msg.sender];
    }

    function earnPoints(uint256 _points) public onlyCustomer {
        loyaltyPoints[msg.sender] += _points;
        emit PointsEarned(msg.sender, _points);
    }

    function redeemPoints(string memory _rewardName) public onlyCustomer reEntrancyGuard {
        require(rewardExists(_rewardName), "This reward does not exist!");

        Reward storage currentReward = rewards[_rewardName];

        require(loyaltyPoints[msg.sender] >= currentReward.pointsNeeded, "You do not have enough points!");

        loyaltyPoints[msg.sender] -= currentReward.pointsNeeded;
        currentReward.quantity--;

        emit PointsRedeemed(msg.sender, currentReward.pointsNeeded, _rewardName);

        (bool success, ) = payable(msg.sender).call{value: currentReward.prize}("");
        require(success, "Transfer failed!");
    }

    function addReward(
        string memory _rewardName,
        uint256 _rewardPrize,
        uint256 _rewardPointsNeeded,
        uint256 _rewardQuantity
    ) public onlyOwner {
        require(_rewardPrize > 0 && _rewardPointsNeeded > 0 && _rewardQuantity > 0, "Invalid reward parameters!");
        require(!rewardExists(_rewardName), "This reward already exists!");

        rewards[_rewardName] = Reward(_rewardName, _rewardPrize, _rewardPointsNeeded, _rewardQuantity);
        rewardNames.push(_rewardName);
    }
}
