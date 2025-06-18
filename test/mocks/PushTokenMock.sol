// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IPushMock } from "../interfaces/v8/IPushMock.sol";

/**
 * @title PushTokenMock
 * @dev A simplified mock of the PUSH token for testing the MigrationLocker contract
 */
contract PushTokenMock is ERC20, IPushMock {
    // Constructor inherits from ERC20 to set token name and symbol
    constructor() ERC20("Push Token", "PUSH") { }

    // Custom mint function for testing
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Override burn from IPushMock
    function burn(uint256 rawAmount) external override {
        _burn(msg.sender, rawAmount);
    }

    // Override transferFrom from IPushMock and ERC20
    function transferFrom(
        address src,
        address dst,
        uint256 rawAmount
    )
        public
        virtual
        override(ERC20, IPushMock)
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(src, spender, rawAmount);
        _transfer(src, dst, rawAmount);
        return true;
    }

    // Override transfer from IPushMock and ERC20
    function transfer(address dst, uint256 rawAmount) public virtual override(ERC20, IPushMock) returns (bool) {
        _transfer(msg.sender, dst, rawAmount);
        return true;
    }

    // Override balanceOf from IPushMock and ERC20
    function balanceOf(address account) public view virtual override(ERC20, IPushMock) returns (uint256) {
        return super.balanceOf(account);
    }
}
