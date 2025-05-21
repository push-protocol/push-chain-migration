// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEPNS} from "./Mocks/IPush.sol";
contract MigrationLocker is Ownable {
    using SafeERC20 for IERC20;
    
    event Locked(address recipient, uint amount, uint indexed id);

    address public PUSH_TOKEN;

    uint counter;

    constructor(address _push, address _admin) Ownable(_admin) {
        PUSH_TOKEN = _push;
    }

    function lock(uint _amount, address _recipient) external {
        require(_recipient != address(0),"invalid recipient");
        IERC20(PUSH_TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
        emit Locked(_recipient, _amount, counter++);
    }

    function burn(uint _amount) external onlyOwner{
        IEPNS(PUSH_TOKEN).burn(_amount);
    }

}