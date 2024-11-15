// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20PermitUpgradeable,
    NoncesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { console } from "forge-std/Test.sol";

contract Pushh is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor

    ///@dev 700 refers to 7%, to avoid round ups, divide by 10000
    uint256 public ALLOWED_INFLATION;

    ///@dev used to determine the time frame for minting
    uint256 public year;

    ///@dev initialized at deploy time, as a genesis value
    uint256 public INIT;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    ///@dev stores the required total supply for an year
    mapping(uint256 year => uint256 mintable) public YearToTotalSupply;

    function initialize(address defaultAdmin, address minterRole, address recipient) public initializer {
        __ERC20_init("Pushh", "PSH");
        __ERC20Burnable_init();
        __AccessControl_init();
        __ERC20Permit_init("Pushh");
        __ERC20Votes_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minterRole);

        _mint(recipient, 10_000_000_000 * 10 ** decimals());

        INIT = block.timestamp;
        ALLOWED_INFLATION = 700;
        year = 365 days;

        uint256 initSupply = totalSupply();
        YearToTotalSupply[currentYear()] = initSupply;
        uint256 mintableAmount = (initSupply * ALLOWED_INFLATION) / 10_000;
        YearToTotalSupply[currentYear() + 1] = initSupply + mintableAmount;
    }

    function currentYear() public view returns (uint256) {
        return (block.timestamp - INIT) / year ;
    }

    /**
     * @dev only Minter can call
     *      reverts if an year has not passed
     *      if 1 year has passed, fetches the mintable year for current Year
     *      The amount + totalSupply should not exceed inflation rate
     *      Sets the mintable amount for next year, if not already set
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        uint256 _currentYear = currentYear();

        if (_currentYear == 0) {
            revert("Invalid Year");
        }
        console.log(_currentYear);
        console.log(YearToTotalSupply[_currentYear] , totalSupply());
        uint256 mintableAmount = YearToTotalSupply[_currentYear] - totalSupply();

        if (amount > mintableAmount) {
            revert("Limit Exceed");
        }
        _mint(to, amount);
        if (YearToTotalSupply[_currentYear + 1] == 0) {
            YearToTotalSupply[_currentYear + 1] = (mintableAmount * ALLOWED_INFLATION) / 10_000;
        }
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }
}
