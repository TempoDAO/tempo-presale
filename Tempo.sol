// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TempoSale is Ownable {
    using SafeERC20 for ERC20;
    using Address for address;
//Change values
    uint constant MIMdecimals = 10 ** 18;
    uint constant Tempodecimals = 10 ** 9;
    uint public constant MAX_SOLD = 75000 * Tempodecimals;
    uint public constant PRICE = 4 * MIMdecimals / Tempodecimals ;
    uint public constant MIN_PRESALE_PER_ACCOUNT = 50 * Tempodecimals;
    uint public constant MAX_PRESALE_PER_ACCOUNT = 250 * Tempodecimals;
    address public owners;
    ERC20 MIM;

    uint public sold;
    address public Tempo;
    bool canClaim;
    bool publicSale;
    bool privateSale;
    address[] devAddr = [0x3F9A6ec4bd789Ad86f360c81F2ba7bb4c55aA2c6, 0x1a70b7159372bac2f86E27741f62d89b71AA5bd2,
         0xa850a1e5F50aFcdB59a96e4444372B44b756a792];
    mapping( address => uint256 ) public invested;
    mapping( address => uint ) public dailyClaimed;
    mapping( address => bool ) public approvedBuyers;
    mapping( address => uint256) public amountPerClaim;

    constructor() {
        //MIM CONTRACT ADDRESS
        MIM = ERC20(0x130966628846BFd36ff31a822705796e8cb8C18D);
        owners = msg.sender;
        sold = 0;
        //DEV REWARDS
        for( uint256 iteration_ = 0; devAddr.length > iteration_; iteration_++ ) {
            invested[ devAddr[ iteration_ ] ] = 4000 * Tempodecimals;
        } 
    }
    /* check if it's not a contract */
    modifier onlyEOA() {
        require(msg.sender == tx.origin, "!EOA");
        _;
    }

    /* approving buyers into whitelist */

    function _approveBuyer( address newBuyer_ ) internal onlyOwner() returns ( bool ) {
        approvedBuyers[newBuyer_] = true;
        return approvedBuyers[newBuyer_];
    }

    function approveBuyer( address newBuyer_ ) external onlyOwner() returns ( bool ) {
        return _approveBuyer( newBuyer_ );
    }

    function approveBuyers( address[] calldata newBuyers_ ) external onlyOwner() returns ( uint256 ) {
        for( uint256 iteration_ = 0; newBuyers_.length > iteration_; iteration_++ ) {
            _approveBuyer( newBuyers_[iteration_] );
        }
        return newBuyers_.length;
    }

    /* deapproving buyers into whitelist */

    function _deapproveBuyer( address newBuyer_ ) internal onlyOwner() returns ( bool ) {
        approvedBuyers[newBuyer_] = false;
        return approvedBuyers[newBuyer_];
    }

    function deapproveBuyer( address newBuyer_ ) external onlyOwner() returns ( bool ) {
        return _deapproveBuyer(newBuyer_);
    }

    function amountBuyable(address buyer) public view returns (uint256) {
        uint256 max;
        if ( (approvedBuyers[buyer] && privateSale) || publicSale ) {
            max = MAX_PRESALE_PER_ACCOUNT;
        }
        return max - invested[buyer];
    }

    function buyTempo(uint256 amount) public onlyEOA {
        require(sold < MAX_SOLD, "sold out");
        require(sold + amount < MAX_SOLD, "not enough remaining");
        require(amount <= amountBuyable(msg.sender), "amount exceeds buyable amount");
        require(amount + invested[msg.sender] >= MIN_PRESALE_PER_ACCOUNT, "amount is not sufficient");
        MIM.safeTransferFrom( msg.sender, address(this), amount * PRICE );
        invested[msg.sender] += amount;
        sold += amount;
    }

    // set Tempo token address and activate claiming
    function setClaimingActive(address tempo) public {
        require(msg.sender == owners, "not owners");
        Tempo = tempo;
        canClaim = true;
    }

    //Check if you are in DEV address
    function isDev(address devAddr_) public view returns ( bool ) {
        if ( devAddr_ == devAddr[0] || devAddr_ == devAddr[1] || devAddr_ == devAddr[2]) {
            return true;
        } 
        return false;
    }
    // claim Tempo allocation based on invested amounts
    function claimTempo() public onlyEOA {
        require(canClaim, "Cannot claim now");
        require(invested[msg.sender] > 0, "no claim avalaible");
        require(dailyClaimed[msg.sender] < block.timestamp, "cannot claimed now");
        if (dailyClaimed[msg.sender] == 0) {
            dailyClaimed[msg.sender] = block.timestamp;
            amountPerClaim[msg.sender] = (isDev(msg.sender) ? invested[msg.sender] * 5 / 100 : invested[msg.sender] * 20 / 100);
        }
        
        if (isDev(msg.sender)) {
            ERC20(Tempo).transfer(msg.sender, amountPerClaim[msg.sender]);
            invested[msg.sender] -= amountPerClaim[msg.sender];
            dailyClaimed[msg.sender] += 604800;
        } else {
            ERC20(Tempo).transfer(msg.sender, amountPerClaim[msg.sender]);
            invested[msg.sender] -= amountPerClaim[msg.sender];
            dailyClaimed[msg.sender] += 86400;
        }
    }

    // token withdrawal by owners
    function withdraw(address _token) public {
        require(msg.sender == owners, "not owners");
        uint b = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(owners,b);
    }

    // manual activation of public presales
    function activatePublicSale() public {
        require(msg.sender == owners, "not owners");
        publicSale = true;
    }
    // manual deactivation of public presales
    function deactivatePublicSale() public {
        require(msg.sender == owners, "not owners");
        publicSale = false;
    }

    // manual activation of whitelisted sales
    function activatePrivateSale() public {
        require(msg.sender == owners, "not owners");
        privateSale = true;
    }

    // manual deactivation of whitelisted sales
    function deactivatePrivateSale() public {
        require(msg.sender == owners, "not owners");
        privateSale = false;
    }

    function setSold(uint _soldAmount) public {
        require(msg.sender == owners, "not owners");
        sold = _soldAmount;
    }

    /*DEV TEST*//*
    function claimNow(address addr) public onlyOwner {
        dailyClaimed[addr] = block.timestamp;
    }*/
}