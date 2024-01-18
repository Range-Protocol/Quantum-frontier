// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract NFTClaim is EIP712 {
    IERC1155 public nftContract;
    address public owner;

    // EIP712 Domain Separator structure
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline,uint256 chainId)"
    );

    // Mapping of nonces for each user
    mapping(address => uint256) public  _nonces;

    constructor(address _nftContract) EIP712("NFTClaim", "1") {
        owner = msg.sender;
        nftContract = IERC1155(_nftContract);
    }

    function claimNFTWithPermit(
        uint256 tokenId,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        // Calculate the current nonce for the sender
        uint256 currentNonce = _nonces[msg.sender];
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        // EIP712 signature verification using SignatureChecker
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            msg.sender,
            tokenId,
            amount,
            currentNonce,
            deadline,
            chainId
        )));
        require(
            SignatureChecker.isValidSignatureNow(owner, digest, signature),
            "Invalid signature"
        );

        // Increment the nonce after successful use
        _nonces[msg.sender]++;

        // Perform the safe transfer of ERC1155
        nftContract.safeTransferFrom(owner, msg.sender, tokenId, amount, "");
    }
}