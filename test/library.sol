// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import { Vm } from "lib/forge-std/src/Vm.sol";

library Helper {
    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    function getAdminFromEvents(Vm.Log[] memory logs) external returns (address newAdmin) {
        bytes memory data;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("AdminChanged(address,address)")) {
                data = logs[i].data;
            }
        }
        (, newAdmin) = abi.decode(data, (address, address));
    }

    function _encodeStateBitmap(OperationState operationState) external pure returns (bytes32) {
        return bytes32(1 << uint8(operationState));
    }

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    )
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
    }
}
