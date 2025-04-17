// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenVault.sol";
import "../src/MockToken.sol";

contract TokenVaultTest is Test {
    TokenVault public vault;
    MockToken public mockToken;
    
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public feeCollector = address(4);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 million tokens
    uint256 public constant INITIAL_FEE = 100; // 1%
    uint256 public constant INITIAL_WITHDRAWAL_LIMIT = 10000 * 10**18; // 10k tokens
    uint256 public constant INITIAL_TIMELOCK = 1 days; // 1 day
    
    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    
    function setUp() public {
        // Setup testing environment
        vm.startPrank(owner);
        
        // Deploy mock token
        mockToken = new MockToken("Mock Token", "MTK");
        
        // Mint tokens to users
        mockToken.mint(owner, INITIAL_SUPPLY);
        mockToken.mint(user1, INITIAL_SUPPLY);
        mockToken.mint(user2, INITIAL_SUPPLY);
        
        // Deploy vault
        vault = new TokenVault(
            mockToken,
            feeCollector,
            INITIAL_FEE,
            INITIAL_WITHDRAWAL_LIMIT,
            INITIAL_TIMELOCK
        );
        
        vm.stopPrank();
    }
    
    function testInitialState() public view {
        assertEq(address(vault.token()), address(mockToken));
        assertEq(vault.feeCollector(), feeCollector);
        assertEq(vault.feePercentage(), INITIAL_FEE);
        assertEq(vault.withdrawalLimit(), INITIAL_WITHDRAWAL_LIMIT);
        assertEq(vault.withdrawalTimelock(), INITIAL_TIMELOCK);
        assertEq(vault.totalDeposited(), 0);
        assertEq(vault.version(), 1);
        
        // Owner should be an operator
        assertTrue(vault.isOperator(owner));
    }
    
    function testDeposit() public {
        uint256 depositAmount = 1000 * 10**18;
        
        vm.startPrank(user1);
        
        // Approve tokens
        mockToken.approve(address(vault), depositAmount);
        
        // Expect Deposited event
        vm.expectEmit(true, false, false, true);
        emit Deposited(user1, depositAmount, block.timestamp);
        
        // Deposit
        vault.deposit(depositAmount);
        
        // Check state after deposit
        assertEq(vault.totalDeposited(), depositAmount);
        assertEq(mockToken.balanceOf(address(vault)), depositAmount);
        assertEq(mockToken.balanceOf(user1), INITIAL_SUPPLY - depositAmount);
        
        vm.stopPrank();
    }
    
    function testWithdraw() public {
        uint256 depositAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        
        // First deposit tokens
        vm.startPrank(user1);
        mockToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        // Advance time past timelock
        vm.warp(block.timestamp + INITIAL_TIMELOCK + 1);
        
        // Now withdraw
        vm.startPrank(user1);
        
        // Calculate expected fee
        uint256 expectedFee = (withdrawAmount * INITIAL_FEE) / 10000;
        uint256 expectedAmountAfterFee = withdrawAmount - expectedFee;
        
        // Expect Withdrawn event
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user1, withdrawAmount, block.timestamp);
        
        // Withdraw
        vault.withdraw(withdrawAmount);
        
        // Check state after withdrawal
        assertEq(vault.totalDeposited(), depositAmount - withdrawAmount);
        assertEq(mockToken.balanceOf(address(vault)), depositAmount - withdrawAmount);
        assertEq(mockToken.balanceOf(user1), INITIAL_SUPPLY - depositAmount + expectedAmountAfterFee);
        assertEq(mockToken.balanceOf(feeCollector), expectedFee);
        assertEq(vault.lastWithdrawalTime(user1), block.timestamp);
        
        vm.stopPrank();
    }
    
    function testCannotWithdrawBeforeTimelock() public {
        uint256 depositAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        
        // First deposit tokens
        vm.startPrank(user1);
        mockToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        // Try to withdraw immediately (before timelock expires)
        vm.expectRevert("Withdrawal too soon");
        vault.withdraw(withdrawAmount);
        
        vm.stopPrank();
    }
    
    function testCannotWithdrawOverLimit() public {
        uint256 depositAmount = 100000 * 10**18; // Large deposit
        uint256 withdrawAmount = INITIAL_WITHDRAWAL_LIMIT + 1; // Over limit
        
        // First deposit tokens
        vm.startPrank(user1);
        mockToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        // Advance time past timelock
        vm.warp(block.timestamp + INITIAL_TIMELOCK + 1);
        
        // Try to withdraw over limit
        vm.expectRevert("Amount exceeds withdrawal limit");
        vault.withdraw(withdrawAmount);
        
        vm.stopPrank();
    }
    
    function testUpdateFeePercentage() public {
        uint256 newFee = 200; // 2%
        
        vm.startPrank(owner);
        
        // Expect FeeUpdated event
        vm.expectEmit(false, false, false, true);
        emit FeeUpdated(INITIAL_FEE, newFee);
        
        // Update fee
        vault.setFeePercentage(newFee);
        
        // Check state after update
        assertEq(vault.feePercentage(), newFee);
        assertEq(vault.version(), 2); // Version should increment
        
        vm.stopPrank();
    }
    
    function testCannotSetFeeAboveMax() public {
        uint256 tooHighFee = vault.MAX_FEE() + 1;
        
        vm.startPrank(owner);
        
        // Try to set fee too high
        vm.expectRevert("Fee exceeds maximum");
        vault.setFeePercentage(tooHighFee);
        
        vm.stopPrank();
    }
    
    function testUpdateFeeCollector() public {
        address newCollector = address(5);
        
        vm.startPrank(owner);
        
        // Expect FeeCollectorUpdated event
        vm.expectEmit(false, false, false, true);
        emit FeeCollectorUpdated(feeCollector, newCollector);
        
        // Update fee collector
        vault.setFeeCollector(newCollector);
        
        // Check state after update
        assertEq(vault.feeCollector(), newCollector);
        assertEq(vault.version(), 2); // Version should increment
        
        vm.stopPrank();
    }
    
    function testCannotSetZeroAddressAsFeeCollector() public {
        vm.startPrank(owner);
        
        // Try to set zero address
        vm.expectRevert("Invalid fee collector");
        vault.setFeeCollector(address(0));
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdraw() public {
        uint256 depositAmount = 1000 * 10**18;
        
        // First deposit tokens from user
        vm.startPrank(user1);
        mockToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        // Emergency withdraw as owner
        vm.startPrank(owner);
        vault.emergencyWithdraw(depositAmount);
        vm.stopPrank();
        
        // Check state after emergency withdrawal
        assertEq(vault.totalDeposited(), 0);
        assertEq(mockToken.balanceOf(address(vault)), 0);
        assertEq(mockToken.balanceOf(owner), INITIAL_SUPPLY + depositAmount);
    }
    
    function testPauseAndUnpause() public {
        // Pause as operator (owner)
        vm.startPrank(owner);
        vault.pause();
        
        // Verify it's paused
        assertTrue(vault.paused());
        
        // Try to deposit while paused - use bytes4 selector instead of string
        vm.startPrank(user1);
        mockToken.approve(address(vault), 100 * 10**18);
        bytes memory encodedError = abi.encodeWithSignature("EnforcedPause()");
        vm.expectRevert(encodedError);
        vault.deposit(100 * 10**18);
        vm.stopPrank();
        
        // Unpause as owner
        vm.startPrank(owner);
        vault.unpause();
        assertFalse(vault.paused());
        vm.stopPrank();
        
        // Now deposit should work
        vm.startPrank(user1);
        vault.deposit(100 * 10**18);
        vm.stopPrank();
    }
    
    function testTimeUntilWithdrawal() public {
        uint256 depositAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        
        // First deposit tokens
        vm.startPrank(user1);
        mockToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        // Withdraw
        vm.warp(block.timestamp + INITIAL_TIMELOCK + 1);
        vault.withdraw(withdrawAmount);
        
        // Check time until next withdrawal
        assertEq(vault.timeUntilWithdrawal(user1), INITIAL_TIMELOCK);
        
        // Advance time halfway
        vm.warp(block.timestamp + INITIAL_TIMELOCK / 2);
        assertEq(vault.timeUntilWithdrawal(user1), INITIAL_TIMELOCK / 2);
        
        // Advance time fully
        vm.warp(block.timestamp + INITIAL_TIMELOCK / 2 + 1);
        assertEq(vault.timeUntilWithdrawal(user1), 0);
        assertTrue(vault.canWithdrawNow(user1));
        
        vm.stopPrank();
    }
    
    function testOperatorManagement() public {
        address newOperator = address(10);
        
        vm.startPrank(owner);
        
        // Add new operator
        vault.addOperator(newOperator);
        assertTrue(vault.isOperator(newOperator));
        
        // Remove operator
        vault.removeOperator(newOperator);
        assertFalse(vault.isOperator(newOperator));
        
        // Cannot remove owner as operator
        vm.expectRevert("Cannot remove owner as operator");
        vault.removeOperator(owner);
        
        vm.stopPrank();
    }
    
    function testOnlyOperatorCanPause() public {
        address nonOperator = address(20);
        
        // Try to pause as non-operator
        vm.startPrank(nonOperator);
        vm.expectRevert("Not an operator");
        vault.pause();
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanUnpause() public {
        address operator = address(30);
        
        // Add new operator
        vm.startPrank(owner);
        vault.addOperator(operator);
        vault.pause();
        vm.stopPrank();
        
        // Try to unpause as non-owner operator
        vm.startPrank(operator);
        // OpenZeppelin v5 has a different error message format
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", operator));
        vault.unpause();
        vm.stopPrank();
        
        // Unpause as owner should work
        vm.prank(owner);
        vault.unpause();
        assertFalse(vault.paused());
    }
    
    function testFuzzDeposit(uint256 amount) public {
        // Bound amount to realistic values
        amount = bound(amount, 1, INITIAL_SUPPLY);
        
        vm.startPrank(user1);
        mockToken.approve(address(vault), amount);
        vault.deposit(amount);
        
        assertEq(vault.totalDeposited(), amount);
        assertEq(mockToken.balanceOf(address(vault)), amount);
        vm.stopPrank();
    }
    
    function testFuzzWithdrawAfterDeposit(uint256 depositAmount, uint256 withdrawAmount) public {
        // Bound amounts to realistic values
        depositAmount = bound(depositAmount, 1, INITIAL_SUPPLY);
        withdrawAmount = bound(withdrawAmount, 1, INITIAL_WITHDRAWAL_LIMIT);
        
        // Ensure withdraw amount doesn't exceed deposit
        if (withdrawAmount > depositAmount) {
            withdrawAmount = depositAmount;
        }
        
        vm.startPrank(user1);
        
        // Deposit
        mockToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        // Advance time past timelock
        vm.warp(block.timestamp + INITIAL_TIMELOCK + 1);
        
        // Calculate fee
        uint256 expectedFee = (withdrawAmount * INITIAL_FEE) / 10000;
        
        // Withdraw
        vault.withdraw(withdrawAmount);
        
        // Verify balances
        assertEq(vault.totalDeposited(), depositAmount - withdrawAmount);
        assertEq(mockToken.balanceOf(feeCollector), expectedFee);
        
        vm.stopPrank();
    }
}
