// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.29;

// import "forge-std/Test.sol";
// import "../src/MigrationRelease.sol";
// import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
// import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract MigrationReleaseTest is Test {
//     MigrationRelease public implementation;
//     TransparentUpgradeableProxy public proxy;
//     MigrationRelease public release;
//     ProxyAdmin public proxyAdmin;
    
//     address public owner;
//     address public user1;
//     address public user2;
//     address public user3;
//     address public user4;
//     address public user5;
    
//     uint256 public constant CLAIM_AMOUNT_1 = 100 ether;
//     uint256 public constant CLAIM_AMOUNT_2 = 200 ether;
//     uint256 public constant CLAIM_AMOUNT_3 = 300 ether;
//     uint256 public constant CLAIM_AMOUNT_4 = 400 ether;
//     uint256 public constant CLAIM_AMOUNT_5 = 500 ether;
    
//     bytes32 public merkleRoot;
//     bytes32[] public merkleProofs;
    
//     // Import the events from MigrationRelease
//     event ReleasedInstant(address indexed recipient, uint indexed amount, uint indexed releaseTime);
//     event ReleasedVested(address indexed recipient, uint indexed amount, uint indexed releaseTime);
//     event FundsAdded(uint indexed amount, uint indexed timestamp);
//     event MerkleRootUpdated(bytes32 indexed oldMerkleRoot, bytes32 indexed newMerkleRoot);
    
//     // Helper function to simulate Merkle tree setup for testing
//     function setupMerkleTree() internal {
//         // In a real implementation, this would create an actual Merkle tree
//         // For testing, we'll create a simpler simulation
        
//         // Create leaves for each user
//         bytes32 leaf1 = keccak256(abi.encodePacked(user1, CLAIM_AMOUNT_1));
//         bytes32 leaf2 = keccak256(abi.encodePacked(user2, CLAIM_AMOUNT_2));
//         bytes32 leaf3 = keccak256(abi.encodePacked(user3, CLAIM_AMOUNT_3));
//         bytes32 leaf4 = keccak256(abi.encodePacked(user4, CLAIM_AMOUNT_4));
//         bytes32 leaf5 = keccak256(abi.encodePacked(user5, CLAIM_AMOUNT_5));
        
//         // For testing purposes, we'll use a fake merkle root and proofs
//         // In production, these would be generated properly using a Merkle tree library
//         merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2, leaf3, leaf4, leaf5));
        
//         // Mock the verification for our tests
//         vm.mockCall(
//             address(0), // This doesn't matter as we're mocking the static call
//             abi.encodeWithSelector(MerkleProof.verify.selector),
//             abi.encode(true)
//         );
        
//         // Create empty proofs (will be mocked in tests)
//         merkleProofs = new bytes32[](1);
//     }
    
//     // Function to access private instantClaimTime mapping
//     function getInstantClaimTime(MigrationRelease _release, bytes32 _leaf) internal view returns (uint256) {
//         bytes32 slot = keccak256(abi.encode(_leaf, uint256(41)));
//         uint256 value;
//         assembly {
//             value := sload(slot)
//         }
//         return value;
//     }
    
//     function mockMerkleVerification(address user, uint256 amount, bool result) internal {
//         bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        
//         // Mock the MerkleProof.verify call for this specific leaf
//         vm.mockCall(
//             address(0), // This doesn't matter as we're mocking the static call
//             abi.encodeWithSelector(
//                 MerkleProof.verify.selector,
//                 merkleProofs,
//                 merkleRoot,
//                 leaf
//             ),
//             abi.encode(result)
//         );
//     }
    
//     function setUp() public {
//         owner = address(this);
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         user3 = makeAddr("user3");
//         user4 = makeAddr("user4");
//         user5 = makeAddr("user5");
        
//         // Deploy the MigrationRelease contract implementation
//         implementation = new MigrationRelease();
        
//         // Deploy ProxyAdmin
//         proxyAdmin = new ProxyAdmin(owner);
        
//         // Initialize data for the proxy
//         bytes memory initData = abi.encodeWithSelector(
//             MigrationRelease.initialize.selector,
//             owner
//         );
        
