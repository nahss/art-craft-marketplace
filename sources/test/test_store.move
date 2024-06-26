#[test_only]
module ArtCraft::test_product {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::transfer;
    use sui::test_utils::{assert_eq};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::transfer_policy::{Self as tp, TransferPolicy, TransferPolicyCap};
    use sui::object;
    use sui::sui::SUI;
    use sui::coin::{mint_for_testing};
    use sui::coin::{Self, Coin}; 
    use std::string::{Self};
    use std::vector;
     use std::option::{Self, Option};
    // use std::debug;

    use ArtCraft::game::{Self as art, Product, ProductPublisher};
    use ArtCraft::floor_price_rule::{Self};
    use ArtCraft::royalty_rule::{Self};
    use ArtCraft::helpers::{init_test_helper};

    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    const TEST_ADDRESS2: address = @0xC;


    #[test]
    public fun test_create_kiosk() {
        let scenario_test = init_test_helper();
        let scenario = &mut scenario_test;
        // Create an kiosk for marketplace
        next_tx(scenario, TEST_ADDRESS1);
        {
           let cap =  art::new(ts::ctx(scenario));
           transfer::public_transfer(cap, TEST_ADDRESS1);
        };

         // create an policy
        next_tx(scenario, TEST_ADDRESS1);
        {
            let publisher = ts::take_shared<ProductPublisher>(scenario);
            art::new_policy(&publisher, ts::ctx(scenario));

            ts::return_shared(publisher);
        };
        
        // add rule
        next_tx(scenario, TEST_ADDRESS1);
        {
            let policy = ts::take_shared<TransferPolicy<Product>>(scenario);
            let cap = ts::take_from_sender<TransferPolicyCap<Product>>(scenario);
            let amount_bp: u16 = 100;
            let min_amount: u64 = 0;

            royalty_rule::add(&mut policy, &cap, amount_bp, min_amount);
           
            ts::return_to_sender(scenario, cap);
            ts::return_shared(policy);
        };

        // create an product NFT
        next_tx(scenario, TEST_ADDRESS1);
        {
            let str1 = string::utf8(b"asd");
            let str2 = string::utf8(b"asd");
            let str3 = string::utf8(b"asd");
            let num1: u64 = 1;
            let num2: u64 = 2;
        
            let product = art::new_product(str1, str2, num1, num2, str3, ts::ctx(scenario));

            transfer::public_transfer(product, TEST_ADDRESS1);
        };

        let nft_data = next_tx(scenario, TEST_ADDRESS1);
        
        // Place the product NFT to kiosk
        next_tx(scenario, TEST_ADDRESS1);
        {
            let product_ = ts::take_from_sender<Product>(scenario);
            let kiosk_cap = ts::take_from_sender<KioskOwnerCap>(scenario);
            let kiosk =  ts::take_shared<Kiosk>(scenario);
            // get item id from effects
            let id_ = ts::created(&nft_data);
            let item_id = vector::borrow(&id_, 0);
        
            kiosk::place(&mut kiosk, &kiosk_cap, product_);

            assert_eq(kiosk::item_count(&kiosk), 1);

            assert_eq(kiosk::has_item(&kiosk, *item_id), true);
            assert_eq(kiosk::is_locked(&kiosk, *item_id), false);
            assert_eq(kiosk::is_listed(&kiosk, *item_id), false);

            ts::return_shared(kiosk);
            ts::return_to_sender(scenario, kiosk_cap);
        };

        // List the product NFT to kiosk
        next_tx(scenario, TEST_ADDRESS1);
        {
            let kiosk_cap = ts::take_from_sender<KioskOwnerCap>(scenario);
            let kiosk =  ts::take_shared<Kiosk>(scenario);
            let price : u64 = 1000_000_000_000;
            // get item id from effects
            let id_ = ts::created(&nft_data);
            let item_id = vector::borrow(&id_, 0);
        
            kiosk::list<Product>(&mut kiosk, &kiosk_cap, *item_id, price);

            assert_eq(kiosk::item_count(&kiosk), 1);

            assert_eq(kiosk::has_item(&kiosk, *item_id), true);
            assert_eq(kiosk::is_locked(&kiosk, *item_id), false);
            assert_eq(kiosk::is_listed(&kiosk, *item_id), true);

            ts::return_shared(kiosk);
            ts::return_to_sender(scenario, kiosk_cap);
        };

        // purchase the item
        next_tx(scenario, TEST_ADDRESS2);
        {
            let kiosk =  ts::take_shared<Kiosk>(scenario);
            let policy = ts::take_shared<TransferPolicy<Product>>(scenario);
            let price  = mint_for_testing<SUI>(1000_000_000_000, ts::ctx(scenario));
            let royalty_price  = mint_for_testing<SUI>(10_000_000_000, ts::ctx(scenario));
            // get item id from effects
            let id_ = ts::created(&nft_data);
            let item_id = vector::borrow(&id_, 0);
        
            let (item, request) = kiosk::purchase<Product>(&mut kiosk, *item_id, price);

            royalty_rule::pay(&mut policy, &mut request, royalty_price);
            // confirm the request. Destroye the hot potato
            let (item_id, paid, from ) = tp::confirm_request(&policy, request);

            assert_eq(kiosk::item_count(&kiosk), 0);
            assert_eq(kiosk::has_item(&kiosk, item_id), false);

            transfer::public_transfer(item, TEST_ADDRESS2);
         
            ts::return_shared(kiosk);
            ts::return_shared(policy);
        };
        // withdraw royalty amount from TP
       next_tx(scenario, TEST_ADDRESS1);
        {
            let cap = ts::take_from_sender<TransferPolicyCap<Product>>(scenario);
            let policy = ts::take_shared<TransferPolicy<Product>>(scenario);
            let amount = option::none();
            option::fill(&mut amount, 10_000_000_000);

            let coin_ = tp::withdraw(&mut policy, &cap, amount, ts::ctx(scenario));

            transfer::public_transfer(coin_, TEST_ADDRESS1);
        
            ts::return_to_sender(scenario, cap);
            ts::return_shared(policy);
        };   
        // withdraw from kiosk 
        next_tx(scenario, TEST_ADDRESS1);
        {
            let kiosk =  ts::take_shared<Kiosk>(scenario);
            let cap = ts::take_from_sender<KioskOwnerCap>(scenario);
            let amount = option::none();
            option::fill(&mut amount, 1000_000_000_000);

            let coin_ = kiosk::withdraw(&mut kiosk, &cap, amount, ts::ctx(scenario));

            transfer::public_transfer(coin_, TEST_ADDRESS1);

            ts::return_shared(kiosk);
            ts::return_to_sender(scenario, cap);
        };        
        ts::end(scenario_test);
    }
}
