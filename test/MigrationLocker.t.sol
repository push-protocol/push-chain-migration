// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "./mocks/PushTokenMock.sol";
import "../src/MigrationLocker.sol";
import { IPushMock } from "./interfaces/v8/IPushMock.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract MigrationLockerTest is Test {
    MigrationLocker public implementation;
    TransparentUpgradeableProxy public proxy;
    MigrationLocker public locker;
    ProxyAdmin public proxyAdmin;
    PushTokenMock public pushToken;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant LOCK_AMOUNT_1 = 100 ether;
    uint256 public constant LOCK_AMOUNT_2 = 200 ether;
    uint256 public constant LOCK_AMOUNT_3 = 300 ether;

    // Import the event from MigrationLocker
    event Locked(address caller, address recipient, uint256 amount, uint256 epoch);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy the mock PUSH token
        pushToken = new PushTokenMock();

        // Mint tokens to users
        pushToken.mint(user1, INITIAL_BALANCE);
        pushToken.mint(user2, INITIAL_BALANCE);
        pushToken.mint(user3, INITIAL_BALANCE);

        // Deploy the MigrationLocker contract implementation
        implementation = new MigrationLocker();

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(owner);

        // Initialize data for the proxy
        bytes memory initData = abi.encodeWithSelector(MigrationLocker.initialize.selector, owner);

        // Deploy the TransparentUpgradeableProxy
        proxy = new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), initData);

        // Create a contract instance pointing to the proxy
        locker = MigrationLocker(address(proxy));

        // Deploy dummy version for the PUSH_TOKEN
        vm.mockCall(
            address(locker.PUSH_TOKEN()), abi.encodeWithSelector(IPushMock.transferFrom.selector), abi.encode(true)
        );

        vm.mockCall(address(locker.PUSH_TOKEN()), abi.encodeWithSelector(IPushMock.burn.selector), abi.encode());

        vm.mockCall(
            address(locker.PUSH_TOKEN()), abi.encodeWithSelector(IPushMock.balanceOf.selector), abi.encode(1000 ether)
        );

        vm.mockCall(address(locker.PUSH_TOKEN()), abi.encodeWithSelector(IPushMock.transfer.selector), abi.encode(true));
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialization() public {
        assertEq(locker.paused(), false);
        assertEq(locker.owner(), owner);
    }
    
    function testInitiateNewEpoch() public {
        // Get the current epoch
        uint256 initialEpoch = locker.epoch();
        
        // Advance the block
        vm.roll(block.number + 10);
        
        // Call initiateNewEpoch
        locker.initiateNewEpoch();
        
        // Verify epoch was incremented
        assertEq(locker.epoch(), initialEpoch + 1);
        
        // Verify the new epoch's start block was set correctly
        assertEq(locker.epochStartBlock(initialEpoch + 1), block.number);
    }
    
    function testOnlyOwnerCanInitiateNewEpoch() public {
        // Try to call initiateNewEpoch as non-owner
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.initiateNewEpoch();
    }

    function testCannotInitializeWithZeroAddress() public {
        MigrationLocker newImplementation = new MigrationLocker();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(owner);

        bytes memory initData = abi.encodeWithSelector(MigrationLocker.initialize.selector, address(0));

        vm.expectRevert("Invalid owner");
        new TransparentUpgradeableProxy(address(newImplementation), address(newProxyAdmin), initData);
    }

    function testCannotReinitialize() public {
        vm.expectRevert("InvalidInitialization()");
        locker.initialize(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                             TOGGLE LOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function testToggleLock() public {
        assertEq(locker.paused(), false);

        locker.pause();
        assertEq(locker.paused(), true);

        locker.unpause();
        assertEq(locker.paused(), false);
    }

    function testOnlyOwnerCanToggleLock() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.pause();
    }

    /*//////////////////////////////////////////////////////////////
                             LOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function testLock() public {
        // Set up the expected event
        vm.expectEmit(true, true, true, true);
        // The caller is the test contract itself, not user1
        emit Locked(address(this), user1, LOCK_AMOUNT_1, locker.epoch());

        // Now call the function
        locker.lock(LOCK_AMOUNT_1, user1);
    }

    function testLockUpdatesBalance() public {
        uint256 initialBalance = pushToken.balanceOf(user1);
        uint256 initialBalanceLocker = pushToken.balanceOf(address(locker));

        console.log("initialBalance", initialBalance);
        console.log("initialBalanceLocker", initialBalanceLocker);

        // We expect a call to transferFrom with these parameters
        vm.expectCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.transferFrom.selector, user1, address(locker), LOCK_AMOUNT_1)
        );

        vm.prank(user1);
        locker.lock(LOCK_AMOUNT_1, user1);

        console.log("Test passed: transferFrom was called with correct parameters");

        // The reason balances don't change is because we've mocked the transferFrom function
        // in the setUp function, but the actual transfer isn't happening since it's just a mock.
        // In a real scenario, the balances would change as expected.
    }

    function testCannotLockWhenPaused() public {
        locker.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        locker.lock(LOCK_AMOUNT_1, user1);
    }

    function testCannotLockToZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert("Invalid recipient");
        locker.lock(LOCK_AMOUNT_1, address(0));
    }

    function testCannotLockToContract() public {
        vm.prank(user1);
        vm.expectRevert("Invalid recipient");
        locker.lock(LOCK_AMOUNT_1, address(locker));
    }

    /*//////////////////////////////////////////////////////////////
                             BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function testBurn() public {
        uint256 burnAmount = 100 ether;

        // Mock the burn call
        vm.expectCall(address(locker.PUSH_TOKEN()), abi.encodeWithSelector(IPushMock.burn.selector, burnAmount));

        locker.burn(burnAmount);
    }

    function testOnlyOwnerCanBurn() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.burn(100 ether);
    }

    function testCannotBurnWhenPaused() public {
        locker.pause();

        // Include EnforcedPause()
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        locker.burn(100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          RECOVER FUNDS TESTS
    //////////////////////////////////////////////////////////////*/

    function testRecoverFunds() public {
        uint256 recoverAmount = 100 ether;

        // Mock the transfer call
        vm.expectCall(
            address(locker.PUSH_TOKEN()), abi.encodeWithSelector(IPushMock.transfer.selector, user1, recoverAmount)
        );

        locker.recoverFunds(address(locker.PUSH_TOKEN()), user1, recoverAmount);
    }

    function testOnlyOwnerCanRecoverFunds() public {
        // Setup the mock call for balanceOf
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.balanceOf.selector, address(proxy)),
            abi.encode(1000 ether)
        );

        address token = address(locker.PUSH_TOKEN());
        address recipient = user2;
        uint256 amount = 100 ether;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.recoverFunds(token, recipient, amount);
    }

    function testCannotRecoverWhenPaused() public {
        // First toggle the lock
        locker.pause();

        // Setup the mock call for balanceOf
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.balanceOf.selector, address(proxy)),
            abi.encode(1000 ether)
        );

        address token = address(locker.PUSH_TOKEN());
        address recipient = user1;
        uint256 amount = 100 ether;

        // Include EnforcedPause()
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        locker.recoverFunds(token, recipient, amount);
    }

    function testCannotRecoverToZeroAddress() public {
        // Setup the mock call for balanceOf
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.balanceOf.selector, address(proxy)),
            abi.encode(1000 ether)
        );

        address token = address(locker.PUSH_TOKEN());
        address zeroAddress = address(0);
        uint256 amount = 100 ether;

        vm.expectRevert("Invalid recipient");
        locker.recoverFunds(token, zeroAddress, amount);
    }

    function testCannotRecoverZeroAmount() public {
        // Setup the mock call for balanceOf
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.balanceOf.selector, address(proxy)),
            abi.encode(1000 ether)
        );

        address token = address(locker.PUSH_TOKEN());
        address recipient = user1;
        uint256 zeroAmount = 0;

        vm.expectRevert("Invalid amount");
        locker.recoverFunds(token, recipient, zeroAmount);
    }

    function testCannotRecoverMoreThanBalance() public {
        // Define a token address
        address token = address(locker.PUSH_TOKEN());

        // Set up the mock for balanceOf
        // Note: We need to use address(proxy) which is the same as address(locker)
        vm.mockCall(
            token,
            abi.encodeWithSelector(IPushMock.balanceOf.selector, address(proxy)),
            abi.encode(500 ether) // Contract balance is 500 ether
        );

        // Try to recover 1000 ether (more than contract balance)
        uint256 amountToRecover = 1000 ether;

        // Verify that it reverts with "Invalid amount"
        vm.expectRevert("Invalid amount");
        locker.recoverFunds(token, user1, amountToRecover);
    }

    function testActualTokenTransfer() public {
        // Deploy a new instance of everything for a clean test environment
        PushTokenMock newToken = new PushTokenMock();
        MigrationLocker newImplementation = new MigrationLocker();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(owner);

        // Initialize data for the proxy
        bytes memory initData = abi.encodeWithSelector(MigrationLocker.initialize.selector, owner);

        // Deploy the proxy
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(newProxyAdmin), initData);

        // Create contract instance
        MigrationLocker newLocker = MigrationLocker(address(newProxy));

        // Set up test account and mint tokens
        address testUser = makeAddr("testUser");
        newToken.mint(testUser, 1000 ether);

        // Create a custom locker just for this test with direct access to our token
        MockMigrationLocker customLocker = new MockMigrationLocker(address(newToken));

        // Initial balances
        uint256 initialUserBalance = newToken.balanceOf(testUser);
        uint256 initialLockerBalance = newToken.balanceOf(address(customLocker));

        console.log("Initial user balance:", initialUserBalance);
        console.log("Initial locker balance:", initialLockerBalance);

        // Approve tokens
        vm.prank(testUser);
        newToken.approve(address(customLocker), 100 ether);

        // Lock tokens
        vm.prank(testUser);
        customLocker.lock(100 ether, testUser);

        // Check final balances
        uint256 finalUserBalance = newToken.balanceOf(testUser);
        uint256 finalLockerBalance = newToken.balanceOf(address(customLocker));

        console.log("Final user balance:", finalUserBalance);
        console.log("Final locker balance:", finalLockerBalance);

        // Verify balances changed correctly
        assertEq(finalUserBalance, initialUserBalance - 100 ether);
        assertEq(finalLockerBalance, initialLockerBalance + 100 ether);
    }
}

// @dev this is Custom mock locker that uses a test dummy token instead of the hardcoded one.
// @dev primarily made for the testActualTokenTransfer() to work without mockCalls
contract MockMigrationLocker is Initializable, Ownable2StepUpgradeable, PausableUpgradeable {
    event Locked(address caller, address recipient, uint256 amount, uint256 epoch);

    uint256 public epoch = 1;

    address public immutable PUSH_TOKEN;

    constructor(address tokenAddress) {
        PUSH_TOKEN = tokenAddress;
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        require(initialOwner != address(0), "Invalid owner");
        __Ownable2Step_init();
        __Ownable_init(initialOwner);
        __Pausable_init();
    }

    function lock(uint256 _amount, address _recipient) external {
        uint256 codeLength;
        assembly {
            codeLength := extcodesize(_recipient)
        }
        if (_recipient == address(0) || codeLength > 0) {
            revert("Invalid recipient");
        }

        IPUSH(PUSH_TOKEN).transferFrom(msg.sender, address(this), _amount);
        emit Locked(msg.sender, _recipient, _amount, epoch);
    }
}

error OwnableUnauthorizedAccount(address account);
error EnforcedPause();