//         // Deploy the TransparentUpgradeableProxy
//         proxy = new TransparentUpgradeableProxy(
//             address(implementation),
//             address(proxyAdmin),
//             initData
//         );
        
//         // Create a contract instance pointing to the proxy
//         release = MigrationRelease(address(proxy));
        
//         // Prepare Merkle tree (simulate it for testing)
//         setupMerkleTree();
        
//         // Set the merkle root
//         release.setMerkleRoot(merkleRoot);
        
//         // Add funds to the contract for releases
//         release.addFunds{value: 10000 ether}();
//     }
    
//     /*//////////////////////////////////////////////////////////////
//                              INITIALIZATION TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testInitialization() public {
//         assertEq(release.isClaimPaused(), false);
//         assertEq(release.owner(), owner);
//         assertEq(release.merkleRoot(), merkleRoot);
//         assertEq(address(release).balance, 10000 ether);
//     }
    
//     function testCannotInitializeWithZeroAddress() public {
//         MigrationRelease newImplementation = new MigrationRelease();
//         ProxyAdmin newProxyAdmin = new ProxyAdmin(owner);
        
//         bytes memory initData = abi.encodeWithSelector(
//             MigrationRelease.initialize.selector,
//             address(0)
//         );
        
//         vm.expectRevert(); // It will revert but with a different message than MigrationLocker
//         new TransparentUpgradeableProxy(
//             address(newImplementation),
//             address(newProxyAdmin),
//             initData
//         );
//     }
    
//     function testCannotReinitialize() public {
//         vm.expectRevert("Initializable: contract is already initialized");
//         release.initialize(address(this));
//     }

//     /*//////////////////////////////////////////////////////////////
//                              TOGGLE LOCK TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testToggleLock() public {
//         assertEq(release.isClaimPaused(), false);
        
//         release.setToggleLock();
//         assertEq(release.isClaimPaused(), true);
        
//         release.setToggleLock();
//         assertEq(release.isClaimPaused(), false);
//     }
    
//     function testOnlyOwnerCanToggleLock() public {
//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
//         release.setToggleLock();
//     }

//     /*//////////////////////////////////////////////////////////////
//                              MERKLE ROOT TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testSetMerkleRoot() public {
//         bytes32 oldRoot = release.merkleRoot();
//         bytes32 newRoot = keccak256("new root");
        
//         vm.expectEmit(true, true, false, true);
//         emit MerkleRootUpdated(oldRoot, newRoot);
//         release.setMerkleRoot(newRoot);
        
//         assertEq(release.merkleRoot(), newRoot);
//     }
    
//     function testCannotSetInvalidMerkleRoot() public {
//         // Test with zero address
//         vm.expectRevert("Invalid Merkle Root");
//         release.setMerkleRoot(bytes32(0));
        
//         // Test with same root
//         bytes32 currentRoot = release.merkleRoot();
//         vm.expectRevert("Invalid Merkle Root");
//         release.setMerkleRoot(currentRoot);
//     }
    
//     function testOnlyOwnerCanSetMerkleRoot() public {
//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
//         release.setMerkleRoot(keccak256("new root"));
//     }

//     /*//////////////////////////////////////////////////////////////
//                              ADD FUNDS TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testAddFunds() public {
//         uint256 initialBalance = address(release).balance;
//         uint256 addAmount = 5 ether;
        
//         vm.expectEmit(true, true, false, true);
//         emit FundsAdded(addAmount, block.timestamp);
//         release.addFunds{value: addAmount}();
        
//         assertEq(address(release).balance, initialBalance + addAmount);
//     }
    
//     function testCannotAddZeroFunds() public {
//         vm.expectRevert("No funds sent");
//         release.addFunds{value: 0}();
//     }
    
//     function testOnlyOwnerCanAddFunds() public {
//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
//         release.addFunds{value: 1 ether}();
//     }

//     /*//////////////////////////////////////////////////////////////
//                          RELEASE INSTANT TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testReleaseInstant() public {
//         // Mock the verification to return true for user1
//         bytes32 leaf = keccak256(abi.encodePacked(user1, CLAIM_AMOUNT_1));
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
        
