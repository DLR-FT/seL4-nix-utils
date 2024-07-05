#![no_std]

pub const NUM_TRIES: usize = 5;
pub const WORD_LENGTH: usize = 5;

#[derive(Debug, Default, Clone, Copy)]
pub enum CharacterState {
    CorrectPlacement = 0,
    IncorrectPlacement = 1,
    #[default]
    Incorrect = 2,
}
