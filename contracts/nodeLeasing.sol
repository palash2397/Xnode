// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//    /$$   /$$ /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$$
//   | $$  / $$| $$$ | $$ /$$__  $$| $$__  $$| $$_____/
//   |  $$/ $$/| $$$$| $$| $$  \ $$| $$  \ $$| $$
//    \  $$$$/ | $$ $$ $$| $$  | $$| $$  | $$| $$$$$
//     >$$  $$ | $$  $$$$| $$  | $$| $$  | $$| $$__/
//    /$$/\  $$| $$\  $$$| $$  | $$| $$  | $$| $$
//   | $$  \ $$| $$ \  $$|  $$$$$$/| $$$$$$$/| $$$$$$$$
//   |__/  |__/|__/  \__/ \______/ |_______/ |________/



import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NodeLeasing is Pausable, Ownable {

    IERC20 public usdt;

    uint256 public constant WEEKLY_RENT = 32 * 10 ** 6; // 6 decimals for USDT
    uint256 public constant LEASE_DURATION_WEEKS = 150;
    uint256 public constant WEEK_IN_SECONDS = 7 days;

    struct Node {
        address owner;
        bool leased;
        address lessee;
        uint256 leaseStartTime;
        uint256 weeksPaid;
    }

    uint256 public nodeCounter;
    mapping(uint256 => Node) public nodes;

    mapping(address => bool) public blacklisted;

    event NodeRegistered(uint256 nodeId, address owner);
    event NodeLeased(uint256 nodeId, address lessee);
    event RentPaid(uint256 nodeId, address lessee, uint256 weeksPaid);
    event Withdrawn(uint256 nodeId, address to, uint256 amount);
    event NodeUnleased(uint256 nodeId);

    modifier notBlacklisted() {
        require(!blacklisted[msg.sender], "Address is blacklisted");
        _;
    }

    constructor(address _usdt) Ownable(msg.sender){
        usdt = IERC20(_usdt);
    }

    // Register a new node
    function registerNode() external whenNotPaused notBlacklisted {
        nodeCounter++;
        nodes[nodeCounter] = Node({
            owner: msg.sender,
            leased: false,
            lessee: address(0),
            leaseStartTime: 0,
            weeksPaid: 0
        });

        emit NodeRegistered(nodeCounter, msg.sender);
    }

    // Lease a node
    function leaseNode(uint256 _nodeId) external whenNotPaused notBlacklisted {
        Node storage node = nodes[_nodeId];
        require(!node.leased, "Node already leased");
        require(node.owner != msg.sender, "Owner cannot lease their own node");

        node.leased = true;
        node.lessee = msg.sender;
        node.leaseStartTime = block.timestamp;
        node.weeksPaid = 0;

        emit NodeLeased(_nodeId, msg.sender);
    }

    // Pay weekly rent
    function payRent(uint256 _nodeId, uint256 _weeks) external whenNotPaused notBlacklisted {
        Node storage node = nodes[_nodeId];
        require(node.leased, "Node not leased");
        require(msg.sender == node.lessee, "Not lessee");
        require(node.weeksPaid + _weeks <= LEASE_DURATION_WEEKS, "Exceeds lease duration");

        uint256 totalAmount = WEEKLY_RENT * _weeks;
        require(usdt.transferFrom(msg.sender, address(this), totalAmount), "Payment failed");

        node.weeksPaid += _weeks;

        emit RentPaid(_nodeId, msg.sender, node.weeksPaid);

        // Auto-end lease
        if (node.weeksPaid == LEASE_DURATION_WEEKS) {
            node.leased = false;
            node.lessee = address(0);
            node.leaseStartTime = 0;
            emit NodeUnleased(_nodeId);
        }
    }

    // Withdraw earnings by node owner
    function withdraw(uint256 _nodeId) external whenNotPaused {
        Node storage node = nodes[_nodeId];
        require(msg.sender == node.owner, "Not owner");

        uint256 totalEarned = node.weeksPaid * WEEKLY_RENT;
        require(totalEarned > 0, "Nothing to withdraw");

        node.weeksPaid = 0;
        require(usdt.transfer(msg.sender, totalEarned), "Withdraw failed");

        emit Withdrawn(_nodeId, msg.sender, totalEarned);
    }

    // Admin Functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function blacklist(address user, bool value) external onlyOwner {
        blacklisted[user] = value;
    }

    // Emergency withdrawal
    function emergencyWithdrawTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }
}