//         uint256 userBalanceBefore = user1.balance;
//         uint256 expectedAmount = (CLAIM_AMOUNT_1 * release.INSTANT_RATIO()) / 10;
        
//         vm.expectEmit(true, true, true, true);
//         emit ReleasedInstant(user1, expectedAmount, block.timestamp);
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         uint256 userBalanceAfter = user1.balance;
//         assertEq(userBalanceAfter - userBalanceBefore, expectedAmount);
        
//         // Verify totalReleased was updated
//         assertEq(release.totalReleased(), expectedAmount);
        
//         // Verify claim was recorded (using storage access)
//         uint256 claimTime = getInstantClaimTime(release, leaf);
//         assertEq(claimTime, block.timestamp);
//     }
    
//     function testCannotReleaseInstantWithInvalidProof() public {
//         // Mock verification to return false
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, false);
        
//         vm.expectRevert("Not Whitelisted or already Claimed");
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
//     }
    
//     function testCannotReleaseInstantTwice() public {
//         // First release
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         // Try to release again
//         vm.expectRevert("Not Whitelisted or already Claimed");
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
//     }
    
//     function testCannotReleaseInstantWhenPaused() public {
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
        
//         // Pause the contract
//         release.setToggleLock();
        
//         vm.expectRevert("Contract is locked");
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
//     }
    
//     function testCannotReleaseInstantWithInsufficientContractBalance() public {
//         // Create a new release contract with low balance
//         MigrationRelease newImpl = new MigrationRelease();
//         bytes memory initData = abi.encodeWithSelector(
//             MigrationRelease.initialize.selector,
//             owner
//         );
//         TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(
//             address(newImpl),
//             address(proxyAdmin),
//             initData
//         );
//         MigrationRelease newRelease = MigrationRelease(address(newProxy));
        
//         // Set merkle root
//         newRelease.setMerkleRoot(merkleRoot);
        
//         // Add minimal funds
//         newRelease.addFunds{value: 0.1 ether}();
        
//         // Mock verification
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
        
//         // Attempt to claim more than contract balance
//         vm.expectRevert("Insufficient balance");
//         newRelease.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
//     }

//     /*//////////////////////////////////////////////////////////////
//                          RELEASE VESTED TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testReleaseVested() public {
//         // First release instant
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         // Fast forward past vesting period
//         vm.warp(block.timestamp + release.VESTING_PERIOD() + 1);
        
//         uint256 userBalanceBefore = user1.balance;
//         uint256 expectedAmount = (CLAIM_AMOUNT_1 * release.VESTING_RATIO()) / 10;
//         uint256 instantAmount = (CLAIM_AMOUNT_1 * release.INSTANT_RATIO()) / 10;
        
//         vm.expectEmit(true, true, true, true);
//         emit ReleasedVested(user1, expectedAmount, block.timestamp);
//         release.releaseVested(user1, CLAIM_AMOUNT_1);
        
//         uint256 userBalanceAfter = user1.balance;
//         assertEq(userBalanceAfter - userBalanceBefore, expectedAmount);
        
//         // Verify totalReleased was updated
//         assertEq(release.totalReleased(), instantAmount + expectedAmount);
//     }
    
//     function testCannotReleaseVestedBeforeInstant() public {
//         vm.expectRevert("Not Whitelisted or Not Vested");
//         release.releaseVested(user1, CLAIM_AMOUNT_1);
//     }
    
//     function testCannotReleaseVestedBeforeVestingPeriod() public {
//         // First release instant
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         // Try to release vested before vesting period
//         vm.expectRevert("Not Whitelisted or Not Vested");
//         release.releaseVested(user1, CLAIM_AMOUNT_1);
//     }
    
//     function testCannotReleaseVestedTwice() public {
//         // First release instant
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         // Fast forward past vesting period
//         vm.warp(block.timestamp + release.VESTING_PERIOD() + 1);
        
//         // First vested release
//         release.releaseVested(user1, CLAIM_AMOUNT_1);
        
