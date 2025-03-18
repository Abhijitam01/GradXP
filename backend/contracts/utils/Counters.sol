// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Counters
 * @dev Provides counters that can only be incremented, decremented, or reset.
 * This can be used, for example, to track the number of elements in a mapping,
 * issuing ERC721 ids, or counting request ids.
 */
library Counters {
    struct Counter {
        uint256 _value; // Default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counters: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}
