// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";
import "./TicketNFT.sol";
import "../interfaces/IERC20.sol";


/**
 * @dev Required interface for the primary market.
 * The primary market is the first point of sale for tickets.
 * It is responsible for minting tickets and transferring them to the purchaser.
 * The NFT to be minted is an implementation of the ITicketNFT interface and should be created (i.e. deployed)
 * when a new event NFT collection is created
 * In this implementation, the purchase price and the maximum number of tickets
 * is set when an event NFT collection is created
 * The purchase token is an ERC20 token that is specified when the contract is deployed.
 */
contract PrimaryMarket {
    IERC20 private _purchaseToken;

    struct EventDetails {
        string eventName;
        uint256 price;
        uint256 maxNumberOfTickets;
        uint256 ticketsSold;
        address creator;
    }

    mapping(address => EventDetails) public deployedEvents;

    constructor(IERC20 purchaseToken) {
        _purchaseToken = purchaseToken;
    } 

    /**
     * @dev Emitted when a purchase by `holder` occurs, with `holderName` specified.
     */
    event EventCreated(
        address indexed creator,
        address indexed ticketCollection,
        string eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    );

    /**
     * @dev Emitted when a purchase by `holder` occurs, with `holderName` specified.
     */
    event Purchase(
        address indexed holder,
        address indexed ticketCollection,
        uint256 ticketId,
        string holderName
    );

    /**
     *
     * @param eventName is the name of the event to create
     * @param price is the price of a single ticket for this event
     * @param maxNumberOfTickets is the maximum number of tickets that can be created for this event
     */
    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT) {
        TicketNFT newTicketCollection = new TicketNFT(maxNumberOfTickets, eventName, price, address(this), address(_purchaseToken), msg.sender);
        address newTicketCollectionAddress = address(newTicketCollection);

        deployedEvents[newTicketCollectionAddress] = EventDetails({
            eventName: eventName,
            price: price,
            maxNumberOfTickets: maxNumberOfTickets,
            ticketsSold: 0,
            creator: msg.sender
        });

        emit EventCreated(msg.sender, newTicketCollectionAddress, eventName, price, maxNumberOfTickets);

        return ITicketNFT(newTicketCollectionAddress);
    }


    /**
     * @notice Allows a user to purchase a ticket from `ticketCollectionNFT`
     * @dev Takes the initial NFT token holder's name as a string input
     * and transfers ERC20 tokens from the purchaser to the creator of the NFT collection
     * @param ticketCollection the collection from which to buy the ticket
     * @param holderName the name of the buyer
     * @return id of the purchased ticket
     */

    function purchase(address ticketCollection, string memory holderName) external returns (uint256) {
        EventDetails storage eventDetails = deployedEvents[ticketCollection];
        require(eventDetails.ticketsSold < eventDetails.maxNumberOfTickets, "No more tickets available");
        require(deployedEvents[ticketCollection].creator != address(0), "Invalid creator address");
    

        // Handle payment
        _purchaseToken.transferFrom(msg.sender, eventDetails.creator, eventDetails.price);

        // Mint ticket
        uint256 ticketId = TicketNFT(ticketCollection).mint(msg.sender, holderName);
        eventDetails.ticketsSold += 1;

        emit Purchase(msg.sender, ticketCollection, ticketId, holderName);

        return ticketId;
    }
    /**
     * @param ticketCollection the collection from which to get the price
     * @return price of a ticket for the event associated with `ticketCollection`
     */
    function getPrice(address ticketCollection) external view returns (uint256) {
        return deployedEvents[ticketCollection].price;
    }
}