//         // Try to release vested again
//         vm.expectRevert("Already Claimed");
//         release.releaseVested(user1, CLAIM_AMOUNT_1);
//     }
    
//     function testCannotReleaseVestedWhenPaused() public {
//         // First release instant
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
//         release.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         // Fast forward past vesting period
//         vm.warp(block.timestamp + release.VESTING_PERIOD() + 1);
        
//         // Pause the contract
//         release.setToggleLock();
        
//         vm.expectRevert("Contract is locked");
//         release.releaseVested(user1, CLAIM_AMOUNT_1);
//     }
    
//     function testCannotReleaseVestedWithInsufficientContractBalance() public {
//         // Set up a contract with just enough for instant but not vested
//         MigrationRelease newImpl = new MigrationRelease();
//         bytes memory initData = abi.encodeWithSelector(
//             MigrationRelease.initialize.selector,
//             owner
//         );
//         TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(
//             address(newImpl),
//             address(proxyAdmin),
//             initData
//         );
//         MigrationRelease newRelease = MigrationRelease(address(newProxy));
        
//         // Set merkle root
//         newRelease.setMerkleRoot(merkleRoot);
        
//         // Calculate instant amount and add just that much
//         uint256 instantAmount = (CLAIM_AMOUNT_1 * release.INSTANT_RATIO()) / 10;
//         newRelease.addFunds{value: instantAmount}();
        
//         // Release instant
//         mockMerkleVerification(user1, CLAIM_AMOUNT_1, true);
//         newRelease.releaseInstant(user1, CLAIM_AMOUNT_1, merkleProofs);
        
//         // Fast forward past vesting period
//         vm.warp(block.timestamp + newRelease.VESTING_PERIOD() + 1);
        
//         // Try to release vested with insufficient balance
//         vm.expectRevert("Insufficient balance");
//         newRelease.releaseVested(user1, CLAIM_AMOUNT_1);
//     }

//     /*//////////////////////////////////////////////////////////////
//                          RECOVER FUNDS TESTS
//     //////////////////////////////////////////////////////////////*/
    
//     function testRecoverNativeFunds() public {
//         uint256 recoveryAmount = 1 ether;
//         uint256 initialBalance = user1.balance;
        
//         release.recoverFunds(address(0), user1, recoveryAmount);
        
//         assertEq(user1.balance - initialBalance, recoveryAmount);
//     }
    
//     function testRecoverERC20Funds() public {
//         // Deploy a mock ERC20 token
//         ERC20Mock token = new ERC20Mock("Test Token", "TEST");
        
//         // Mint some tokens to the contract
//         token.mint(address(release), 100 ether);
        
//         uint256 recoveryAmount = 50 ether;
        
//         release.recoverFunds(address(token), user1, recoveryAmount);
        
//         assertEq(token.balanceOf(user1), recoveryAmount);
//     }
    
//     function testCannotRecoverZeroAmount() public {
//         vm.expectRevert("Invalid amount");
//         release.recoverFunds(address(0), user1, 0);
//     }
    
//     function testCannotRecoverToZeroAddress() public {
//         vm.expectRevert("Invalid recipient");
//         release.recoverFunds(address(0), address(0), 1 ether);
//     }
    
//     function testCannotRecoverMoreThanBalance() public {
//         uint256 balance = address(release).balance;
        
//         vm.expectRevert("Invalid amount");
//         release.recoverFunds(address(0), user1, balance + 1);
        
//         // Test for ERC20
//         ERC20Mock token = new ERC20Mock("Test Token", "TEST");
//         token.mint(address(release), 100 ether);
        
//         vm.expectRevert("Invalid amount");
//         release.recoverFunds(address(token), user1, 101 ether);
//     }
    
//     function testOnlyOwnerCanRecoverFunds() public {
//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
//         release.recoverFunds(address(0), user2, 1 ether);
//     }
// }

// // Helper contract for ERC20 token testing
// contract ERC20Mock is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
//     function mint(address to, uint256 amount) public {
//         _mint(to, amount);
//     }
// }

// error OwnableUnauthorizedAccount(address account); 