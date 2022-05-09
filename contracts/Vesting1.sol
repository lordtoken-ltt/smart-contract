// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/IBEP20.sol";

contract Vesting1 is Ownable {

  // The token being vested
  IBEP20 public token;
  
  // Address where LTT tokens are located (with allowance to contract)
  address public immutable tokenWallet;

  // Vesting time
  uint256 public immutable startTime;
  uint256 public constant cliff = 365 days; //time before first release

  //Vesting release parameters are per thousand to avoid rounding errors and are assumed as not /1000
  uint public constant gradualReleasePercentage = 333;
  uint256 public constant gradualReleasePeriod = 365 days;
  uint public constant nVestingPhases = 3;

  // Total tokens for this vesting is 10% of the tokens cap
  uint256 public constant totalTokensVesting = 2000000000 * 0.1 * 10**9;
  uint256 public totalTokensDelivered = 0;
  uint256 public totalTokensToDeliver = 0;

  struct Allocation {
    uint256 amountBought;
    uint256 amountClaimed;
    uint256 phaseClaimed;
  }

  mapping (address => Allocation) public Allocations;
  uint public totalAllocations;

  /**
   * @dev Creates the first Vesting, from the selected start time and token. 
   * The wallet selected as tokenWallet should have enough funds to fulfill this vesting period.
   */
  constructor(IBEP20 _token, uint256 _startTime, address _tokenWallet, address _owner) {
    token = _token;
    startTime = _startTime;
    tokenWallet = _tokenWallet;
    _transferOwnership(_owner);
  }

  
  /**
   * @dev Calculate the amount to be given to a certain recipient. This function do not withdraw funds.
   */
  function getVestedAmount(address _recipient) public view returns(uint phasesVested, uint256 amountVested) {
    Allocation storage recipientAllocation = Allocations[_recipient];
    require(recipientAllocation.amountClaimed < recipientAllocation.amountBought, "Allocation fully claimed");
    uint256 endOfCliff = startTime + cliff;
    if (block.timestamp < endOfCliff) {
      return (0, 0);
    }

    uint currentVestingPhase = 1 + (block.timestamp - endOfCliff) / gradualReleasePeriod;

    if(currentVestingPhase >= nVestingPhases) {
      uint256 remainingAllocation = recipientAllocation.amountBought - recipientAllocation.amountClaimed;
      return (nVestingPhases, remainingAllocation);
    }

    phasesVested = currentVestingPhase - recipientAllocation.phaseClaimed;
    amountVested = (phasesVested * recipientAllocation.amountBought * gradualReleasePercentage / 1000);
  }

  /**
   * @dev Get allocation details from a given recipient.
   */
  function getAllocationDetails(address _recipient) external view returns(Allocation memory) {
    return Allocations[_recipient];
  }

  /**
   * @dev Add new users in the vesting. 
   * This contract need to have enough allowance in a wallet (preferably multisignature) to fullfill the previous + this amount vested. 
   */
  function addAllocation(address _recipient, uint256 _amount) external onlyOwner {
    _addAllocation(_recipient, _amount);
    totalAllocations += 1;
  }

  /**
   * @dev Batch function to add new users in the vesting. 
   * This contract need to have enough allowance in a wallet (preferably multisignature) to fullfill the previous + this amount vested. 
   */
  function addMultipleAllocations(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner {
    require(_recipients.length == _amounts.length, "Invalid input lengths");
    uint256 totalAmount = 0;
    for (uint i = 0; i < _recipients.length; i++) {
      totalAmount += _amounts[i];
      _addAllocation(_recipients[i], _amounts[i]);
    }
    totalAllocations += _recipients.length;
  }
  
  /**
   * @dev Release the vested tokens in the vesting to the caller according to the time period.
   */
  function releaseVestedTokens() external {
    _releaseVestedTokens(msg.sender);
  }

  /**
   * @dev Batch function to release the vested tokens in the vesting to the selected recipients according to the time period.
   */
  function batchReleaseVestedTokens(address[] calldata _recipients) external {
    for (uint i = 0; i < _recipients.length; i++) {
      _releaseVestedTokens(_recipients[i]);
    }
  }

  /**
   * @dev Transfer an allocation to a new address in case of wallet loss.
   */
  function transferAllocation(address _oldRecipient, address _newRecipient) external onlyOwner {
    _transferAllocation(_oldRecipient, _newRecipient);
    totalAllocations += 1;
  }

    /**
   * @dev Create a new allocation of the given amount to the selected recipient in this vesting.
   */
  function _addAllocation(address _recipient, uint256 _amount) internal {
    require(Allocations[_recipient].amountBought == 0, "Allocation for this recipient already exists");
    require(_amount >= nVestingPhases, "Amount too low (less than 1 token per vesting period)");
    require(totalTokensToDeliver + _amount <= totalTokensVesting, "This vesting period arrived to the total token capacity.");

    Allocation memory allocation = Allocation({
    amountBought: _amount,
    amountClaimed: 0,
    phaseClaimed: 0
    });
    Allocations[_recipient] = allocation;
    
    totalTokensToDeliver+=_amount;
  }

  /**
   * @dev Transfer an allocation to a new address in case of wallet loss.
   */
  function _transferAllocation(address _oldRecipient, address _newRecipient) internal {
    require(Allocations[_newRecipient].amountBought == 0, "Allocation for the new recipient already exists");
    require(Allocations[_oldRecipient].amountBought > Allocations[_oldRecipient].amountClaimed, "All tokens have already been claimed for this allocation.");
    Allocation memory allocation = Allocation({
    amountBought: Allocations[_oldRecipient].amountBought,
    amountClaimed: Allocations[_oldRecipient].amountClaimed,
    phaseClaimed: Allocations[_oldRecipient].phaseClaimed
    });
    Allocations[_newRecipient] = allocation;
    
    Allocations[_oldRecipient].amountClaimed = Allocations[_oldRecipient].amountBought;
    Allocations[_oldRecipient].phaseClaimed = nVestingPhases;
  }
  
  /**
   * @dev Release the vested delivery amount of tokens in this vesting period sending from allowance wallet to recipient.
   */
  function _releaseVestedTokens(address _recipient) internal {
    (uint phasesVested, uint256 amountVested) = getVestedAmount(_recipient);
    require(amountVested > 0, "Vested amount is 0");

    Allocation storage recipientAllocation = Allocations[_recipient];
    recipientAllocation.phaseClaimed = recipientAllocation.phaseClaimed + phasesVested;
    recipientAllocation.amountClaimed = recipientAllocation.amountClaimed + amountVested;

    _deliverTokens(_recipient, amountVested);
  }


  /**
   * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
   * @param _beneficiary Address performing the token purchase
   * @param _tokenAmount Number of tokens to be emitted
   */
  function _deliverTokens(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    require(_tokenAmount>0, "Amount of tokens to deliver is equal or lower than 0");
    totalTokensDelivered+=_tokenAmount;
    token.transferFrom(tokenWallet,_beneficiary, _tokenAmount);
  }
}
