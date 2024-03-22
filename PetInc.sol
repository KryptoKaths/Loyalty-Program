pragma solidity ^0.8.2;

contract PetInc {
   // State Variables
   uint256 internal constant INITIAL_STARS = 100;
   bool internal locked; // to support reEntrancy guard
   address internal owner;    
   address[] internal customerAddresses;
   string[] internal rewardNames; 

   struct Reward {
           string rewardName; 
           uint256 rewardPrize;
           uint256 starsNeeded;           
           uint256 qty;       
   }
   mapping(address => uint256) internal petStars;
   mapping(string => Reward) internal rewards;

   // Events
   event AccountCreated(address indexed account);
   event StarsEarned(address indexed account, uint256 starsEarned);
   event StarsRedeemed(address indexed account, uint256 starsRedeemed, string rewardName);

   // Functional Modifiers
   modifier onlyOwner() {
       require(msg.sender == owner, "Only contract owner can perform this action.");
       _;
   }
  
   modifier onlyCustomer() {
       require(customerExist(msg.sender), "You have not registered as a customer.");
       _;
   }
  
   modifier onlynewCustomer() {
       require(!customerExist(msg.sender), "You are already a customer.");
       _;
   }

   modifier reEntrancyGuard() {
       require(!locked, "This smart contract is locked at the moment.");
       locked = true; 
       _;
       locked = false; 
   }

   // Helper Functions
   function customerExist (address _custAddr) internal view returns (bool) { 
       for (uint256 i = 0; i < customerAddresses.length; i++) { 
           address currAddr = customerAddresses[i];
           if (currAddr == _custAddr) {
               return true;
           }
       }
       return false;
   }
  
   function rewardExist (string memory _rewardName) internal view returns (bool) {
       for (uint256 i = 0; i < rewardNames.length; i++) {
           string memory currRewardName = rewardNames[i];
           if (stringsEqual(currRewardName, _rewardName)) {
               return true;
           }
       }
       return false;
   }
  
   function stringsEqual (string memory _strA, string memory _strB) internal pure returns (bool) {
       return keccak256(abi.encodePacked(_strA)) == keccak256(abi.encodePacked(_strB));
   }

   constructor() payable { //must be payable
       owner = msg.sender;
       locked = false;
   }
  
   receive() external payable {}

   function topUp() external payable onlyOwner {}
  
   // Functions
   function createAccount() public onlynewCustomer {
       address newCustAddr = msg.sender;
       customerAddresses.push(newCustAddr);
       petStars[msg.sender] = INITIAL_STARS;
       emit AccountCreated(newCustAddr);
   }

   function getStarsBalance() public view onlyCustomer returns (uint256) {
       return petStars[msg.sender];
   }

   function earnStars(uint256 _stars) public onlyCustomer {
       uint256 currStars = petStars[msg.sender]; 
       uint256 newStars = currStars + _stars; 
       petStars[msg.sender] = newStars;
     
       emit StarsEarned(msg.sender, _stars);
   }

   function redeemStars(string memory _rewardName) public onlyCustomer reEntrancyGuard { 
       require(rewardExist(_rewardName), "This reward does not exist.");
       Reward memory currReward = rewards[_rewardName]; // use memory if data can be discarded after function ends
       uint256 costOfReward = currReward.starsNeeded;
       uint256 custCurrStars = petStars[msg.sender];
       require(custCurrStars >= costOfReward, "You do not have enough stars for this reward.");
      
       uint256 custBalStars = custCurrStars - costOfReward;
       petStars[msg.sender] = custBalStars;

       currReward.qty -= 1;
       rewards[_rewardName] = currReward;

       (bool success, ) = payable(msg.sender).call{value: currReward.rewardPrize}("");
       require(success, "Transfer Failed");
       emit StarsRedeemed(msg.sender, costOfReward, _rewardName);
   }

   function addReward(
       string memory _rewardName,
       uint256 _rewardCost,
       uint256 _rewardPrize,
       uint256 _rewardQty
   ) public onlyOwner {
       require(_rewardCost > 0, "Reward cost must be more than zero.");
       require(_rewardPrize > 0, "Reward prize must be more than zero.");
       require(_rewardQty > 0, "Reward qty must be more than zero.");
       require(!rewardExist(_rewardName), "This reward name already exists.");
       rewardNames.push(_rewardName);
       rewards[_rewardName] = Reward(_rewardName, _rewardCost, _rewardPrize, _rewardQty);
   }
}
