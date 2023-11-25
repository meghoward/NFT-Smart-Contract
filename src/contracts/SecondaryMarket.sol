// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";
import "./TicketNFT.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/ISecondaryMarket.sol";
import "./PrimaryMarket.sol";


/**
 * @dev Required interface for the secondary market.
 * The secondary market is the point of sale for tickets after they have been initially purchased from the primary market
 */
contract SecondaryMarket is ISecondaryMarket{

    //listings mapping
    mapping(address => mapping(uint256 => TicketListing)) public listings;

    //highestBids mapping
    mapping(address => mapping(uint256 => Bid)) public highestBids;

    IERC20 private _purchaseToken;
    
    struct TicketListing {
        address seller;
        uint256 price;
        bool isActive;
    }


    struct Bid {
        address bidderAddress;
        uint256 bidAmount;
        uint256 ticketID;
        string newName;
    }

    constructor(IERC20 purchaseToken) {
        _purchaseToken = purchaseToken;
    }



    /**
     * @dev This method lists a ticket with `ticketID` for sale by transferring the ticket
     * such that it is held by this contract. Only the current owner of a specific
     * ticket is able to list that ticket on the secondary market. The purchase
     * `price` is specified in an amount of `PurchaseToken`.
     * Note: Only non-expired and unused tickets can be listed
     */
    function listTicket(
        address ticketCollection,
        uint256 ticketID,
        uint256 price)   external {
        TicketNFT ticketNFT = TicketNFT(ticketCollection);

        require(ticketNFT.holderOf(ticketID) == msg.sender, "Not the ticket owner");
        require(!ticketNFT.isExpiredOrUsed(ticketID), "Ticket expired or used");
        require(!listings[ticketCollection][ticketID].isActive, "Ticket already listed");

        ticketNFT.transferFrom(msg.sender, address(this), ticketID);
        listings[ticketCollection][ticketID] = TicketListing(msg.sender, price, true);

        emit Listing(msg.sender, ticketID, price);
    }


    /** @notice This method allows the msg.sender to submit a bid for the ticket from `ticketCollection` with `ticketID`
     * The `bidAmount` should be kept in escrow by the contract until the bid is accepted, a higher bid is made,
     * or the ticket is delisted.
     * If this is not the first bid for this ticket, `bidAmount` must be strictly higher that the previous bid.
     * `name` gives the new name that should be stated on the ticket when it is purchased.
     * Note: Bid can only be made on non-expired and unused tickets
     */
    function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    ) external {
        TicketListing storage ticketListing = listings[ticketCollection][ticketID];
        TicketNFT ticketNFT = TicketNFT(ticketCollection);

        require(ticketListing.isActive, "Ticket not for sale");
        require(!ticketNFT.isExpiredOrUsed(ticketID), "Cannot bid on used or expired tickets");
        require(ticketNFT.holderOf(ticketID) != msg.sender, "Cannot bid on own ticket");

        // Check if the bidAmount is higher than the current highest bid
        require(bidAmount > highestBids[ticketCollection][ticketID].bidAmount, "Bid too low");

        _purchaseToken.transferFrom(msg.sender, address(this), bidAmount);

        // Refund the previous highest bidder
        if (highestBids[ticketCollection][ticketID].bidAmount > 0) {    
            _purchaseToken.transfer(highestBids[ticketCollection][ticketID].bidderAddress, highestBids[ticketCollection][ticketID].bidAmount);
        }

        highestBids[ticketCollection][ticketID] = Bid(msg.sender, bidAmount, ticketID, name);

        emit BidSubmitted(msg.sender, ticketCollection, ticketID, bidAmount);
    }



    /**
    * Returns the current highest bid for the ticket from `ticketCollection` with `ticketID`
    */
    function getHighestBid(
        address ticketCollection,
        uint256 ticketID
    ) external view returns (uint256) {
        return highestBids[ticketCollection][ticketID].bidAmount;
    }


    /**
    * Returns the current highest bidder for the ticket from `ticketCollection` with `ticketID`
    */
    function getHighestBidder(
        address ticketCollection,
        uint256 ticketID
    ) external view returns (address) {
        return highestBids[ticketCollection][ticketID].bidderAddress;
    }


    /*
     * @notice Allow the lister of the ticket from `ticketCollection` with `ticketID` to accept the current highest bid.
     * This function reverts if there is currently no bid.
     * Otherwise, it should accept the highest bid, transfer the money to the lister of the ticket,
     * and transfer the ticket to the highest bidder after having set the ticket holder name appropriately.
     * A fee charged when the bid is accepted. The fee is charged on the bid amount.
     * The final amount that the lister of the ticket receives is the price
     * minus the fee. The fee should go to the creator of the `ticketCollection`.
     */
    function acceptBid(address ticketCollection, uint256 ticketID) external {
        TicketListing storage ticketListing = listings[ticketCollection][ticketID];
        require(ticketListing.isActive && ticketListing.seller == msg.sender, "Not authorized to accept bid");

        
        TicketNFT ticketNFT = TicketNFT(ticketCollection);
        address eventCreator = ticketNFT.creator();
        require(eventCreator != address(0), "Admin address not set");

        Bid memory highestBid = highestBids[ticketCollection][ticketID];
        require(highestBid.bidAmount > 0, "No active bids for this ticket");

        uint256 fee = (highestBid.bidAmount * 5) / 100;
        uint256 sellerAmount = highestBid.bidAmount - fee;

        _purchaseToken.transfer(ticketListing.seller, sellerAmount);
        _purchaseToken.transfer(eventCreator, fee);

        TicketNFT(ticketCollection).updateHolderName(ticketID, highestBid.newName);
        TicketNFT(ticketCollection).transferFrom(address(this), highestBid.bidderAddress, ticketID);

        // emit a BidAccepted event
        emit BidAccepted(highestBid.bidderAddress, ticketCollection, ticketID, highestBid.bidAmount);
        
        delete listings[ticketCollection][ticketID];
        delete highestBids[ticketCollection][ticketID];

}


    /** @notice This method delists a previously listed ticket of `ticketCollection` with `ticketID`. Only the account that
     * listed the ticket may delist the ticket. The ticket should be transferred back
     * to msg.sender, i.e., the lister, and escrowed bid funds should be return to the bidder, if any.
     */
    function delistTicket(address ticketCollection, uint256 ticketID) external {
        TicketListing memory ticketListing = listings[ticketCollection][ticketID];
        require(ticketListing.seller == msg.sender, "Not the seller");

        TicketNFT(ticketCollection).transferFrom(address(this), msg.sender, ticketID);
        delete listings[ticketCollection][ticketID];


        if (highestBids[ticketCollection][ticketID].bidAmount > 0) {
            _purchaseToken.transfer(highestBids[ticketCollection][ticketID].bidderAddress, highestBids[ticketCollection][ticketID].bidAmount);
            delete highestBids[ticketCollection][ticketID];
        }


        emit Delisting(ticketCollection, ticketID);
        }
    }
