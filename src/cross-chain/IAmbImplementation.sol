// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/// @title IAmbImplementation
/// @dev Interface for arbitrary message bridge (AMB) implementations
/// @author ZeroPoint Labs
interface IAmbImplementation {
    struct Message {
        uint8 msgType; // 1 -> deposit, 2 -> withdraw
        uint256 amount; // per chain
        address messageCreator;
        uint16 sourceChain;
        address sourceUser;
    }

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

    


    /**
     * @notice When a `send` is performed with this contract as the target, this function will be
     *     invoked by the WormholeRelayer contract
     *
     * NOTE: This function should be restricted such that only the Wormhole Relayer contract can call it.
     *
     * We also recommend that this function checks that `sourceChain` and `sourceAddress` are indeed who
     *       you expect to have requested the calling of `send` on the source chain
     *
     * The invocation of this function corresponding to the `send` request will have msg.value equal
     *   to the receiverValue specified in the send request.
     *
     * If the invocation of this function reverts or exceeds the gas limit
     *   specified by the send requester, this delivery will result in a `ReceiverFailure`.
     *
     * @param payload - an arbitrary message which was included in the delivery by the
     *     requester. This message's signature will already have been verified (as long as msg.sender is the Wormhole Relayer contract)
     * @param additionalMessages - Additional messages which were requested to be included in this delivery.
     *      Note: There are no contract-level guarantees that the messages in this array are what was requested
     *      so **you should verify any sensitive information given here!**
     *
     *      For example, if a 'VaaKey' was specified on the source chain, then MAKE SURE the corresponding message here
     *      has valid signatures (by calling `parseAndVerifyVM(message)` on the Wormhole core contract)
     *
     *      This field can be used to perform and relay TokenBridge or CCTP transfers, and there are example
     *      usages of this at
     *         https://github.com/wormhole-foundation/hello-token
     *         https://github.com/wormhole-foundation/hello-cctp
     *
     * @param sourceAddress - the (wormhole format) address on the sending chain which requested
     *     this delivery.
     * @param sourceChain - the wormhole chain ID where this delivery was requested.
     * @param deliveryHash - the VAA hash of the deliveryVAA.
     *
     */
    function receiveMessage(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable returns(Message memory message);
}
