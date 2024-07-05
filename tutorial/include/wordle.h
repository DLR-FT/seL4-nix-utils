#define NUM_TRIES 5
#define WORD_LENGTH 5

enum character_state {
    CORRECT_PLACEMENT = 0, // Correct character, in the correct index of the word.
    INCORRECT_PLACEMENT = 1, // Correct character, in the incorrect index of the word.
    INCORRECT = 2, // Character does not appear in the word.
};
