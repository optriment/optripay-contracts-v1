// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Marketplace} from "../src/Marketplace.sol";
import {MyToken} from "./MyToken.sol";

contract MarketplaceTest is Test {
    uint256 constant serviceFee = 3;

    // event ServiceFeeChanged(address indexed from, uint256 oldServiceFee, uint256 newServiceFee);
    event BeneficiaryChanged(address indexed from, address oldBeneficiary, address newBeneficiary);
    event ItemAdded(address indexed seller, uint indexed itemId);
    event ItemUpdated(address indexed seller, uint indexed itemId);
    event ItemPurchased(address indexed seller, uint indexed itemId, address indexed buyer);

    Marketplace public marketplace;
    MyToken public token;

    address public tokenOwner;
    address public contractOwner;
    address public beneficiary;
    address public seller1;
    address public seller2;
    address public buyer1;
    address public buyer2;

    function setUp() public {
        tokenOwner = makeAddr("TokenOwner");
        contractOwner = makeAddr("ContractOwner");
        beneficiary = makeAddr("Beneficiary");
        seller1 = makeAddr("Seller 1");
        seller2 = makeAddr("Seller 2");
        buyer1 = makeAddr("Buyer 1");
        buyer2 = makeAddr("Buyer 2");

        vm.prank(tokenOwner);
        token = new MyToken();

        vm.prank(contractOwner);
        marketplace = new Marketplace(address(token), serviceFee);

        vm.label(address(this), "MarketplaceTest");
    }

    function test_Constructor_SetsOwnerToDeployer() public {
        assertEq(marketplace.owner(), contractOwner);
    }

    function test_Constructor_SetsBeneficiaryToDeployer() public {
        assertEq(marketplace.owner(), contractOwner);
    }

    function test_Constructor_SetsToken() public {
        assertEq(address(marketplace.token()), address(token));
    }

    function test_Constructor_SetsServiceFee() public {
        assertEq(marketplace.serviceFee(), 3);
    }

    function test_SetBeneficiary_Reverts_IfCallerIsNotTheOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        marketplace.setBeneficiary(beneficiary);
    }

    function test_SetBeneficiary_Reverts_IfBeneficiaryIsZeroAddress() public {
        vm.expectRevert("Zero address");

        vm.prank(contractOwner);
        marketplace.setBeneficiary(address(0));
    }

    function test_SetBeneficiary_Reverts_IfBeneficiaryIsMarketplace() public {
        vm.expectRevert("Marketplace can not be beneficiary");

        vm.prank(contractOwner);
        marketplace.setBeneficiary(address(marketplace));
    }

    function test_SetBeneficiary_Reverts_IfBeneficiaryIsTheSame() public {
        vm.expectRevert("Nothing to change");

        vm.prank(contractOwner);
        marketplace.setBeneficiary(contractOwner);
    }

    function test_SetBeneficiary_Emits_BeneficiaryChanged(address newBeneficiary) public {
        vm.assume(
            newBeneficiary != address(0) &&
            newBeneficiary != address(marketplace) &&
            newBeneficiary != contractOwner
        );

        vm.expectEmit(true, true, true, true);

        emit BeneficiaryChanged(contractOwner, contractOwner, newBeneficiary);

        vm.prank(contractOwner);
        marketplace.setBeneficiary(newBeneficiary);
    }

    function test_SetBeneficiary_UpdatesBeneficiary(address newBeneficiary) public {
        vm.assume(
            newBeneficiary != address(0) &&
            newBeneficiary != address(marketplace) &&
            newBeneficiary != contractOwner
        );

        vm.prank(contractOwner);
        marketplace.setBeneficiary(newBeneficiary);

        assertEq(marketplace.beneficiary(), newBeneficiary);
    }

    function test_Sell_Reverts_IfPriceIsZero() public {
        vm.expectRevert("Price must be greater than zero");

        vm.prank(seller1);
        marketplace.sell(0, "Title", "");
    }

    function test_Sell_Reverts_IfTitleIsEmpty(uint256 price) public {
        vm.assume(price > 0);

        vm.expectRevert("Title must not be empty");

        vm.prank(seller1);
        marketplace.sell(price, "", "");
    }

    function test_Sell_Emits_ItemAdded(
        uint256 price,
        string memory title,
        string memory redirectTo
    ) public {
        vm.assume(price > 0 && bytes(title).length > 0);

        vm.expectEmit(true, true, true, true);

        emit ItemAdded(seller1, 0);

        vm.prank(seller1);

        marketplace.sell(price, title, redirectTo);
    }

    function test_Sell_AddsNewItem(
        uint256 price,
        string memory title,
        string memory redirectTo
    ) public {
        vm.assume(price > 0 && bytes(title).length > 0);

        vm.startPrank(seller1);

        marketplace.sell(price, title, redirectTo);

        (
            uint256[] memory itemId,
            uint256[] memory itemPrice,
            uint256[] memory itemCreatedAt,
            uint256[] memory itemPurchases,
            string[] memory itemTitle
        ) = marketplace.getMyItems();

        assertEq(itemId.length, 1);

        assertEq(itemId[0], 0);
        assertEq(itemTitle[0], title);
        assertEq(itemPrice[0], price);
        assertEq(itemCreatedAt[0], block.timestamp);
        assertEq(itemPurchases[0], 0);
    }

    function test_UpdateItem_Reverts_IfItemDoesNotExist(uint256 itemId) public {
        vm.expectRevert("Item does not exist");

        marketplace.updateItem(itemId, "", "");
    }

    function test_UpdateItem_Reverts_IfItemBelongsToAnotherSeller() public {
        vm.prank(seller1);
        marketplace.sell(1 ether, "Item", "");

        vm.expectRevert("Only seller");

        vm.prank(seller2);
        marketplace.updateItem(0, "", "");
    }

    function test_UpdateItem_Reverts_IfTitleIsEmpty() public {
        vm.startPrank(seller1);
        marketplace.sell(1 ether, "Item", "");

        vm.expectRevert("Title must not be empty");

        marketplace.updateItem(0, "", "");
    }

    function test_UpdateItem_Emits_ItemUpdated(
        string memory newTitle,
        string memory newRedirectTo
    ) public {
        vm.assume(bytes(newTitle).length > 0);

        vm.expectEmit(true, true, true, true);

        emit ItemUpdated(seller1, 0);

        vm.startPrank(seller1);

        marketplace.sell(1 ether, "Item", "");

        marketplace.updateItem(0, newTitle, newRedirectTo);
    }

    function test_UpdateItem_UpdatesOnlyTitleAndRedirectTo(
        string memory newTitle,
        string memory newRedirectTo
    ) public {
        vm.assume(bytes(newTitle).length > 0);

        vm.startPrank(seller1);

        marketplace.sell(1 ether, "Item", "");

        marketplace.updateItem(0, newTitle, newRedirectTo);

        (
            address itemSeller,
            uint256 itemPrice,
            uint256 itemPurchasesCount,
            string memory itemTitle,
            string memory itemRedirectTo
        ) = marketplace.getItem(0);

        assertEq(itemSeller, seller1);
        assertEq(itemPrice, 1 ether);
        assertEq(itemPurchasesCount, 0);
        assertEq(itemTitle, newTitle);
        assertEq(itemRedirectTo, newRedirectTo);
    }

    function test_Buy_Reverts_IfItemDoesNotExist(uint256 itemId) public {
        vm.expectRevert("Item does not exist");

        vm.prank(buyer1);
        marketplace.buy(itemId);
    }

    function test_Buy_Reverts_IfBuyerDoesNotHaveEnoughTokens(uint256 price) public {
        vm.assume(price > 0);

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.expectRevert("Insufficient balance");

        vm.prank(buyer1);
        marketplace.buy(0);
    }

    function test_Buy_Reverts_IfBuyerDoesNotHaveEnoughAllowance(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        vm.expectRevert("Insufficient allowance");

        vm.prank(buyer1);
        marketplace.buy(0);
    }

    function test_Buy_Emits_ItemPurchased(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        vm.startPrank(buyer1);

        token.approve(address(marketplace), price);

        vm.expectEmit(true, true, true, true);

        emit ItemPurchased(seller1, 0, buyer1);

        marketplace.buy(0);
    }

    function test_Buy_UpdatesTokenBalances(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        assertEq(token.balanceOf(seller1), 0);
        assertEq(token.balanceOf(buyer1), price);

        uint256 feeAmount = price * serviceFee / 100;
        uint256 transferAmount = price - feeAmount;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), transferAmount);
        assertEq(token.balanceOf(buyer1), 0);
        assertEq(token.balanceOf(contractOwner), feeAmount);
    }

    function test_Buy_WhenBeneficiaryChanged_UpdatesTokenBalances(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(contractOwner);
        marketplace.setBeneficiary(beneficiary);

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        assertEq(token.balanceOf(seller1), 0);
        assertEq(token.balanceOf(buyer1), price);
        assertEq(token.balanceOf(contractOwner), 0);
        assertEq(token.balanceOf(beneficiary), 0);

        uint256 feeAmount = price * serviceFee / 100;
        uint256 transferAmount = price - feeAmount;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), transferAmount);
        assertEq(token.balanceOf(buyer1), 0);
        assertEq(token.balanceOf(contractOwner), 0);
        assertEq(token.balanceOf(beneficiary), feeAmount);
    }

    function test_Buy_UpdatesPlatformIncome(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        uint256 feeAmount = price * serviceFee / 100;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.prank(contractOwner);
        assertEq(marketplace.getPlatformTotalIncome(), feeAmount);
    }

    function test_Buy_UpdatesSellerIncome(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        uint256 feeAmount = price * serviceFee / 100;
        uint256 transferAmount = price - feeAmount;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.prank(seller1);
        assertEq(marketplace.getMyIncome(), transferAmount);
    }

    function test_Buy_UpdatesItemPurchases(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        (,, uint256 itemPurchasesCount,,) = marketplace.getItem(0);

        assertEq(itemPurchasesCount, 1);
    }

    function test_Buy_AddPurchaseToBuyer(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.startPrank(buyer1);
        (
            uint256[] memory purchaseId,
            uint256[] memory itemId,
            string[] memory itemTitle,
            uint256[] memory itemPrice,
            uint256[] memory itemPurchaseDate
        ) = marketplace.getMyPurchases();

        assertEq(purchaseId.length, 1);
        assertEq(purchaseId[0], 0);
        assertEq(itemId[0], 0);
        assertEq(itemTitle[0], "Item");
        assertEq(itemPrice[0], price);
        assertEq(itemPurchaseDate[0], block.timestamp);
    }

    function test_Buy_AddsPurchaseToSellerItem(uint256 price) public {
        vm.assume(price > 0 && price <= token.totalSupply());

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, price);

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.startPrank(seller1);
        (
            uint256[] memory purchaseId,
            address[] memory itemBuyer,
            uint256[] memory purchaseDate
        ) = marketplace.getItemPurchases(0);

        assertEq(purchaseId.length, 1);
        assertEq(itemBuyer[0], buyer1);
        assertEq(purchaseDate[0], block.timestamp);
    }

    function test_Buy_WhenItemPurchasedMultipleTimes_ByOneBuyer() public {
        uint256 price = 97 ether;

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.prank(tokenOwner);
        token.transfer(buyer1, 200 ether);

        uint256 feeAmount = price * serviceFee / 100;
        uint256 transferAmount = price - feeAmount;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), transferAmount * 2);
        assertEq(token.balanceOf(buyer1), 6 ether);
        assertEq(token.balanceOf(contractOwner), feeAmount * 2);

        // Updates item purchases count
        (,, uint256 itemPurchasesCount,,) = marketplace.getItem(0);
        assertEq(itemPurchasesCount, 2);

        // Adds seller's item purchases
        vm.startPrank(seller1);
        (
            uint256[] memory purchaseId,
            address[] memory itemBuyer,
            uint256[] memory purchaseDate
        ) = marketplace.getItemPurchases(0);

        assertEq(purchaseId.length, 2);
        assertEq(purchaseId[0], 0);
        assertEq(itemBuyer[0], buyer1);
        assertEq(purchaseDate[0], block.timestamp);
        assertEq(purchaseId[1], 1);
        assertEq(itemBuyer[1], buyer1);
        assertEq(purchaseDate[1], block.timestamp);
        vm.stopPrank();

        // Adds purchases to buyer
        vm.startPrank(buyer1);
        (
            uint256[] memory buyerPurchaseId,
            uint256[] memory itemId,
            string[] memory itemTitle,
            uint256[] memory itemPrice,
            uint256[] memory itemPurchaseDate
        ) = marketplace.getMyPurchases();

        assertEq(buyerPurchaseId.length, 2);

        assertEq(buyerPurchaseId[0], 0);
        assertEq(itemId[0], 0);
        assertEq(itemTitle[0], "Item");
        assertEq(itemPrice[0], price);
        assertEq(itemPurchaseDate[0], block.timestamp);

        assertEq(buyerPurchaseId[1], 1);
        assertEq(itemId[1], 0);
        assertEq(itemTitle[1], "Item");
        assertEq(itemPrice[1], price);
        assertEq(itemPurchaseDate[1], block.timestamp);
        vm.stopPrank();

        // Updates seller's income
        vm.prank(seller1);
        assertEq(marketplace.getMyIncome(), transferAmount * 2);

        // Updates platform's income
        vm.prank(contractOwner);
        assertEq(marketplace.getPlatformTotalIncome(), feeAmount * 2);
    }

    function test_Buy_WhenItemPurchasedMultipleTimes_ByDifferentBuyers() public {
        uint256 price = 97 ether;

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.startPrank(tokenOwner);
        token.transfer(buyer1, 100 ether);
        token.transfer(buyer2, 97 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), 0);
        assertEq(token.balanceOf(buyer1), 100 ether);
        assertEq(token.balanceOf(buyer2), 97 ether);

        uint256 feeAmount = price * serviceFee / 100;
        uint256 transferAmount = price - feeAmount;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.startPrank(buyer2);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), transferAmount * 2);
        assertEq(token.balanceOf(buyer1), 3 ether);
        assertEq(token.balanceOf(buyer2), 0);
        assertEq(token.balanceOf(contractOwner), feeAmount * 2);

        // // Updates item purchases count
        (,, uint256 itemPurchasesCount,,) = marketplace.getItem(0);
        assertEq(itemPurchasesCount, 2);

        // Adds seller's item purchases
        vm.startPrank(seller1);
        (, address[] memory itemBuyer,) = marketplace.getItemPurchases(0);
        assertEq(itemBuyer.length, 2);
        assertEq(itemBuyer[0], buyer1);
        assertEq(itemBuyer[1], buyer2);
        vm.stopPrank();

        // Adds purchases to buyer1
        vm.startPrank(buyer1);
        (uint256[] memory buyer1PurchaseId, uint256[] memory buyer1ItemId,,,) = marketplace.getMyPurchases();
        assertEq(buyer1PurchaseId.length, 1);
        assertEq(buyer1PurchaseId[0], 0);
        assertEq(buyer1ItemId[0], 0);
        vm.stopPrank();

        // Adds purchases to buyer2
        vm.startPrank(buyer2);
        (uint256[] memory buyer2PurchaseId, uint256[] memory buyer2ItemId,,,) = marketplace.getMyPurchases();
        assertEq(buyer2PurchaseId.length, 1);
        assertEq(buyer2PurchaseId[0], 1);
        assertEq(buyer2ItemId[0], 0);
        vm.stopPrank();

        // Updates seller's income
        vm.prank(seller1);
        assertEq(marketplace.getMyIncome(), transferAmount * 2);

        // Updates platform's income
        vm.prank(contractOwner);
        assertEq(marketplace.getPlatformTotalIncome(), feeAmount * 2);
    }

    function test_Buy_WhenBeneficiaryHasBeenChangedBetweenPurchasesOfOneItem() public {
        uint256 price = 97 ether;

        vm.prank(seller1);
        marketplace.sell(price, "Item", "");

        vm.startPrank(tokenOwner);
        token.transfer(buyer1, 100 ether);
        token.transfer(buyer2, 97 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), 0);
        assertEq(token.balanceOf(buyer1), 100 ether);
        assertEq(token.balanceOf(buyer2), 97 ether);
        assertEq(token.balanceOf(contractOwner), 0);
        assertEq(token.balanceOf(beneficiary), 0);

        uint256 feeAmount = price * serviceFee / 100;
        uint256 transferAmount = price - feeAmount;

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.prank(contractOwner);
        marketplace.setBeneficiary(beneficiary);

        vm.startPrank(buyer2);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        assertEq(token.balanceOf(seller1), transferAmount * 2);
        assertEq(token.balanceOf(buyer1), 3 ether);
        assertEq(token.balanceOf(buyer2), 0);
        assertEq(token.balanceOf(contractOwner), feeAmount);
        assertEq(token.balanceOf(beneficiary), feeAmount);
    }

    function test_GetMyItems_WhenThereAreNoItems_ReturnsEmptyResult() public {
        (uint256[] memory itemId,,,,) = marketplace.getMyItems();

        assertEq(itemId.length, 0);
    }

    function test_GetMyItems_WhenThereAreItemsBelongToDifferentPeople_ReturnsOnlyMyItems() public {
        vm.startPrank(seller1);
        marketplace.sell(0.1 ether, "Item 1", "");
        marketplace.sell(0.2 ether, "Item 2", "");
        vm.stopPrank();

        vm.startPrank(seller2);
        marketplace.sell(0.3 ether, "Item 3", "");
        vm.stopPrank();

        vm.startPrank(seller1);
        marketplace.sell(0.4 ether, "Item 4", "");

        (
            uint256[] memory itemId,
            uint256[] memory itemPrice,
            uint256[] memory itemCreatedAt,
            uint256[] memory itemPurchases,
            string[] memory itemTitle
        ) = marketplace.getMyItems();

        assertEq(itemId.length, 3);

        assertEq(itemId[0], 0);
        assertEq(itemTitle[0], "Item 1");
        assertEq(itemPrice[0], 0.1 ether);
        assertEq(itemCreatedAt[0], block.timestamp);
        assertEq(itemPurchases[0], 0);

        assertEq(itemId[1], 1);
        assertEq(itemTitle[1], "Item 2");
        assertEq(itemPrice[1], 0.2 ether);
        assertEq(itemCreatedAt[1], block.timestamp);
        assertEq(itemPurchases[1], 0);

        assertEq(itemId[2], 3);
        assertEq(itemTitle[2], "Item 4");
        assertEq(itemPrice[2], 0.4 ether);
        assertEq(itemCreatedAt[2], block.timestamp);
        assertEq(itemPurchases[2], 0);
    }

    function test_GetMyPurchases_WhenThereAreNoPurchases_ReturnsEmptyResult() public {
        (uint256[] memory purchaseId,,,,) = marketplace.getMyPurchases();

        assertEq(purchaseId.length, 0);
    }

    function test_GetMyPurchases_WhenThereAreManyPurchases_ReturnsOnlyMyPurchases() public {
        uint256 price = 94 ether;

        vm.startPrank(seller1);
        marketplace.sell(price, "Item 1", "");
        marketplace.sell(price, "Item 2", "");
        vm.stopPrank();

        vm.startPrank(tokenOwner);
        token.transfer(buyer1, price * 2);
        token.transfer(buyer2, price * 2);
        vm.stopPrank();

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(0);
        vm.stopPrank();

        vm.startPrank(buyer2);
        token.approve(address(marketplace), price * 2);
        marketplace.buy(0);
        marketplace.buy(0);
        vm.stopPrank();

        vm.startPrank(buyer1);
        token.approve(address(marketplace), price);
        marketplace.buy(1);
        vm.stopPrank();

        vm.startPrank(buyer1);
        (uint256[] memory buyerPurchaseId, uint256[] memory itemId, ,,) = marketplace.getMyPurchases();
        assertEq(buyerPurchaseId.length, 2);
        assertEq(buyerPurchaseId[0], 0);
        assertEq(itemId[0], 0);
        assertEq(buyerPurchaseId[1], 3);
        assertEq(itemId[1], 1);
        vm.stopPrank();
    }

    function test_GetItem_Reverts_IfItemDoesNotExist() public {
        vm.expectRevert("Item does not exist");

        marketplace.getItem(0);
    }

    function test_GetItem_ReturnsItem() public {
        vm.prank(seller1);
        marketplace.sell(1 ether, "Item", "http://localhost:3000");

        (
            address itemSeller,
            uint256 itemPrice,
            uint256 itemPurchases,
            string memory itemTitle,
            string memory itemRedirectTo
        ) = marketplace.getItem(0);

        assertEq(itemSeller, seller1);
        assertEq(itemTitle, "Item");
        assertEq(itemPrice, 1 ether);
        assertEq(itemPurchases, 0);
        assertEq(itemRedirectTo, "http://localhost:3000");

        marketplace.getItem(0);
    }

    function test_GetItemPurchases_Reverts_IfItemDoesNotExist() public {
        vm.expectRevert("Item does not exist");

        marketplace.getItemPurchases(0);
    }

    function test_GetItemPurchases_Reverts_IfCallerIsNotTheSeller() public {
        vm.prank(seller1);
        marketplace.sell(1 ether, "Item", "");

        vm.expectRevert("Only seller");
        marketplace.getItemPurchases(0);
    }

    function test_GetItemPurchases_WhenThereAreNoItemPurchases_ReturnsEmptyResult() public {
        vm.startPrank(seller1);

        marketplace.sell(1 ether, "Item", "");

        marketplace.getItemPurchases(0);

        (uint256[] memory purchaseId,,) = marketplace.getItemPurchases(0);
        assertEq(purchaseId.length, 0);
    }

    function test_GetItemPurchases_WhenThereAreItemPurchases_ReturnsOnlyItemPurchases() public {
        vm.startPrank(seller1);
        marketplace.sell(1 ether, "Item 1", "");
        marketplace.sell(2 ether, "Item 2", "");
        vm.stopPrank();

        vm.startPrank(tokenOwner);
        token.transfer(buyer1, 4 ether);
        vm.stopPrank();

        vm.startPrank(buyer1);
        token.approve(address(marketplace), 4 ether);
        marketplace.buy(0);
        marketplace.buy(1);
        marketplace.buy(0);
        vm.stopPrank();

        vm.startPrank(seller1);

        (uint256[] memory purchaseId, address[] memory soldItemToBuyer,) = marketplace.getItemPurchases(0);

        assertEq(purchaseId.length, 2);
        assertEq(purchaseId[0], 0);
        assertEq(soldItemToBuyer[0], buyer1);
        assertEq(purchaseId[1], 2);
        assertEq(soldItemToBuyer[1], buyer1);
    }

    function test_GetMyIncome_WhenThereAreNoPurchases_ReturnsZero() public {
        assertEq(marketplace.getMyIncome(), 0);
    }

    function test_GetMyIncome_WhenThereArePurchases_ReturnsMyIncome() public {
        vm.startPrank(seller1);
        marketplace.sell(1 ether, "Item 1", "");
        marketplace.sell(2 ether, "Item 2", "");
        vm.stopPrank();

        vm.startPrank(tokenOwner);
        token.transfer(buyer1, 4 ether);
        vm.stopPrank();

        vm.startPrank(buyer1);
        token.approve(address(marketplace), 4 ether);
        marketplace.buy(0);
        marketplace.buy(1);
        marketplace.buy(0);
        vm.stopPrank();

        uint256 item1FeeAmount = 1 ether * serviceFee / 100;
        uint256 item1TransferAmount = 1 ether - item1FeeAmount;

        uint256 item2FeeAmount = 2 ether * serviceFee / 100;
        uint256 item2TransferAmount = 2 ether - item2FeeAmount;

        vm.prank(seller1);
        assertEq(marketplace.getMyIncome(), item1TransferAmount * 2 + item2TransferAmount);
    }

    function test_GetPlatformTotalIncome_Reverts_IfCallerIsNotTheOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        assertEq(marketplace.getPlatformTotalIncome(), 0);
    }

    function test_GetPlatformTotalIncome_WhenThereAreNoPurchases_ReturnsZero() public {
        vm.prank(contractOwner);
        assertEq(marketplace.getPlatformTotalIncome(), 0);
    }

    function test_GetPlatformTotalIncome_WhenThereArePurchases_ReturnsPlatformIncome() public {
        vm.startPrank(seller1);
        marketplace.sell(1 ether, "Item 1", "");
        marketplace.sell(2 ether, "Item 2", "");
        vm.stopPrank();

        vm.startPrank(tokenOwner);
        token.transfer(buyer1, 4 ether);
        vm.stopPrank();

        vm.startPrank(buyer1);
        token.approve(address(marketplace), 4 ether);
        marketplace.buy(0);
        marketplace.buy(1);
        marketplace.buy(0);
        vm.stopPrank();

        uint256 item1FeeAmount = 1 ether * serviceFee / 100;
        uint256 item2FeeAmount = 2 ether * serviceFee / 100;

        vm.prank(contractOwner);
        assertEq(marketplace.getPlatformTotalIncome(), item1FeeAmount * 2 + item2FeeAmount);
    }
}
