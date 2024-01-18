// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// MyToken is an ERC1155 token with Access Control and supply tracking capabilities.
contract MyToken is ERC1155, AccessControl, ERC1155Burnable, ERC1155Supply {
    // Role definitions for URI setting and token minting
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Variables to track the maximum total supply and total amount minted
    uint256 public maxTotalSupply;
    uint256 public totalMinted;

    // Constructor for initializing the MyToken contract
    constructor(
        address defaultAdmin, 
        address minter, 
        uint256 _maxTotalSupply,
        string memory _baseURI // Added parameter for the base URI
    ) ERC1155(_baseURI) { // Passing _baseURI to the ERC1155 constructor
        // Setting up roles for default admin and minter
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);

        // Setting the maximum total supply
        maxTotalSupply = _maxTotalSupply;
    }

    // Function to mint new tokens, restricted to users with MINTER_ROLE
    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        // Ensure that the total minted tokens do not exceed the max total supply
        require(totalMinted + amount <= maxTotalSupply, "Max total supply exceeded");
        totalMinted += amount;
        _mint(account, id, amount, data);
    }

    // Function to set a new URI for the tokens, restricted to users with URI_SETTER_ROLE
    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    // Function to mint multiple tokens in a batch, restricted to users with MINTER_ROLE
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        // Calculate the total amount in the batch
        uint256 batchTotal = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            batchTotal += amounts[i];
        }

        // Ensure that the total minted tokens (including this batch) do not exceed the max total supply
        require(totalMinted + batchTotal <= maxTotalSupply, "Max total supply exceeded");
        totalMinted += batchTotal;
        _mintBatch(to, ids, amounts, data);
    }

    // Override the uri function to concatenate the token ID to the base URI
    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(id), Strings.toString(id)));
    }


    // Override functions from ERC1155 and ERC1155Supply to manage updates and interface support
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
