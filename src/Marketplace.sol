// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Item {
    string title;
    string redirectTo;
    address seller;
    uint256 price;
    uint256 createdAt;
    uint256 purchases;
}

struct Purchase {
    string title;
    address buyer;
    uint256 itemId;
    uint256 price;
    uint256 date;
}

// TODO: Add limit of items to each seller (e.g. 100 items per person)
contract Marketplace is Ownable {
    using SafeMath for uint256;

    uint256 constant MIN_SERVICE_FEE = 1;
    uint256 constant MAX_SERVICE_FEE = 5;

    address public beneficiary;
    IERC20 public immutable token;
    uint256 public immutable serviceFee;

    event BeneficiaryChanged(address indexed from, address oldBeneficiary, address newBeneficiary);
    event ItemAdded(address indexed seller, uint indexed itemId);
    event ItemUpdated(address indexed seller, uint indexed itemId);
    event ItemPurchased(address indexed seller, uint indexed itemId, address indexed buyer);

    mapping (uint256 => Item) private items;
    uint256 private itemCount;

    mapping (uint256 => Purchase) private purchases;
    uint256 private purchaseCount;

    mapping(address => uint256[]) private myItems;
    mapping(address => uint256[]) private myPurchases;
    mapping(address => mapping(uint256 => uint256[])) private purchasesBySellerItem;
    mapping(address => uint256) private incomeBySeller;
    uint256 private platformTotalIncome;

    constructor(address _tokenAddress, uint256 _serviceFee) {
        require(address(_tokenAddress) != address(0), "Invalid Token Address");
        require(_serviceFee >= MIN_SERVICE_FEE && _serviceFee <= MAX_SERVICE_FEE, "Invalid service fee range");

        token = IERC20(_tokenAddress);
        serviceFee = _serviceFee;
        beneficiary = msg.sender;
    }

    // FIXME: Update with two-phase commit
    function setBeneficiary(address newBeneficiary) external onlyOwner {
        require(newBeneficiary != address(0), "Zero address");
        require(newBeneficiary != address(this), "Marketplace can not be beneficiary");
        require(newBeneficiary != beneficiary, "Nothing to change");

        emit BeneficiaryChanged(msg.sender, beneficiary, newBeneficiary);

        beneficiary = newBeneficiary;
    }

    function sell(uint256 price, string memory title, string memory redirectTo) external {
        require(price > 0, "Price must be greater than zero");
        require(bytes(title).length > 0, "Title must not be empty");

        emit ItemAdded(msg.sender, itemCount);

        items[itemCount] = Item({
            price: price,
            title: title,
            seller: msg.sender,
            createdAt: block.timestamp,
            purchases: 0,
            redirectTo: redirectTo
        });

        myItems[msg.sender].push(itemCount);
        itemCount++;
    }

    function updateItem(uint256 itemId, string memory title, string memory redirectTo) external {
        require(items[itemId].seller != address(0), "Item does not exist");

        Item storage item = items[itemId];

        require(item.seller == msg.sender, "Only seller");

        require(bytes(title).length > 0, "Title must not be empty");

        emit ItemUpdated(msg.sender, itemId);

        item.title = title;
        item.redirectTo = redirectTo;
    }

    function buy(uint256 itemId) external {
        require(items[itemId].seller != address(0), "Item does not exist");

        Item storage item = items[itemId];

        require(token.balanceOf(msg.sender) >= item.price, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= item.price, "Insufficient allowance");

        uint256 feeAmount = item.price.mul(serviceFee).div(100);
        uint transferAmount = item.price - feeAmount;

        require(token.transferFrom(msg.sender, item.seller, transferAmount), "Failed to transfer service payment.");
        require(token.transferFrom(msg.sender, beneficiary, feeAmount), "Failed to transfer service fee.");

        emit ItemPurchased(item.seller, itemId, msg.sender);

        platformTotalIncome += feeAmount;
        item.purchases++;
        incomeBySeller[item.seller] += transferAmount;

        purchases[purchaseCount] = Purchase({
            itemId: itemId,
            buyer: msg.sender,
            title: item.title,
            price: item.price,
            date: block.timestamp
        });

        myPurchases[msg.sender].push(purchaseCount);
        purchasesBySellerItem[item.seller][itemId].push(purchaseCount);
        purchaseCount++;
    }

    function getMyItems() external view returns (
        uint256[] memory itemId,
        uint256[] memory itemPrice,
        uint256[] memory itemCreatedAt,
        uint256[] memory itemPurchases,
        // string must be in the end
        string[] memory itemTitle
    ) {
        uint256 myItemsCount = myItems[msg.sender].length;

        itemId = new uint256[](myItemsCount);
        itemTitle = new string[](myItemsCount);
        itemPrice = new uint256[](myItemsCount);
        itemCreatedAt = new uint256[](myItemsCount);
        itemPurchases = new uint256[](myItemsCount);

        uint256 index = 0;
        uint256 myItemIndex = 0;

        while (index < myItemsCount) {
            myItemIndex = myItems[msg.sender][index];

            Item memory item = items[myItemIndex];

            require(item.seller == msg.sender, "Access denied");

            itemId[index] = myItemIndex;
            itemTitle[index] = item.title;
            itemPrice[index] = item.price;
            itemCreatedAt[index] = item.createdAt;
            itemPurchases[index] = item.purchases;

            unchecked {
                ++index;
            }
        }
    }

    function getMyPurchases() external view returns (
        uint256[] memory purchaseId,
        uint256[] memory itemId,
        string[] memory title,
        uint256[] memory price,
        uint256[] memory date
    ) {
        uint256 myPurchasesCount = myPurchases[msg.sender].length;

        purchaseId = new uint256[](myPurchasesCount);
        itemId = new uint256[](myPurchasesCount);
        title = new string[](myPurchasesCount);
        price = new uint256[](myPurchasesCount);
        date = new uint256[](myPurchasesCount);

        uint256 index = 0;
        uint256 myPurchaseIndex = 0;

        while (index < myPurchasesCount) {
            myPurchaseIndex = myPurchases[msg.sender][index];

            require(purchases[myPurchaseIndex].buyer == msg.sender, "Access denied");

            purchaseId[index] = myPurchaseIndex;
            itemId[index] = purchases[myPurchaseIndex].itemId;
            title[index] = purchases[myPurchaseIndex].title;
            price[index] = purchases[myPurchaseIndex].price;
            date[index] = purchases[myPurchaseIndex].date;

            unchecked {
                ++index;
            }
        }
    }

    function getItem(uint256 itemId) external view returns (
        address seller,
        uint256 price,
        uint256 purchasesCount,
        string memory title,
        string memory redirectTo
    ) {
        require(items[itemId].seller != address(0), "Item does not exist");

        seller = items[itemId].seller;
        price = items[itemId].price;
        title = items[itemId].title;
        purchasesCount = items[itemId].purchases;
        redirectTo = items[itemId].redirectTo;
    }

    function getItemPurchases(uint256 itemId) external view returns (
        uint256[] memory purchaseId,
        address[] memory buyer,
        uint256[] memory date
    ) {
        require(items[itemId].seller != address(0), "Item does not exist");

        Item memory item = items[itemId];

        require(item.seller == msg.sender, "Only seller");

        uint256 itemPurchasesCount = item.purchases;

        purchaseId = new uint256[](itemPurchasesCount);
        buyer = new address[](itemPurchasesCount);
        date = new uint256[](itemPurchasesCount);

        uint256 index = 0;
        uint256 purchaseIndex = 0;

        while (index < itemPurchasesCount) {
            purchaseIndex = purchasesBySellerItem[msg.sender][itemId][index];

            purchaseId[index] = purchaseIndex;
            buyer[index] = purchases[purchaseIndex].buyer;
            date[index] = purchases[purchaseIndex].date;

            unchecked {
                ++index;
            }
        }
    }

    function getMyIncome() external view returns (uint256) {
        return incomeBySeller[msg.sender];
    }

    function getPlatformTotalIncome() external view onlyOwner returns (uint256) {
        return platformTotalIncome;
    }
}
