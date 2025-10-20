// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/// @title IAmbImplementation
/// @dev Interface for arbitrary message bridge (AMB) implementations
/// @author ZeroPoint Labs
struct Message {
    uint8 msgType; // 1 -> deposit, 2 -> withdraw
    uint256 amount; // per chain
    address messageCreator;
    uint16 sourceChain;
    address sourceUser;
}
interface IAmbSenderImplementation {


    //////////////////////////////////////////////////////////////
    //                      AMB  ERRORS                         //
    //////////////////////////////////////////////////////////////

    /// @dev thrown if same amb tries to deliver a payload and proof
    // error MALICIOUS_DELIVERY();

    //////////////////////////////////////////////////////////////
    //                          EVENTS                          //
    //////////////////////////////////////////////////////////////

    // event ChainAdded(uint64 indexed superChainId);
    // event AuthorizedImplAdded(uint64 indexed superChainId, address indexed authImpl);

    //////////////////////////////////////////////////////////////
    //              EXTERNAL VIEW FUNCTIONS                     //
    //////////////////////////////////////////////////////////////

    /// not all AMBs will have on-chain estimation for which this function will return 0
    /// is the identifier of the destination chain
    ///  is the cross-chain message
    ///  is any amb-specific information
    ///is the native_tokens to be sent along the transaction
    function quoteCrossChainCost(
        uint16 targetChain
    )
        external
        view
        returns (uint256 cost);

    /// @dev returns the extra data for the given gas request
    /// @param gasLimit is the amount of gas limit in wei to override
    /// @return extraData is the bytes encoded extra data
    /// NOTE: this process is unique to the message bridge
    // function generateExtraData(uint256 gasLimit) external pure returns (bytes memory extraData);

    //////////////////////////////////////////////////////////////
    //              EXTERNAL WRITE FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /// is the caller (used for gas refunds)
    /// is the identifier of the destination chain
    ///is the cross-chain message to be sent
    ///is message amb specific override information
    function sendMessage(
        uint16 targetChain,
        address targetAddress,
        bytes memory message
    )
        external
        payable;

    /// @dev allows for the permissionless calling of the retry mechanism for encoded data
    /// @param data_ is the encoded retry data (different per AMB implementation)
    // function retryPayload(bytes memory data_) external payable;

}
