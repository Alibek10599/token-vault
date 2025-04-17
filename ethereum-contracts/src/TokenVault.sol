// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TokenVault
 * @dev A vault contract for storing ERC20 tokens with role-based access control
 * @custom:security-contact security@tokenvault.example
 */
contract TokenVault is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // State variables
    IERC20 public token;
    uint256 public totalDeposited;
    uint256 public feePercentage; // Basis points (1/100 of a percent)
    uint256 public constant MAX_FEE = 500; // 5% max fee
    address public feeCollector;
    uint256 public withdrawalLimit;
    uint256 public withdrawalTimelock;
    
    // Security version tracking
    uint256 public version;
    
    // Withdrawal timelock mapping
    mapping(address => uint256) public lastWithdrawalTime;
    
    // DAO/Governance tracking
    mapping(address => bool) public isOperator;
    
    // Events
    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event WithdrawalLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event TimelockUpdated(uint256 oldTimelock, uint256 newTimelock);
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);
    event EmergencyWithdrawal(address indexed by, uint256 amount);
    
    /**
     * @dev Contract constructor
     * @param _token The ERC20 token this vault will manage
     * @param _feeCollector Address that collects fees
     * @param _initialFee Initial fee in basis points
     * @param _withdrawalLimit Initial withdrawal limit
     * @param _withdrawalTimelock Timelock between withdrawals in seconds
     */
    constructor(
        IERC20 _token,
        address _feeCollector,
        uint256 _initialFee,
        uint256 _withdrawalLimit,
        uint256 _withdrawalTimelock
    ) Ownable(msg.sender) {
        require(address(_token) != address(0), "Invalid token address");
        require(_feeCollector != address(0), "Invalid fee collector");
        require(_initialFee <= MAX_FEE, "Fee exceeds maximum");
        
        token = _token;
        feeCollector = _feeCollector;
        feePercentage = _initialFee;
        withdrawalLimit = _withdrawalLimit;
        withdrawalTimelock = _withdrawalTimelock;
        version = 1;
        
        // Set deployer as first operator
        isOperator[msg.sender] = true;
        emit OperatorAdded(msg.sender);
    }
    
    /**
     * @dev Deposit tokens into the vault
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens from user to vault
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update total deposited
        totalDeposited += amount;
        
        emit Deposited(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Withdraw tokens from the vault
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= withdrawalLimit, "Amount exceeds withdrawal limit");
        require(
            block.timestamp >= lastWithdrawalTime[msg.sender] + withdrawalTimelock,
            "Withdrawal too soon"
        );
        
        // Calculate fee
        uint256 fee = (amount * feePercentage) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        // Update state
        totalDeposited -= amount;
        lastWithdrawalTime[msg.sender] = block.timestamp;
        
        // Transfer fee to collector if fee exists
        if (fee > 0) {
            token.safeTransfer(feeCollector, fee);
        }
        
        // Transfer remaining amount to user
        token.safeTransfer(msg.sender, amountAfterFee);
        
        emit Withdrawn(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Emergency withdraw by owner
     * @param amount Amount to withdraw in emergency
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= token.balanceOf(address(this)), "Insufficient balance");
        
        // Update state
        totalDeposited -= amount;
        
        // Transfer to owner
        token.safeTransfer(owner(), amount);
        
        emit EmergencyWithdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Set new fee percentage
     * @param newFeePercentage New fee in basis points
     */
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= MAX_FEE, "Fee exceeds maximum");
        
        uint256 oldFee = feePercentage;
        feePercentage = newFeePercentage;
        version += 1;
        
        emit FeeUpdated(oldFee, newFeePercentage);
    }
    
    /**
     * @dev Set new fee collector
     * @param newFeeCollector Address of new fee collector
     */
    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Invalid fee collector");
        
        address oldCollector = feeCollector;
        feeCollector = newFeeCollector;
        version += 1;
        
        emit FeeCollectorUpdated(oldCollector, newFeeCollector);
    }
    
    /**
     * @dev Set new withdrawal limit
     * @param newLimit New withdrawal limit
     */
    function setWithdrawalLimit(uint256 newLimit) external onlyOwner {
        uint256 oldLimit = withdrawalLimit;
        withdrawalLimit = newLimit;
        version += 1;
        
        emit WithdrawalLimitUpdated(oldLimit, newLimit);
    }
    
    /**
     * @dev Set new withdrawal timelock
     * @param newTimelock New timelock in seconds
     */
    function setWithdrawalTimelock(uint256 newTimelock) external onlyOwner {
        uint256 oldTimelock = withdrawalTimelock;
        withdrawalTimelock = newTimelock;
        version += 1;
        
        emit TimelockUpdated(oldTimelock, newTimelock);
    }
    
    /**
     * @dev Add a new operator
     * @param operator Address to add as operator
     */
    function addOperator(address operator) external onlyOwner {
        require(operator != address(0), "Invalid operator address");
        require(!isOperator[operator], "Already an operator");
        
        isOperator[operator] = true;
        
        emit OperatorAdded(operator);
    }
    
    /**
     * @dev Remove an operator
     * @param operator Address to remove from operators
     */
    function removeOperator(address operator) external onlyOwner {
        require(isOperator[operator], "Not an operator");
        require(operator != owner(), "Cannot remove owner as operator");
        
        isOperator[operator] = false;
        
        emit OperatorRemoved(operator);
    }
    
    /**
     * @dev Pause the contract for emergency
     * Only operators can pause
     */
    function pause() external {
        require(isOperator[msg.sender], "Not an operator");
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     * Only owner can unpause (higher safety level)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get vault balance
     * @return Current balance of tokens in vault
     */
    function getVaultBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    /**
     * @dev Checks if user can withdraw now
     * @param user Address to check
     * @return boolean indicating if user can withdraw
     */
    function canWithdrawNow(address user) external view returns (bool) {
        return block.timestamp >= lastWithdrawalTime[user] + withdrawalTimelock;
    }
    
    /**
     * @dev Time remaining until user can withdraw
     * @param user Address to check
     * @return Time remaining in seconds, 0 if can withdraw
     */
    function timeUntilWithdrawal(address user) external view returns (uint256) {
        uint256 nextWithdrawalTime = lastWithdrawalTime[user] + withdrawalTimelock;
        
        if (block.timestamp >= nextWithdrawalTime) {
            return 0;
        }
        
        return nextWithdrawalTime - block.timestamp;
    }
}
