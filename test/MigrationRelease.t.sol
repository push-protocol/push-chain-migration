// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "../src/MigrationRelease.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MigrationReleaseTest is Test {
    MigrationRelease public implementation;
    TransparentUpgradeableProxy public proxy;
    MigrationRelease public release;
    ProxyAdmin public proxyAdmin;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;

    uint256 public constant CLAIM_AMOUNT_1 = 100 ether;
    uint256 public constant CLAIM_AMOUNT_2 = 200 ether;
    uint256 public constant CLAIM_AMOUNT_3 = 300 ether;
    uint256 public constant CLAIM_AMOUNT_4 = 400 ether;
    uint256 public constant CLAIM_AMOUNT_5 = 500 ether;

    uint256 public constant EPOCH = 1;

    bytes32 public merkleRoot;

    // Mapping from user address to their Merkle proof
    mapping(address => bytes32[]) public userMerkleProofs;

    // Import the events from MigrationRelease
    event ReleasedInstant(address indexed recipient, uint256 indexed amount, uint256 indexed releaseTime);
    event ReleasedVested(address indexed recipient, uint256 indexed amount, uint256 indexed releaseTime);
    event FundsAdded(uint256 indexed amount, uint256 indexed timestamp);
    event MerkleRootUpdated(bytes32 indexed oldMerkleRoot, bytes32 indexed newMerkleRoot);

    // Function to create a leaf from user address and claim amount
    function createLeaf(address user, uint256 amount) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amount));
    }

    // Function to create a leaf from user address, claim amount, and epoch
    function createLeaf(address user, uint256 amount, uint256 epoch) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amount, epoch));
    }

    // Simple method to create a basic Merkle tree with just 2 leaves for simplicity
    function setupMerkleTree() internal {
        // We'll create a much simpler tree with just 2 users for testing
        bytes32[] memory leaves = new bytes32[](2);

        // Use the EPOCH constant for all test cases

        // Create leaves for each user
        leaves[0] = createLeaf(user1, CLAIM_AMOUNT_1, EPOCH);
        leaves[1] = createLeaf(user2, CLAIM_AMOUNT_2, EPOCH);

        // Sort leaves to ensure consistent ordering (not strictly necessary for 2 leaves,
        // but a good practice for Merkle trees)
        if (uint256(leaves[0]) > uint256(leaves[1])) {
            bytes32 temp = leaves[0];
            leaves[0] = leaves[1];
            leaves[1] = temp;
        }

        // Compute the root - with 2 leaves it's just the hash of both leaves
        merkleRoot = keccak256(abi.encodePacked(leaves[0], leaves[1]));

        // Create proofs for each user
        // For a 2-leaf tree, the proof for one leaf is just the other leaf

        // Check which leaf corresponds to which user after sorting
        bytes32 leaf1 = createLeaf(user1, CLAIM_AMOUNT_1, EPOCH);
        bytes32 leaf2 = createLeaf(user2, CLAIM_AMOUNT_2, EPOCH);

        // Create proofs
        userMerkleProofs[user1] = new bytes32[](1);
        userMerkleProofs[user2] = new bytes32[](1);

        if (leaves[0] == leaf1) {
            // user1's leaf is first, so user1's proof is leaves[1]
            userMerkleProofs[user1][0] = leaves[1];
            userMerkleProofs[user2][0] = leaves[0];
        } else {
            // user2's leaf is first, so user2's proof is leaves[1]
            userMerkleProofs[user1][0] = leaves[0];
            userMerkleProofs[user2][0] = leaves[1];
        }

        // Add dummy proofs for other users (they won't pass verification)
        userMerkleProofs[user3] = new bytes32[](1);
        userMerkleProofs[user3][0] = bytes32(0);

        userMerkleProofs[user4] = new bytes32[](1);
        userMerkleProofs[user4][0] = bytes32(0);

        userMerkleProofs[user5] = new bytes32[](1);
        userMerkleProofs[user5][0] = bytes32(0);

        // Verify the proofs are valid
        bool isUser1Valid = MerkleProof.verify(userMerkleProofs[user1], merkleRoot, leaf1);
        bool isUser2Valid = MerkleProof.verify(userMerkleProofs[user2], merkleRoot, leaf2);

        // Ensure our Merkle tree implementation is correct
        require(isUser1Valid && isUser2Valid, "Merkle proof verification failed in setup");
    }

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");

        // Deploy the MigrationRelease contract implementation
        implementation = new MigrationRelease();

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(owner);

        // Initialize data for the proxy
        bytes memory initData = abi.encodeWithSelector(MigrationRelease.initialize.selector, owner);

        // Deploy the TransparentUpgradeableProxy
        proxy = new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), initData);

        // Create a contract instance pointing to the proxy
        release = MigrationRelease(address(proxy));

        // Prepare Merkle tree (generate a real tree for testing)
        setupMerkleTree();

        // Set the merkle root
        release.setMerkleRoot(merkleRoot);

        // Add funds to the contract for releases
        release.addFunds{ value: 10_000 ether }();
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialization() public {
        assertEq(release.isClaimPaused(), false);
        assertEq(release.owner(), owner);
        assertEq(release.merkleRoot(), merkleRoot);
        assertEq(address(release).balance, 10_000 ether);
    }

    function testCannotInitializeWithZeroAddress() public {
        MigrationRelease newImplementation = new MigrationRelease();
        ProxyAdmin newProxyAdmin = new ProxyAdmin(owner);

        bytes memory initData = abi.encodeWithSelector(MigrationRelease.initialize.selector, address(0));

        vm.expectRevert(); // It will revert but with a different message than MigrationLocker
        new TransparentUpgradeableProxy(address(newImplementation), address(newProxyAdmin), initData);
    }

    function testCannotReinitialize() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidInitialization.selector));
        release.initialize(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                             PAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    function testPauseability() public {
        assertEq(release.paused(), false);

        release.pause();
        assertEq(release.paused(), true);

        release.unpause();
        assertEq(release.paused(), false);
    }

    function testOnlyOwnerCanToggleLock() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        release.pause();
    }

    /*//////////////////////////////////////////////////////////////
                             MERKLE ROOT TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetMerkleRoot() public {
        bytes32 oldRoot = release.merkleRoot();
        bytes32 newRoot = keccak256("new root");

        vm.expectEmit(true, true, false, true);
        emit MerkleRootUpdated(oldRoot, newRoot);
        release.setMerkleRoot(newRoot);

        assertEq(release.merkleRoot(), newRoot);
    }

    function testCannotSetInvalidMerkleRoot() public {
        // Test with zero address
        vm.expectRevert("Invalid Merkle Root");
        release.setMerkleRoot(bytes32(0));

        // Test with same root
        bytes32 currentRoot = release.merkleRoot();
        vm.expectRevert("Invalid Merkle Root");
        release.setMerkleRoot(currentRoot);
    }

    function testOnlyOwnerCanSetMerkleRoot() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        release.setMerkleRoot(keccak256("new root"));
    }

    /*//////////////////////////////////////////////////////////////
                             ADD FUNDS TESTS
    //////////////////////////////////////////////////////////////*/

    function testAddFunds() public {
        uint256 initialBalance = address(release).balance;
        uint256 addAmount = 5 ether;

        vm.expectEmit(true, true, false, true);
        emit FundsAdded(addAmount, block.timestamp);
        release.addFunds{ value: addAmount }();

        assertEq(address(release).balance, initialBalance + addAmount);
    }

    function testCannotAddZeroFunds() public {
        vm.expectRevert("No funds sent");
        release.addFunds{ value: 0 }();
    }

    function testOnlyOwnerCanAddFunds() public {
        // Fund the user1 account so they have ETH to send
        vm.deal(user1, 10 ether);

        // Try to add funds as non-owner
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        release.addFunds{ value: 1 ether }();
    }

    /*//////////////////////////////////////////////////////////////
                         RELEASE INSTANT TESTS
    //////////////////////////////////////////////////////////////*/

    function testReleaseInstant() public {
        // Get the proof for user1
        bytes32[] memory proof = userMerkleProofs[user1];

        // Check the initial balance
        uint256 userBalanceBefore = user1.balance;
        uint256 expectedAmount = (CLAIM_AMOUNT_1 * release.INSTANT_RATIO()) / 10;

        // Expected event
        vm.expectEmit(true, true, true, true);
        emit ReleasedInstant(user1, expectedAmount, block.timestamp);

        // Call the function with the real proof
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Verify the user received the expected amount
        uint256 userBalanceAfter = user1.balance;
        assertEq(userBalanceAfter - userBalanceBefore, expectedAmount);

        // Verify totalReleased was updated
        assertEq(release.totalReleased(), expectedAmount);

        // Verify claim was recorded in the instantClaimTime mapping
        bytes32 leaf = createLeaf(user1, CLAIM_AMOUNT_1, EPOCH);
        assertEq(release.instantClaimTime(leaf), block.timestamp);
    }

    function testCannotReleaseInstantWithInvalidProof() public {
        // Create an invalid proof by using user3's proof (which is invalid)
        bytes32[] memory invalidProof = userMerkleProofs[user3];

        vm.expectRevert("Not Whitelisted or already Claimed");
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, invalidProof);
    }

    function testCannotReleaseInstantTwice() public {
        // First release
        bytes32[] memory proof = userMerkleProofs[user1];
        vm.prank(user1);
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Try to release again
        vm.expectRevert("Not Whitelisted or already Claimed");
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);
    }

    function testCannotReleaseInstantWhenPaused() public {
        bytes32[] memory proof = userMerkleProofs[user1];

        // Pause the contract
        release.pause();

        // Include EnforcedPause() error
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);
    }

    function testCannotReleaseInstantWithInsufficientContractBalance() public {
        // Create a new release contract with low balance
        MigrationRelease newImpl = new MigrationRelease();
        bytes memory initData = abi.encodeWithSelector(MigrationRelease.initialize.selector, owner);
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(proxyAdmin), initData);
        MigrationRelease newRelease = MigrationRelease(address(newProxy));

        // Set the same merkle root
        newRelease.setMerkleRoot(merkleRoot);

        // Add minimal funds
        newRelease.addFunds{ value: 0.1 ether }();

        // Try to claim an amount that exceeds the contract balance
        vm.expectRevert("Insufficient balance");
        newRelease.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, userMerkleProofs[user1]);
    }

    /*//////////////////////////////////////////////////////////////
                         RELEASE VESTED TESTS
    //////////////////////////////////////////////////////////////*/

    function testReleaseVested() public {
        // First release instant
        bytes32[] memory proof = userMerkleProofs[user1];
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Fast forward past vesting period
        vm.warp(block.timestamp + release.VESTING_PERIOD() + 1);

        uint256 userBalanceBefore = user1.balance;
        uint256 expectedAmount = (CLAIM_AMOUNT_1 * release.VESTING_RATIO()) / 10;
        uint256 instantAmount = (CLAIM_AMOUNT_1 * release.INSTANT_RATIO()) / 10;

        vm.expectEmit(true, true, true, true);
        emit ReleasedVested(user1, expectedAmount, block.timestamp);
        release.releaseVested(user1, CLAIM_AMOUNT_1, EPOCH);

        uint256 userBalanceAfter = user1.balance;
        assertEq(userBalanceAfter - userBalanceBefore, expectedAmount);

        // Verify totalReleased was updated
        assertEq(release.totalReleased(), instantAmount + expectedAmount);
    }

    function testCannotReleaseVestedBeforeVestingPeriod() public {
        // First release instant
        bytes32[] memory proof = userMerkleProofs[user1];
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Try to release vested before vesting period
        vm.expectRevert("Not Whitelisted or Not Vested");
        release.releaseVested(user1, CLAIM_AMOUNT_1, EPOCH);
    }

    function testCannotReleaseVestedTwice() public {
        // First release instant
        bytes32[] memory proof = userMerkleProofs[user1];
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Fast forward past vesting period
        vm.warp(block.timestamp + release.VESTING_PERIOD() + 1);

        // First vested release
        release.releaseVested(user1, CLAIM_AMOUNT_1, EPOCH);

        // Try to release vested again
        vm.expectRevert("Already Claimed");
        release.releaseVested(user1, CLAIM_AMOUNT_1, EPOCH);
    }

    function testCannotReleaseVestedWhenPaused() public {
        // First release instant
        bytes32[] memory proof = userMerkleProofs[user1];
        release.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Fast forward past vesting period
        vm.warp(block.timestamp + release.VESTING_PERIOD() + 1);

        // Pause the contract
        release.pause();

        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        release.releaseVested(user1, CLAIM_AMOUNT_1, EPOCH);
    }

    function testCannotReleaseVestedWithInsufficientContractBalance() public {
        // Set up a contract with just enough for instant but not vested
        MigrationRelease newImpl = new MigrationRelease();
        bytes memory initData = abi.encodeWithSelector(MigrationRelease.initialize.selector, owner);
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(proxyAdmin), initData);
        MigrationRelease newRelease = MigrationRelease(address(newProxy));

        // Set the same merkle root
        newRelease.setMerkleRoot(merkleRoot);

        // Calculate instant amount and add just that much
        uint256 instantAmount = (CLAIM_AMOUNT_1 * release.INSTANT_RATIO()) / 10;
        newRelease.addFunds{ value: instantAmount }();

        // Release instant
        bytes32[] memory proof = userMerkleProofs[user1];
        newRelease.releaseInstant(user1, CLAIM_AMOUNT_1, EPOCH, proof);

        // Fast forward past vesting period
        vm.warp(block.timestamp + newRelease.VESTING_PERIOD() + 1);

        // Try to release vested with insufficient balance
        vm.expectRevert("Insufficient balance");
        newRelease.releaseVested(user1, CLAIM_AMOUNT_1, EPOCH);
    }

    /*//////////////////////////////////////////////////////////////
                         RECOVER FUNDS TESTS
    //////////////////////////////////////////////////////////////*/

    function testRecoverFunds() public {
        // Recover funds
        release.recoverFunds(address(0), user1, 100 ether);

        // Verify the user received the expected amount
        assertEq(user1.balance, 100 ether);
    }

    function testCannotRecoverFundsToZeroAddress() public {
        vm.expectRevert("Invalid recipient");
        release.recoverFunds(address(0), address(0), 100 ether);
    }

    function testCannotRecoverFundsWhenPaused() public {
        // Pause the contract
        release.pause();

        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        release.recoverFunds(address(0), user1, 100 ether);
    }

    function testRecoverERC20Tokens() public {
        // Deploy a mock ERC20 token
        ERC20Mock mockToken = new ERC20Mock("Mock Token", "MOCK");
        
        // Mint tokens to the contract
        uint256 tokenAmount = 1000 ether;
        mockToken.mint(address(release), tokenAmount);
        
        // Verify initial balances
        assertEq(mockToken.balanceOf(address(release)), tokenAmount);
        assertEq(mockToken.balanceOf(user1), 0);
        
        // Recover tokens
        release.recoverFunds(address(mockToken), user1, tokenAmount);
        
        // Verify final balances
        assertEq(mockToken.balanceOf(address(release)), 0);
        assertEq(mockToken.balanceOf(user1), tokenAmount);
    }
    
    function testCannotRecoverInvalidERC20Amount() public {
        // Deploy a mock ERC20 token
        ERC20Mock mockToken = new ERC20Mock("Mock Token", "MOCK");
        
        // Mint tokens to the contract
        uint256 tokenAmount = 1000 ether;
        mockToken.mint(address(release), tokenAmount);
        
        // Try to recover more tokens than the contract has
        vm.expectRevert("Invalid amount");
        release.recoverFunds(address(mockToken), user1, tokenAmount + 1);
        
        // Try to recover zero tokens
        vm.expectRevert("Invalid amount");
        release.recoverFunds(address(mockToken), user1, 0);
    }
}

// Helper contract for ERC20 token testing
contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

error OwnableUnauthorizedAccount(address account);
error InvalidInitialization();
error EnforcedPause();
