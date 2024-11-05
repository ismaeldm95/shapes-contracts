use starknet::{ContractAddress};
use starknet::get_caller_address;
use starknet::syscalls::get_block_hash_syscall;
use starknet::syscalls::get_execution_info_syscall;

use starknet::storage::Map;

pub mod GameConstants {
    pub const SHAPES_PER_GAME: u8 = 10;
    pub const MIN_INDIVIDUAL_SHAPES: u8 = 4;
    pub const MAX_INDIVIDUAL_SHAPES: u8 = 6;
    pub const TOTAL_INDIVIDUAL_SHAPES: u8 = 40;
    pub const SECONDS_PER_DAY: u64 = 86400;
    pub const TIME_BETWEEN_GAMES: u64 = SECONDS_PER_DAY;
}

#[starknet::interface]
pub trait IShapesGame<TContractState> {
    fn getGame(self: @TContractState) -> felt252;
    fn updateGame(ref self: TContractState);
    fn getGameIndex(self: @TContractState) -> felt252;
    fn getGameTimestamp(self: @TContractState) -> u64;
    fn getAllGames(self: @TContractState) -> Array<(felt252, u64, Array<Array<u8>>)>;
    fn getAllGameIds(self: @TContractState) -> Array<felt252>;
    fn getAllGameTimestamps(self: @TContractState) -> Array<u64>;
    fn getAllGameIdsAndTimestamps(self: @TContractState) -> Array<(felt252, u64)>;
    fn getAllGamesForAccount(self: @TContractState, account: ContractAddress) -> Array<(felt252, u32, u64, Array<Array<u8>>, Array<Array<u8>>, felt252)>;
    fn getAccountSolutionsForGame(self: @TContractState, account: ContractAddress, game_id: felt252) -> Array<Array<u8>>;
    fn isValidGame(self: @TContractState, game_id: felt252) -> bool;
    fn getCompoundShape(self: @TContractState, game_id: felt252, compound_shape_index: u8) -> Array<u8>;
    fn getShapeScoreForSolution(self: @TContractState, compound_shape: Array<u8>, solution: Array<u8>) -> i8;
    fn getCurrentGameCompoundShapes(self: @TContractState) -> Array<Array<u8>>;
    fn getCompoundShapesForGame(self: @TContractState, game_id: felt252) -> Array<Array<u8>>;
    fn getLastPlayedIndex(self: @TContractState, address: ContractAddress) -> u8;
    fn canPlayGame(self: @TContractState, address: ContractAddress) -> bool;
    fn solveAll(ref self: TContractState, solutions: Array<Array<u8>>);
    fn solve(ref self: TContractState, solution: Array<u8>);
    fn getScore(self: @TContractState, account: ContractAddress, game_id: felt252) -> i8;
}

#[starknet::contract]
mod ShapesGame {
    use super::IShapesGame;
    use super::ContractAddress;
    use super::Map;
    use super::get_caller_address;
    use super::get_block_hash_syscall;
    use super::get_execution_info_syscall;
    use super::GameConstants;
    use super::Utils;

    #[storage]
    struct Storage {
        // Game state
        current_game_id: felt252, 
        current_game_timestamp: u64,
        games_amount: felt252,
        
        // Game history mappings
        game_ids: Map::<felt252, felt252>,
        game_timestamps: Map::<felt252, u64>,
        
        // Player state mappings
        games_played: Map::<(ContractAddress, felt252), bool>,
        final_scores: Map::<(ContractAddress, felt252), i8>,
        
        // Solution storage
        solution_length: Map::<(ContractAddress, felt252, u8), u32>,
        solution_content: Map::<(ContractAddress, felt252, u8, u32), u8>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let exec_info = get_execution_info_syscall().unwrap();
        let block_timestamp = exec_info.block_info.block_timestamp;
        self.current_game_id.write(0x1648a422176b2fa7c60edd4bc2f06dc00229ac10bb52abd28933eaa0a9c9e6c);
        self.current_game_timestamp.write(block_timestamp);
        self.games_amount.write(1);
        self.game_ids.write(1, 0x1648a422176b2fa7c60edd4bc2f06dc00229ac10bb52abd28933eaa0a9c9e6c);
        self.game_timestamps.write(1, block_timestamp);
    }

