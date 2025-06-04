// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "./mocks/PushTokenMock.sol";
import "../src/MigrationLocker.sol";
import {IPushMock} from "./interfaces/v8/IPushMock.sol";
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
    event Locked(address recipient, uint amount);

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
        bytes memory initData = abi.encodeWithSelector(
            MigrationLocker.initialize.selector,
            owner
        );
        
        // Deploy the TransparentUpgradeableProxy
        proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        // Create a contract instance pointing to the proxy
        locker = MigrationLocker(address(proxy));
        
        // Deploy dummy version for the PUSH_TOKEN 
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.transferFrom.selector),
            abi.encode(true)
        );
        
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.burn.selector),
            abi.encode()
        );
        
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.balanceOf.selector),
            abi.encode(1000 ether)
        );
        
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.transfer.selector),
            abi.encode(true)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testInitialization() public {
        assertEq(locker.isMigrationPause(), false);
        assertEq(locker.owner(), owner);
    }
    
    function testCannotInitializeWithZeroAddress() public {
        MigrationLocker newImplementation = new MigrationLocker();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(owner);
        
        bytes memory initData = abi.encodeWithSelector(
            MigrationLocker.initialize.selector,
            address(0)
        );
        
        vm.expectRevert("Invalid owner");
        new TransparentUpgradeableProxy(
            address(newImplementation),
            address(newProxyAdmin),
            initData
        );
    }
    
    function testCannotReinitialize() public {
        vm.expectRevert("InvalidInitialization()");
        locker.initialize(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                             TOGGLE LOCK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testToggleLock() public {
        assertEq(locker.isMigrationPause(), false);
        
        locker.setToggleLock();
        assertEq(locker.isMigrationPause(), true);
        
        locker.setToggleLock();
        assertEq(locker.isMigrationPause(), false);
    }
    
    function testOnlyOwnerCanToggleLock() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.setToggleLock();
    }

    /*//////////////////////////////////////////////////////////////
                             LOCK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testLock() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Locked(user1, LOCK_AMOUNT_1);
        locker.lock(LOCK_AMOUNT_1, user1);
    }
    
    function testCannotLockWhenPaused() public {
        locker.setToggleLock();
        
        vm.prank(user1);
        vm.expectRevert("Contract is locked");
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
        vm.expectCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.burn.selector, burnAmount)
        );
        
        locker.burn(burnAmount);
    }
    
    function testOnlyOwnerCanBurn() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.burn(100 ether);
    }
    
    function testCannotBurnWhenPaused() public {
        locker.setToggleLock();
        
        vm.expectRevert("Contract is locked");
        locker.burn(100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          RECOVER FUNDS TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testRecoverFunds() public {
        uint256 recoverAmount = 100 ether;
        
        // Mock the transfer call
        vm.expectCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.transfer.selector, user1, recoverAmount)
        );
        
        locker.recoverFunds(address(locker.PUSH_TOKEN()), user1, recoverAmount);
    }
    
    function testOnlyOwnerCanRecoverFunds() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        locker.recoverFunds(address(locker.PUSH_TOKEN()), user1, 100 ether);
    }
    
    function testCannotRecoverWhenPaused() public {
        locker.setToggleLock();
        
        vm.expectRevert("Contract is locked");
        locker.recoverFunds(address(locker.PUSH_TOKEN()), user1, 100 ether);
    }
    
    function testCannotRecoverToZeroAddress() public {
        vm.expectRevert("Invalid recipient");
        locker.recoverFunds(address(locker.PUSH_TOKEN()), address(0), 100 ether);
    }
    
    function testCannotRecoverZeroAmount() public {
        vm.expectRevert("Invalid amount");
        locker.recoverFunds(address(locker.PUSH_TOKEN()), user1, 0);
    }
    
    function testCannotRecoverMoreThanBalance() public {
        // Mock balance of contract to be 500 ether
        vm.mockCall(
            address(locker.PUSH_TOKEN()),
            abi.encodeWithSelector(IPushMock.balanceOf.selector, address(locker)),
            abi.encode(500 ether)
        );
        
        vm.expectRevert("Invalid amount");
        locker.recoverFunds(address(locker.PUSH_TOKEN()), user1, 1000 ether);
    }
}

error OwnableUnauthorizedAccount(address account); 