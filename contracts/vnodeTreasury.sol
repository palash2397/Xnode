// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

//    /$$   /$$ /$$   /$$  /$$$$$$  /$$$$$$$  /$$$$$$$$
//   | $$  / $$| $$$ | $$ /$$__  $$| $$__  $$| $$_____/
//   |  $$/ $$/| $$$$| $$| $$  \ $$| $$  \ $$| $$
//    \  $$$$/ | $$ $$ $$| $$  | $$| $$  | $$| $$$$$
//     >$$  $$ | $$  $$$$| $$  | $$| $$  | $$| $$__/
//    /$$/\  $$| $$\  $$$| $$  | $$| $$  | $$| $$
//   | $$  \ $$| $$ \  $$|  $$$$$$/| $$$$$$$/| $$$$$$$$
//   |__/  |__/|__/  \__/ \______/ |_______/ |________/




import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract VnodeTreasury is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant TREASURY_ADMIN_ROLE = keccak256("TREASURY_ADMIN_ROLE");
    bytes32 public constant ICO_CONTRACT_ROLE = keccak256("ICO_CONTRACT_ROLE");

    address public adminWallet;

    event ReceivedETH(address indexed from, uint256 amount);
    event TransferredETH(address indexed to, uint256 amount);
    event TransferredToken(address indexed token, address indexed to, uint256 amount);
    event AdminWalletUpdated(address oldWallet, address newWallet);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    event Pausedd(address by);
    event Unpausedd(address by);

    constructor(address _adminWallet) {
        require(_adminWallet != address(0), "Invalid admin wallet");
        adminWallet = _adminWallet;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_ADMIN_ROLE, msg.sender);
    }

    receive() external payable {
        emit ReceivedETH(msg.sender, msg.value);
    }

    modifier onlyAdminOrICO() {
        require(
            hasRole(TREASURY_ADMIN_ROLE, msg.sender) || hasRole(ICO_CONTRACT_ROLE, msg.sender),
            "Not authorized"
        );
        _;
    }

    function setAdminWallet(address _newAdminWallet) external onlyRole(TREASURY_ADMIN_ROLE) {
        require(_newAdminWallet != address(0), "Invalid address");
        emit AdminWalletUpdated(adminWallet, _newAdminWallet);
        adminWallet = _newAdminWallet;
    }

    function pause() external onlyRole(TREASURY_ADMIN_ROLE) {
        _pause();
        emit Pausedd(msg.sender);
    }

    function unpause() external onlyRole(TREASURY_ADMIN_ROLE) {
        _unpause();
        emit Unpausedd(msg.sender);
    }

    function withdrawETH(uint256 amount) external onlyAdminOrICO nonReentrant whenNotPaused {
        require(address(this).balance >= amount, "Insufficient ETH");
        payable(adminWallet).transfer(amount);
        emit TransferredETH(adminWallet, amount);
    }

    function withdrawToken(address token, uint256 amount) external onlyAdminOrICO nonReentrant whenNotPaused {
        require(token != address(0), "Invalid token address");
        IERC20(token).safeTransfer(adminWallet, amount);
        emit TransferredToken(token, adminWallet, amount);
    }

    function emergencyWithdraw(address token, address to, uint256 amount)
        external
        onlyRole(TREASURY_ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "Invalid to address");

        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH");
            payable(to).transfer(amount);
            emit EmergencyWithdrawal(address(0), to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
            emit EmergencyWithdrawal(token, to, amount);
        }
    }

    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function grantICORole(address icoContract) external onlyRole(TREASURY_ADMIN_ROLE) {
        require(icoContract != address(0), "Invalid ICO contract");
        _grantRole(ICO_CONTRACT_ROLE, icoContract);
    }

    function revokeICORole(address icoContract) external onlyRole(TREASURY_ADMIN_ROLE) {
        _revokeRole(ICO_CONTRACT_ROLE, icoContract);
    }
}