    #[abi(embed_v0)]
    impl ShapesGameImpl of super::IShapesGame<ContractState> {

        fn getGame(self: @ContractState) -> felt252 {
            self.current_game_id.read()
        }

        fn getGameIndex(self: @ContractState) -> felt252 {
            self.games_amount.read()
        }

        fn getGameTimestamp(self: @ContractState) -> u64 {
            self.current_game_timestamp.read()
        }

        fn isValidGame(self: @ContractState, game_id: felt252) -> bool {
            game_id == self.getGame()
        }

        fn updateGame(ref self: ContractState) {
            
            let exec_info = get_execution_info_syscall().unwrap();
            let block_timestamp = exec_info.block_info.block_timestamp;


            assert(block_timestamp > self.current_game_timestamp.read() + GameConstants::TIME_BETWEEN_GAMES, 'Too early to update game');


            let block_number = exec_info.block_info.unbox().block_number;
            let new_block_number = block_number - 10_u64;
            let mut previous_block_hash = get_block_hash_syscall(new_block_number).unwrap();


            assert(previous_block_hash != 0, 'Invalid block hash: cannot be 0');
            let new_games_amount = self.games_amount.read() + 1;

            self.current_game_timestamp.write(block_timestamp);
            self.current_game_id.write(previous_block_hash);
            self.games_amount.write(new_games_amount);
            self.game_ids.write(new_games_amount, previous_block_hash);
            self.game_timestamps.write(new_games_amount, block_timestamp);

        }

        fn getAllGames(self: @ContractState) -> Array<(felt252, u64, Array<Array<u8>>)> {
            let mut games = ArrayTrait::new();
            let mut i: u32 = 1;
            loop {
                if i > self.games_amount.read().try_into().unwrap() {
                    break;
                }
                let game_id = self.game_ids.read(i.into());
                let compound_shapes = self.getCompoundShapesForGame(game_id);
                let game_timestamp = self.game_timestamps.read(i.into());
                games.append((game_id, game_timestamp, compound_shapes));
                i += 1;
            };
            games
        }


        fn getAllGamesForAccount(self: @ContractState, account: ContractAddress) -> Array<(felt252, u32, u64, Array<Array<u8>>, Array<Array<u8>>, felt252)> {
            let mut games = ArrayTrait::new();
            let mut i: u32 = 1;
            loop {
                if i > self.games_amount.read().try_into().unwrap() {
                    break;
                }
                let game_id = self.game_ids.read(i.into());
                let has_played_game = self.games_played.read((account, game_id));

                if has_played_game {
                    let game_index = i;
                    let game_timestamp = self.game_timestamps.read(i.into());
                    let game_solutions = self.getCompoundShapesForGame(game_id);
                    let account_solutions = self.getAccountSolutionsForGame(account, game_id);
                    let final_score: felt252 = self.final_scores.read((account, game_id)).into();

                    games.append((game_id, game_index, game_timestamp, game_solutions, account_solutions, final_score));
                }
                i += 1;
            };
            games
        }

      
        fn getAccountSolutionsForGame(self: @ContractState, account: ContractAddress, game_id: felt252) -> Array<Array<u8>> {
            let mut solutions = ArrayTrait::new();
            let mut i: u8 = 1;
            loop {
                if i > GameConstants::SHAPES_PER_GAME {
                    break;
                }
                let solution_len = self.solution_length.read((account, game_id, i));
                let mut solution = ArrayTrait::new();
                let mut j: u32 = 0;
                loop {
                    if j >= solution_len {
                        break;
                    }
                    let solution_value = self.solution_content.read((account, game_id, i, j.into()));
                    solution.append(solution_value);
                    j += 1;
                };
                solutions.append(solution);
                i += 1;
            };
            solutions
        }
       

