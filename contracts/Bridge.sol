                                                              
//                          ==                                
//                         ===                               
//                        ====                               
//                        ====                               
//                        =-==                               
//                       ==-==                               
//                       =--==                     ==       
//                      ==--==                 =====+        
//   ====               =---==           =====-====          
//    ======           ==---==   ======-----====             
//       ==--===       =----===----------===                 
//         ==---===   ==----=--------====                    
//           ==-----===-----=-----====                       
//             ==------==---=====-----==                     
//               ==-------======--------==                   
//                 =-------====-===-------==                 
//                  ======----=----===-----==                
//                  ===-------=-----= ====----==             
//               ==----------==-----=     ===--===           
//           ===-------========----=         ====-==         
//        ===-=-=====        ==---==             ======      
//     ========              ==---=                 ====     
//   =====                   ==--==                          
//                           ==--=                           
//                           ==-==                           
//                           ==-=                            
//                            ===                            
//                            ===                            
//                            ==                             
//                            ==                             
                                                              
                                                               

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HyperBoreBridge is ReentrancyGuard, Ownable, Pausable {

    mapping(address => bool) public validators;
    mapping(bytes32 => bool) public processedNonces;
    address private pendingOwner;
    address private treasury;
    uint16 public requiredSignatures;
    address public token_address;
    uint16 public fee_basis_points;
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event RequiredSignaturesChanged(uint256 newThreshold);
    event FeeBasisPointsUpdated(uint16 newFeeBasisPoints);
    event TokenAddressUpdated(address indexed token_address);
    event TreasuryUpdated(address indexed treasury);

    event TokensReleased(
        address indexed recipient,
        uint256 amount,
        bytes32 indexed solanaTransactionId,
        bytes32 nonce
    );

    event UsdcDeposited(
        address indexed sender,
        uint256 amount,
        bytes32 solanaRecipient,
        uint256 feeAmount,
        bytes32 nonce
    );


    constructor(
        address initialValidator,
        uint16 _requiredSignatures,
        address _token_address,
        uint16 _fee_basis_points
    ) Ownable(msg.sender) {
        validators[initialValidator] = true;
        treasury = msg.sender;
        requiredSignatures = _requiredSignatures;
        token_address = _token_address;
        fee_basis_points = _fee_basis_points;
        emit ValidatorAdded(initialValidator);
    }

    // Helper Functions
    function _verifySignatures(
        bytes32 messageHash,
        Signature[] calldata signatures
    ) internal view {
        require(signatures.length >= requiredSignatures, "Not enough signatures");
        
        address[] memory recoveredAddresses = new address[](signatures.length);
        
        for (uint i = 0; i < signatures.length; i++) {
            address recoveredAddress = ecrecover(
                messageHash,
                signatures[i].v,
                signatures[i].r,
                signatures[i].s
            );
            
            // Check if recovered address is a validator
            require(validators[recoveredAddress], "Invalid validator signature");
            
            // Check for duplicate signatures
            for (uint j = 0; j < i; j++) {
                require(recoveredAddress != recoveredAddresses[j], "Duplicate signatures");
            }
            
            recoveredAddresses[i] = recoveredAddress;
        }
    }
    
    function _generateNonce(uint256 amount, bytes32 solanaRecipient) internal view returns (bytes32) {
        return keccak256(abi.encode(block.prevrandao, block.timestamp, msg.sender, block.number, amount, solanaRecipient, token_address));
    }
    
    /**
     * @dev Get the USDC balance of the contract
     */
    function getTokenBalance() external view returns (uint256) {
        return IERC20(token_address).balanceOf(address(this));
    }

    /**
     * @dev Release USDC on Hyper Liquid based on a deposit on Solana
     * @param recipient Address to receive USDC
     * @param amount Amount of USDC to release
     * @param solanaTransactionId Solana transaction ID for reference
     * @param nonce Unique identifier to prevent replay attacks
     * @param signatures Array of validator signatures
     */
    function bridgeFromSolana(
        address recipient,
        uint256 amount,
        bytes32 solanaTransactionId,
        bytes32 nonce,
        Signature[] calldata signatures
    ) external whenNotPaused nonReentrant {
        require(!processedNonces[nonce], "Nonce already processed");
        // Verify signatures
        bytes32 messageHash = keccak256(
            abi.encode(
                block.chainid,
                recipient,
                amount,
                solanaTransactionId,
                token_address,
                nonce
            )
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        
        // Verify required number of signatures
        _verifySignatures(ethSignedMessageHash, signatures);
        
        // Mark nonce as processed
        processedNonces[nonce] = true;
         // Transfer USDC to recipient
        require(
            IERC20(token_address).transfer(recipient, amount),
            "USDC transfer failed"
        );
        
        
        emit TokensReleased(recipient, amount, solanaTransactionId, nonce);
    }

    /**
     * @dev Deposit USDC on Hyper Liquid to bridge to Solana
     * @param amount Amount of USDC to deposit
     * @param solanaRecipient Solana account to receive USDC
     */
    function bridgeToSolana(
        uint256 amount,
        bytes32 solanaRecipient
    ) external whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        // Calculate fee
        uint256 feeAmount = (amount * fee_basis_points) / 10000;
        uint256 transferAmount = amount - feeAmount;
        
        // Generate a unique nonce
        bytes32 nonce = _generateNonce(amount, solanaRecipient);

        require(
            IERC20(token_address).transferFrom(msg.sender, address(this), amount),
            "USDC transfer failed"
        );

        require(
            IERC20(token_address).transfer(treasury, feeAmount),
            "Fee transfer failed"
        );
        
        emit UsdcDeposited(msg.sender, transferAmount, solanaRecipient, feeAmount, nonce);
    }

    // Admin functions
    function addValidator(address validator) external onlyOwner {
        require(!validators[validator], "Validator already exists");
        validators[validator] = true;
        emit ValidatorAdded(validator);
    }
    
    function removeValidator(address validator) external onlyOwner {
        require(validators[validator], "Validator doesn't exist");
        validators[validator] = false;
        emit ValidatorRemoved(validator);
    }
    
    function updateRequiredSignatures(uint16 newThreshold) external onlyOwner {
        requiredSignatures = newThreshold;
        emit RequiredSignaturesChanged(newThreshold);
    }
    
    function updateFees(uint16 newFeeBasisPoints) external onlyOwner {
        require(newFeeBasisPoints <= 2000, "Fee percentage too high");
        fee_basis_points = newFeeBasisPoints;
        emit FeeBasisPointsUpdated(newFeeBasisPoints);
    }

    function updateTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
        emit TreasuryUpdated(treasury);
    }

    function updateTokenAddress(address newTokenAddress) external onlyOwner {
        token_address = newTokenAddress;
        emit TokenAddressUpdated(token_address);
    }

    function initiateOwnershipTransfer(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == pendingOwner, "Not authorized");
        address newOwner = pendingOwner;
        pendingOwner = address(0);
        _transferOwnership(newOwner);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }

     /**
     * @dev Withdraw pool
     * @param amount Amount of USDC to withdraw
     */
    function withdrawPool(uint256 amount) external onlyOwner {
        require(
            IERC20(token_address).transfer(owner(), amount),
            "USDC transfer failed"
        );
    }
}