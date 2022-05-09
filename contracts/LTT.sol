// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract LTT is Initializable, ERC20Upgradeable, OwnableUpgradeable{

    function initialize(address owner) public virtual initializer {
        require(owner != address(0), "Owner cannot be the zero address");
        __ERC20_init("LordToken", "LTT");
        __Ownable_init();
        _transferOwnership(owner);
        _mint(owner, 2000000000000000000);
    }
    

    /**
     * @dev Change decimals to 9.
     */
    function decimals() public view virtual override returns (uint8) {
      return 9;
    }

    /**
     * @dev Returns the token owner. Compatibility with IBEP20.
     */
    function getOwner() external view returns (address) {
        return owner();
    }


    /**
     * @dev Burnable but only owner can reduce total supply.
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }


    /**
     * @dev Burnable, if given allowance, but only owner can reduce total supply.
     */
    function burnFrom(address account, uint256 amount) external onlyOwner {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
}