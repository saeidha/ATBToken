// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ABTToken is ERC20, Ownable {
    // Max supply: 100 Billion tokens (with 18 decimals)
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * (10**18);

    // The address of the distributor contract allowed to mint
    address public distributor;

    event DistributorUpdated(address indexed oldDistributor, address indexed newDistributor);

    constructor(address _initialOwner)
        // Set name and symbol
        ERC20("ABT Token", "ABT")
        Ownable(_initialOwner)
    {}

    /**
     * @dev Sets the distributor contract address. Only owner can call this.
     */
    function setDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "ABT: Invalid address");
        emit DistributorUpdated(distributor, _distributor);
        distributor = _distributor;
    }

    /**
     * @dev Mints tokens. Can only be called by the registered distributor.
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == distributor, "ABT: Caller is not the distributor");
        require(totalSupply() + amount <= MAX_SUPPLY, "ABT: Max supply exceeded");
        _mint(to, amount);
    }
}