        fn getAllGameIds(self: @ContractState) -> Array<felt252> {
            let mut games = ArrayTrait::new();
            let mut i: u32 = 1;
            loop {
                if i > self.games_amount.read().try_into().unwrap() {
                    break;
                }
                let game_id = self.game_ids.read(i.into());
                games.append(game_id);
                i += 1;
            };
            games
        }

        fn getAllGameTimestamps(self: @ContractState) -> Array<u64> {
            let mut games = ArrayTrait::new();
            let mut i: u32 = 1;
            loop {
                if i > self.games_amount.read().try_into().unwrap() {
                    break;
                }
                let game_timestamp = self.game_timestamps.read(i.into());
                games.append(game_timestamp);
                i += 1;
            };
            games
        }

        fn getAllGameIdsAndTimestamps(self: @ContractState) -> Array<(felt252, u64)> {
            let mut games = ArrayTrait::new();
            let mut i: u32 = 1;
            loop {
                if i > self.games_amount.read().try_into().unwrap() {
                    break;
                }
                let game_id = self.game_ids.read(i.into());
                let game_timestamp = self.game_timestamps.read(i.into());
                games.append((game_id, game_timestamp));
                i += 1;
            };
            games
        }

        fn getCompoundShape(self: @ContractState, game_id: felt252, compound_shape_index: u8) -> Array<u8> {
            assert(compound_shape_index >= 1 && compound_shape_index <= GameConstants::SHAPES_PER_GAME, 'Invalid compound shape index');
            
            // Use game_id and compound_shape_index to seed the random generation
            let compound_shape_seed = game_id * compound_shape_index.into();

            let shape_count = Utils::generate_range(compound_shape_seed, GameConstants::MIN_INDIVIDUAL_SHAPES, GameConstants::MAX_INDIVIDUAL_SHAPES);
            let mut shape = ArrayTrait::new();


            let mut i: u8 = 0;
            let mut j: u8 = 1;
            loop {
                if i >= shape_count {
                    break;
                }
                let shape_seed = compound_shape_seed * (i.into() + j.into()) ;
                let shape_value = Utils::generate_range(shape_seed, 1, GameConstants::TOTAL_INDIVIDUAL_SHAPES);
                if (!Utils::array_contains(@shape, shape_value)) {
                    shape.append(shape_value);
                    i += 1;
                } else {
                    j += 1;
                }
            
            };

            shape
        }

        fn getScore(self: @ContractState, account: ContractAddress, game_id: felt252) -> i8 {
            return self.final_scores.read((account, game_id));
        }


        fn getShapeScoreForSolution(self: @ContractState, compound_shape: Array<u8>, solution: Array<u8>) -> i8 {
            let mut score: i8 = 0;
            let mut i = 0;
            loop {
                if i >= solution.len() {
                    break;
                }
                let shape = *solution.at(i);
                if Utils::array_contains(@compound_shape, shape){
                    score += 1;
                } else {
                    score -= 1;
                }
                i += 1;
            };
            score
        }

        fn getCurrentGameCompoundShapes(self: @ContractState) -> Array<Array<u8>> {
            let game_id = self.getGame();
            return self.getCompoundShapesForGame(game_id);
        }

        fn getCompoundShapesForGame(self: @ContractState, game_id: felt252) -> Array<Array<u8>> {
            let mut shapes = ArrayTrait::new();
            let mut i: u8 = 1;
            loop {
                if i > GameConstants::SHAPES_PER_GAME {
                    break;
                }
                shapes.append(self.getCompoundShape(game_id, i));
                i += 1;
            };
            shapes
        }

