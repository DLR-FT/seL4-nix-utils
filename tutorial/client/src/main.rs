#![no_std]
#![no_main]

use sel4_externally_shared::access::{ReadOnly, ReadWrite};
use sel4_externally_shared::{ExternallySharedRef, ExternallySharedRefExt};
use sel4_microkit::{debug_println, memory_region_symbol};
use sel4_microkit::{protection_domain, Channel, Handler, IrqAckError};
use wordle::{CharacterState, NUM_TRIES, WORD_LENGTH};

#[derive(Debug, Default, Clone, Copy)]
struct WordleChar {
    ch: Option<char>,
    state: CharacterState,
}

#[derive(Debug)]
pub struct Client {
    user_input: ExternallySharedRef<'static, [u32], ReadOnly>,
    game_output: ExternallySharedRef<'static, [u8], ReadWrite>,
    table: [[WordleChar; WORD_LENGTH]; NUM_TRIES],
    cur_row: usize,
    cur_letter: usize,
}

impl Client {
    const MOVE_CURSOR_UP: &'static str = "\x1b[5A";
    const CLEAR_TERMINAL_BELOW_CURSOR: &'static str = "\x1b[0J";
    const OUTPUT_SIZE: usize = 0x1000;

    pub fn new() -> Self {
        let user_input = unsafe {
            ExternallySharedRef::new(memory_region_symbol!(user_input_vaddr: *mut [u32], n = 1))
        };
        let game_output = unsafe {
            ExternallySharedRef::new(
                memory_region_symbol!(game_output_vaddr: *mut [u8], n = Self::OUTPUT_SIZE),
            )
        };
        let mut client = Self {
            table: Default::default(),
            cur_row: 0,
            cur_letter: 0,
            user_input,
            game_output,
        };

        client.print_table(false);

        client
    }

    fn wordle_server_send(&mut self) {
        // TODO
    }

    fn serial_send(&mut self, msg: &str) {
        // TODO
        let msg = msg.as_bytes();
        let len = msg.len().min(Self::OUTPUT_SIZE - 1);

        self.game_output
            .as_mut_ptr()
            .index(..len)
            .copy_from_slice(&msg[..len]);
        self.game_output.as_mut_ptr().index(len).write(0);
        SERIAL_SERVER.notify();
    }

    pub fn print_table(&mut self, clear_terminal: bool) {
        if clear_terminal {
            self.serial_send(Self::MOVE_CURSOR_UP);
            self.serial_send(Self::CLEAR_TERMINAL_BELOW_CURSOR);
        }

        for row in 0..NUM_TRIES {
            for letter in 0..WORD_LENGTH {
                self.serial_send("[");
                let state = self.table[row][letter].state;
                if let Some(ch) = self.table[row][letter].ch {
                    match state {
                        CharacterState::CorrectPlacement => self.serial_send("\x1B[32m"),
                        CharacterState::IncorrectPlacement => self.serial_send("\x1B[33m"),
                        _ => {}
                    }
                    let mut ch_str_buf = [0; 4];
                    let ch_str = ch.encode_utf8(&mut ch_str_buf);
                    self.serial_send(ch_str);
                    self.serial_send("\x1B[0m");
                } else {
                    self.serial_send(" ");
                }
                self.serial_send("] ");
            }
            self.serial_send("\n");
        }
    }

    fn char_is_backspace(ch: char) -> bool {
        ch == 0x7f as char
    }

    pub fn add_char_to_table(&mut self, ch: char) {
        if Self::char_is_backspace(ch) {
            if self.cur_letter > 0 {
                self.cur_letter -= 1;
                self.table[self.cur_row][self.cur_letter].ch = None;
            }
        } else if !ch.is_control() && !ch.is_whitespace() && self.cur_letter != WORD_LENGTH {
            self.table[self.cur_row][self.cur_letter].ch = Some(ch);
            self.cur_letter += 1;
        }

        if ch == '\r' && self.cur_letter == WORD_LENGTH {
            self.wordle_server_send();
            self.cur_row += 1;
            self.cur_letter = 0;
        }
    }
}

impl Default for Client {
    fn default() -> Self {
        Self::new()
    }
}

#[protection_domain]
fn init() -> impl Handler {
    Client::new()
}

const SERIAL_SERVER: Channel = Channel::new(1);

impl Handler for Client {
    type Error = IrqAckError;

    fn notified(&mut self, channel: Channel) -> Result<(), Self::Error> {
        match channel {
            SERIAL_SERVER => {
                let ch = char::from_u32(self.user_input.as_ptr().index(0).read()).unwrap();
                self.add_char_to_table(ch);
                self.print_table(true);
            }
            _ => unreachable!(),
        }
        Ok(())
    }
}
