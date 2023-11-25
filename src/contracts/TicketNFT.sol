// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";

/**
 * @dev Required interface for the TicketNFT contract.
 * A ticket NFT is a non-fungible token that represents a single entry to an event.
 */
contract TicketNFT is ITicketNFT {
    struct Ticket {
        string ticketName;
        uint256 tickID;
        string holderName;
        uint256 validUntil;
        bool isUsed;
    }

    uint256 public tickID;
    uint256 private _ticketIdCounter;
    uint256 private _maxNumberOfTickets;
    address private _admin;
    address private primaryMarketAddress;
    string private _eventName;
    uint256 public price;
    address public tokenAddress;
    address private _eventCreator;


    mapping(uint256 => Ticket) private _tickets;
    mapping(uint256 => address) private _ticketOwners;
    mapping(uint256 => address) private _ticketApprovals;
    mapping(address => uint256) private _balances;

    constructor(uint256 maxTickets_, string memory eventName_, uint256 price_, address _primaryMarketAddress, address erc20Token, address eventCreator_) {
        _ticketIdCounter = 1;
        _maxNumberOfTickets = maxTickets_;
        _eventName = eventName_;
        price = price_;
        _admin = msg.sender;
        primaryMarketAddress = _primaryMarketAddress; 
        tokenAddress = erc20Token;
        _eventCreator = eventCreator_;
    }

    /**
     * @dev Returns the address of the user who created the NFT collection
     * This is the address of the user who called `createNewEvent` in the primary market
     */
    function creator() external view returns (address) {
        return _eventCreator;
    }
    
    function getTicketID() public view returns (uint256) {
        return tickID;
    }


    /**
     * @dev Returns the maximum number of tickets that can be minted for this event. 
     */ 
    function maxNumberOfTickets() external view returns (uint256) {
        return _maxNumberOfTickets;
    }

	/**
     * @dev Returns the name of the event for this TicketNFT
     */
    function eventName() external view returns (string memory) {
        return _eventName;
    }

    /**
     * Mints a new ticket for `holder` with `holderName`.
     * The ticket must be assigned the following metadata:
     * - A unique ticket ID. Once a ticket has been used or expired, its ID should not be reallocated
     * - An expiry time of 10 days from the time of minting
     * - A boolean `used` flag set to false
     * On minting, a `Transfer` event should be emitted with `from` set to the zero address.
     *
     * Requirements:
     *
     * - The caller must be the primary market
     */

    function mint(address holder, string memory holderName) external returns (uint256) {
        require(msg.sender == _admin, "Only admin can mint tickets");
        require(msg.sender == primaryMarketAddress, "ERC-721: Minter must be primary market");
        require(_ticketIdCounter <= _maxNumberOfTickets, "ERC-721: Maximum Tokens minted");

        uint256 newTicketId = _ticketIdCounter;
        _tickets[newTicketId] = Ticket({
            ticketName: _eventName, // Assuming the event name is the same as the NFT collection name
            tickID: newTicketId,
            holderName: holderName,
            validUntil: block.timestamp + (10*86400),
            isUsed: false
        });

        _ticketOwners[newTicketId] = holder;
        _balances[holder] += 1;
        _ticketIdCounter += 1;

        // Emit Transfer event
        emit Transfer(address(0), holder, newTicketId);

        return newTicketId;
    }


    /**
     * @dev Returns the number of tickets a `holder` has.
     */
    function balanceOf(address holder) external view returns (uint256 balance) {
        require(holder != address(0), "ERC721: balance query for the zero address");
        return _balances[holder];
    }

    /**
     * @dev Returns the address of the holder of the `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderOf(uint256 ticketID) external view returns (address holder) {
        require(_exists(ticketID), "ERC-721: Ticket doesn't exist.");
        return _ticketOwners[ticketID];
    }


    /**
     * @dev Transfers `ticketID` ticket from `from` to `to`.
     * This should also set the approved address for this ticket to the zero address
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - the caller must either:
     *   - own `ticketID`
     *   - be approved to move this ticket using `approve`
     *
     * Emits a `Transfer` and an `Approval` event.
     */
    function transferFrom(
        address from, 
        address to,
        uint256 ticketID
    ) external {
        require(_ticketOwners[ticketID] == from, "Ticket doesn't exist at this address");
        require(to != address(0), "Address 0 is an invalid reciever");
        require(from != address(0), "Address 0 is an invalid owner");
        require(_ticketOwners[ticketID] == msg.sender || _ticketApprovals[ticketID] == msg.sender, "Caller not owner nor approved");

        // Update the ticket owner
        _ticketOwners[ticketID] = to;

        // Update the balances
        _balances[from] -= 1;
        _balances[to] += 1;

        // Clear any existing approval
        _ticketApprovals[ticketID] = address(0);

        // Emit the Transfer event
        emit Transfer(from, to, ticketID);

        // Emit the Approval event to indicate the approval is cleared
        emit Approval(from, address(0), ticketID);
    }


    /**
     * @dev Gives permission to `to` to transfer `ticketID` ticket to another account.
     * The approval is cleared when the ticket is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the ticket
     * - `ticketID` must exist.
     *
     * Emits an `Approval` event.
     */
    function approve(address to, uint256 ticketID) external override {
        require(_exists(ticketID), "TicketNFT: ticket does not exist");
        require(_ticketOwners[ticketID] == msg.sender, "Caller is not the ticket owner");
        _ticketApprovals[ticketID] = to;

        emit Approval(msg.sender, to, ticketID);
    }


    function _exists(uint256 ticketID) internal view returns (bool) {
        return ticketID > 0 && ticketID <= _maxNumberOfTickets;
    }



    /**
     * @dev Returns the account approved for `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function getApproved(uint256 ticketID)
        external
        view
        returns (address operator) {
        require(_exists(ticketID), "ERC-721: Ticket doesn't exist.");
        return _ticketApprovals[ticketID];
        }

    /**
     * @dev Returns the current `holderName` associated with a `ticketID`.
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderNameOf(uint256 ticketID)
        external
        view
        returns (string memory holderName) {
        return _tickets[ticketID].holderName;
        }

    /**
     * @dev Updates the `holderName` associated with a `ticketID`.
     * Note that this does not update the actual holder of the ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exists
     * - Only the current holder can call this function
     */

    function updateHolderName(uint256 ticketID, string calldata newName) external {
        require(_ticketOwners[ticketID] == msg.sender, "ERC-721: Only ticket holder can call function.");
        require(_exists(ticketID), "ERC-721: Ticket doesn't exist.");

        _tickets[ticketID].holderName = newName;
    }


    /**
     * @dev Sets the `used` flag associated with a `ticketID` to `true`
     *
     * Requirements:
     *
     * - `ticketID` must exist
     * - the ticket must not already be used
     * - the ticket must not be expired
     * - Only the creator of the collection can call this function
     */
    function setUsed(uint256 ticketID) external {
        require(msg.sender == _admin, "Only admin can set ticket as used");
        require(_exists(ticketID), "ERC-721: Ticket doesn't exist.");
        require(block.timestamp <= _tickets[ticketID].validUntil, "ERC-721: Ticket expired");
        require(!_tickets[ticketID].isUsed, "Ticket is already used");

        _tickets[ticketID].isUsed = true;
    }

    /**
     * @dev Returns `true` if the `used` flag associated with a `ticketID` if `true`
     * or if the ticket has expired, i.e., the current time is greater than the ticket's
     * `expiryDate`.
     * Requirements:
     *
     * - `ticketID` must exist
     */
    function isExpiredOrUsed(uint256 ticketID) external view override returns (bool) {
        Ticket memory ticket = _tickets[ticketID];
        return ticket.isUsed || block.timestamp > ticket.validUntil;
    }
}