        fn getLastPlayedIndex(self: @ContractState, address: ContractAddress) -> u8 {
            let game_id = self.getGame();
            let mut last_index: u8 = 0;
            let mut i: u8 = 1;
            loop {
                if i > GameConstants::SHAPES_PER_GAME {
                    break;
                }
                let solution_len = self.solution_length.read((address, game_id, i));

                if (solution_len == 0){
                    break;
                }
                last_index = i;
                i += 1;
            };
            last_index
        }

        fn canPlayGame(self: @ContractState, address: ContractAddress) -> bool {
            let game_id = self.getGame();
            !self.games_played.read((address, game_id))
        }

        fn solveAll(ref self: ContractState, solutions: Array<Array<u8>>) {
            let mut i: u32 = 0;
            loop {
                if i >= solutions.len() {
                    break;
                }
                self.solve(solutions.at(i).clone());
                i += 1;
            };
        }

        fn solve(ref self: ContractState, solution: Array<u8>) {

            let caller = get_caller_address();
            assert(self.canPlayGame(caller), 'Already played today');

            let game_id = self.getGame();
            let last_index = self.getLastPlayedIndex(caller);
            let current_index = last_index + 1_u8;

            assert(current_index <= GameConstants::SHAPES_PER_GAME, 'Game already finished');

            assert(validate_solution(@solution), 'Solution is not valid');

            write_solution(ref self, caller, game_id, current_index, solution);

            if current_index == GameConstants::SHAPES_PER_GAME {
                let mut total_score: i8 = 0;
                let mut i: u8 = 1;
                loop {
                    if i > GameConstants::SHAPES_PER_GAME {
                        break;
                    }
                    let shape = self.getCompoundShape(game_id, i);
                    let sol = read_solution(ref self, caller, game_id, i);
                    total_score += self.getShapeScoreForSolution(shape.clone(), sol.clone());
                    i += 1;
                };


                self.final_scores.write((caller, game_id), total_score);
                self.games_played.write((caller, game_id), true);
            }


        }
        

    }



    fn validate_solution(solution: @Array<u8>) -> bool {

        // Solution must have unique values

        let mut unique_values = true;
        let mut i: u32 = 0;
        loop {
            if i >= solution.len() || !unique_values {
                break;
            }
            let mItem = *solution.at(i);
            if Utils::array_count_ocurrences(solution, mItem) > 1 {
                unique_values = false;
            } 
            i += 1;
        };
        unique_values
    }



    fn write_solution(ref self: ContractState, address: ContractAddress, game_id: felt252, index: u8, solution: Array<u8>) { 
        let solution_len = solution.len();

        self.solution_length.write((address, game_id, index), solution_len);

        let mut i: u32 = 0;
        loop {
            if i >= solution.len() {
                break;
            }
            self.solution_content.write((address, game_id, index, i), *solution.at(i));
            i += 1;
        };

    }

    fn read_solution(ref self: ContractState, address: ContractAddress, game_id: felt252, index: u8) -> Array<u8> { 
        let len = self.solution_length.read((address, game_id, index));
        let mut solution = ArrayTrait::new();
        let mut i: u32 = 0;
        loop {
            if i >= len {
                break;
            }
            let solution_content = self.solution_content.read((address, game_id, index, i));
            solution.append(solution_content);
            i += 1;
        };
        return solution;
    }
  
}

mod Utils {
    pub fn array_contains(mArray: @Array<u8>, item: u8) -> bool {
        let mut i = 0;
        let mut contains = false;
        loop {
            if i >= mArray.len() || contains {
                break;
            }
            let mItem = *mArray.at(i);
            if item == mItem {
                contains = true;
            } 
            i += 1;
        };
        return contains;
    }

    pub fn array_count_ocurrences(mArray: @Array<u8>, item: u8) -> u32 {
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

    pub fn generate_range(seed: felt252, min: u8, max: u8) -> u8 {
        assert(min < max, 'Invalid range');
        let range : u256 = (max - min).into() + 1;
        let random = seed.into(); //+ pedersen::pedersen(seed, 0).into();
        let random_value = random % range;
        (random_value.try_into().unwrap() + min)
    }
}

