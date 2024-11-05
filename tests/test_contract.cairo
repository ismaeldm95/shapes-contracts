use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use shapes_contracts::IShapesGameSafeDispatcher;
use shapes_contracts::IShapesGameSafeDispatcherTrait;


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
#[feature("gameplay")]
fn test_solve_shape_increases_next_shape_index() {

    let contract_address = deploy_contract("ShapesGame");

    let safe_dispatcher = IShapesGameSafeDispatcher { contract_address };

    let caller_address = 123.try_into().unwrap();

    start_cheat_caller_address(contract_address, caller_address);

    let next_shape_index = safe_dispatcher.getLastPlayedIndex(caller_address).unwrap();


    assert(next_shape_index == 0, 'Invalid next shape index');


    let shapes = safe_dispatcher.getCurrentGameCompoundShapes().unwrap();
    let shape1 = shapes.at(0).clone();


    safe_dispatcher.solve(shape1).unwrap();


    let next_shape_index2 = safe_dispatcher.getLastPlayedIndex(caller_address).unwrap();

    assert(next_shape_index2 == 1, 'Invalid next shape index');

}


#[test]
#[feature("gameplay")]
fn test_can_play_game() {

    let contract_address = deploy_contract("ShapesGame");

    let safe_dispatcher = IShapesGameSafeDispatcher { contract_address };

    let caller_address = 123.try_into().unwrap();

    start_cheat_caller_address(contract_address, caller_address);

    let next_shape_index = safe_dispatcher.getLastPlayedIndex(caller_address).unwrap();

    assert(next_shape_index == 0, 'Invalid next shape index');


    let shapes = safe_dispatcher.getCurrentGameCompoundShapes().unwrap();

    let mut i: u32 = 0;
    loop {
        if i >= shapes.len() {
            break;
        }
        let shape = shapes.at(i).clone();
        safe_dispatcher.solve(shape).unwrap();
        i += 1;
    };


    let canPlayGame = safe_dispatcher.canPlayGame(caller_address).unwrap();

    assert(canPlayGame == false, 'User can  play game');

}


#[test]
#[feature("gameplay")]
fn test_right_score_for_solution() {

    let contract_address = deploy_contract("ShapesGame");

    let safe_dispatcher = IShapesGameSafeDispatcher { contract_address };

    let caller_address = 123.try_into().unwrap();

    start_cheat_caller_address(contract_address, caller_address);

    let next_shape_index = safe_dispatcher.getLastPlayedIndex(caller_address).unwrap();

    assert(next_shape_index == 0, 'Invalid next shape index');


    let shapes = safe_dispatcher.getCurrentGameCompoundShapes().unwrap();

    let mut i: u32 = 0;
    loop {
        if i >= shapes.len() {
            break;
        }
        let shape = shapes.at(i).clone();
        safe_dispatcher.solve(shape).unwrap();
        i += 1;
    };


    let allGamesForAccount : Array<(felt252, u32, u64, Array<Array<u8>>, Array<Array<u8>>, felt252)> = safe_dispatcher.getAllGamesForAccount(caller_address).unwrap();

    println!("allGamesForAccount: {:?}", @allGamesForAccount.at(0).3);
    // let game_solutions = allGamesForAccount.at(0).3;
    // let account_solutions = allGamesForAccount.at(0).4;

    // for i in 0..game_solutions.len() {
    //     assert(game_solutions.at(i) == account_solutions.at(i), "Solutions are not the same");
    // };
    assert(allGamesForAccount.len() == 1, 'User has not played any games');

}



#[test]
#[feature("gameplay")]
fn test_number_of_compound_shapes_per_game() {
    let contract_address = deploy_contract("ShapesGame");

    let safe_dispatcher = IShapesGameSafeDispatcher { contract_address };

    let compound_shapes = safe_dispatcher.getCurrentGameCompoundShapes().unwrap();
    assert(compound_shapes.len() == 10, 'Invalid compound shapes');
    
}


#[test]
#[feature("randomness")]
fn test_random_games() {
    let contract_address = deploy_contract("ShapesGame");

    let safe_dispatcher = IShapesGameSafeDispatcher { contract_address };

    let compound_shapes1 = safe_dispatcher.getCompoundShapesForGame(0x1648a422176b2fa7c60edd4bc2f06dc00229ac10bb52abd28933eaa0a9c9e6c).unwrap();
    test_unique_shapes_in_compound_shapes(safe_dispatcher, @compound_shapes1);
    let compound_shapes2 = safe_dispatcher.getCompoundShapesForGame(0x05fd8632073d51096f91e59b703f443c16003311b528c51147062cb2c3d93d6e).unwrap();
    test_unique_shapes_in_compound_shapes(safe_dispatcher, @compound_shapes2);
    let compound_shapes3 = safe_dispatcher.getCompoundShapesForGame(0x049c7b1a844d84c8bf57599c166dce4c16c81acb89f65ff1619f0928c6911043).unwrap();
    test_unique_shapes_in_compound_shapes(safe_dispatcher, @compound_shapes3);
    let compound_shapes4 = safe_dispatcher.getCompoundShapesForGame(0x030dd24d007742a7f2880281f3bcb34d5c08e372464282fabe0a94702631c5ff).unwrap();
    test_unique_shapes_in_compound_shapes(safe_dispatcher, @compound_shapes4);
    let compound_shapes5 = safe_dispatcher.getCompoundShapesForGame(0x02a089183bab375b5cc6bba998ce7ac1836ad63ca0fd78cd85256e422282cdd8).unwrap();
    test_unique_shapes_in_compound_shapes(safe_dispatcher, @compound_shapes5);
  
}

fn test_unique_shapes_in_compound_shapes(safe_dispatcher: IShapesGameSafeDispatcher, game_compound_shapes: @Array<Array<u8>>) {

    let mut i: u32 = 0;
    loop {
        if i >= game_compound_shapes.len() {
            break;
        }

        let compound_shape = game_compound_shapes.at(i);
        let mut j: u32 = 1;
        loop {
            if j >= compound_shape.len() {
                break;
            }

            let count = array_count_ocurrences(compound_shape, *compound_shape.at(j));
            assert(count == 1, 'Invalid count');

            j += 1;
        };
        i += 1;
    
    };  
}


#[test]
#[feature("randomness")]
fn test_get_shape_score_for_solution() {
  

  let contract_address = deploy_contract("ShapesGame");

  let safe_dispatcher = IShapesGameSafeDispatcher { contract_address };


  let mut solution1 = ArrayTrait::new();
  solution1.append(1_u8);
  solution1.append(2_u8);
  solution1.append(3_u8);

  let mut solution2 = ArrayTrait::new();
  solution2.append(4_u8);
  solution2.append(5_u8);


  let score1 = safe_dispatcher.getShapeScoreForSolution(solution1.clone(), solution1.clone()).unwrap();
   assert(score1 == 3, 'Invalid score');
  let score2 = safe_dispatcher.getShapeScoreForSolution(solution1.clone(), solution2.clone()).unwrap();
   assert(score2 == -2, 'Invalid score');
    
}

fn array_count_ocurrences(mArray: @Array<u8>, item: u8) -> u32 {
    let mut i = 0;
    let mut occurences : u32 = 0;
    loop {
        if i >= mArray.len() {
            break;
        }
        let mItem = *mArray.at(i);
        if item == mItem {
            occurences += 1;
        } 
        i += 1;
    };

    return occurences;
}
