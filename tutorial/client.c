#include <stdint.h>
#include <stdbool.h>
#include <microkit.h>
#include "printf.h"
#include "wordle.h"

#define MOVE_CURSOR_UP "\033[5A"
#define CLEAR_TERMINAL_BELOW_CURSOR "\033[0J"

#define INVALID_CHAR (-1)

struct wordle_char {
    int ch;
    enum character_state state;
};

// Store game state
static struct wordle_char table[NUM_TRIES][WORD_LENGTH];
// Use these global variables to keep track of the character index that the
// player is currently trying to input.
static int curr_row = 0;
static int curr_letter = 0;

void wordle_server_send() {
    // Implement this function to send the word over PPC
    // After doing the PPC, the Wordle server should have updated
    // the message-registers containing the state of each character.
    // Look at the message registers and update the `table` accordingly.
}

void serial_send(char *str) {
    // Implement this function to get the serial server to print the string.
}

// This function prints a CLI Wordle using pretty colours for what characters
// are correct, or correct but in the wrong place etc.
void print_table(bool clear_terminal) {
    if (clear_terminal) {
        // Assuming we have already printed a Wordle table, this will clear the
        // table we have already printed and then print the updated one. This
        // is done by moving the cursor up 5 lines and then clearing everything
        // below it.
        serial_send(MOVE_CURSOR_UP);
        serial_send(CLEAR_TERMINAL_BELOW_CURSOR);
    }

    for (int row = 0; row < NUM_TRIES; row++) {
        for (int letter = 0; letter < WORD_LENGTH; letter++) {
            serial_send("[");
            enum character_state state = table[row][letter].state;
            int ch = table[row][letter].ch;
            if (ch != INVALID_CHAR) {
                switch (state) {
                    case INCORRECT: break;
                    case CORRECT_PLACEMENT: serial_send("\x1B[32m"); break;
                    case INCORRECT_PLACEMENT: serial_send("\x1B[33m"); break;
                    default:
                        // Print out error messages/debug info via debug output
                        microkit_dbg_puts("CLIENT|ERROR: unexpected character state\n");
                }
                char ch_str[] = { ch, '\0' };
                serial_send(ch_str);
                // Reset colour
                serial_send("\x1B[0m");
            } else {
                serial_send(" ");
            }
            serial_send("] ");
        }
        serial_send("\n");
    }
}

void init_table() {
    for (int row = 0; row < NUM_TRIES; row++) {
        for (int letter = 0; letter < WORD_LENGTH; letter++) {
            table[row][letter].ch = INVALID_CHAR;
            table[row][letter].state = INCORRECT;
        }
    }
}

bool char_is_backspace(int ch) {
    return (ch == 0x7f);
}

bool char_is_valid(int ch) {
    // Only allow alphabetical letters and do not accept a character if the
    // current word has already been filled.
    return ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) && curr_letter != WORD_LENGTH;
}

void add_char_to_table(char c) {
    if (char_is_backspace(c)) {
        if (curr_letter > 0) {
            curr_letter--;
            table[curr_row][curr_letter].ch = INVALID_CHAR;
        }
    } else if (c != '\r' && c != ' ' && curr_letter != WORD_LENGTH) {
        table[curr_row][curr_letter].ch = c;
        curr_letter++;
    }

    // If the user has finished inputting a word, we want to send the
    // word to the server and move the cursor to the next row.
    if (c == '\r' && curr_letter == WORD_LENGTH) {
        wordle_server_send();
        curr_row += 1;
        curr_letter = 0;
    }
}

void init(void) {
    microkit_dbg_puts("CLIENT: starting\n");
    serial_send("Welcome to the Wordle client!\n");

    init_table();
    // Don't want to clear the terminal yet since this is the first time
    // we are printing it (we want to clear just the Wordle table, not
    // everything on the terminal).
    print_table(false);
}

void notified(microkit_channel channel) {}
