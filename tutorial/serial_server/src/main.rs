#![no_std]
#![no_main]

use core::{ffi::CStr, ops::BitAnd};

use sel4_externally_shared::{
    access::{ReadOnly, ReadWrite},
    ExternallySharedRef, ExternallySharedRefExt,
};
use sel4_microkit::{memory_region_symbol, protection_domain, Channel, Handler, IrqAckError};

pub struct SerialServer {
    uart: ExternallySharedRef<'static, [u32], ReadWrite>,
    user_input: ExternallySharedRef<'static, [u32], ReadWrite>,
    game_output: ExternallySharedRef<'static, [u8], ReadOnly>,
}

impl SerialServer {
    const RHR_MASK: u32 = 0b111111111;
    const UARTDR: usize = 0x000;
    const UARTFR: usize = 0x018 / core::mem::size_of::<u32>();
    const UARTIMSC: usize = 0x038 / core::mem::size_of::<u32>();
    const UARTICR: usize = 0x044 / core::mem::size_of::<u32>();
    const PL011_UARTFR_TXFF: u32 = (1 << 5);
    const PL011_UARTFR_RXFE: u32 = (1 << 4);
    const UART_SIZE: usize = 0x4_000 / core::mem::size_of::<u32>();
    const GAME_OUTPUT_SIZE: usize = 0x1000;

    pub fn new() -> Self {
        let uart = unsafe {
            ExternallySharedRef::new(
                memory_region_symbol!(uart_base_vaddr: *mut [u32], n = Self::UART_SIZE),
            )
        };
        let user_input = unsafe {
            ExternallySharedRef::new(memory_region_symbol!(user_input_vaddr: *mut [u32], n = 1))
        };
        let game_output = unsafe {
            ExternallySharedRef::new(
                memory_region_symbol!(game_output_vaddr: *mut [u8], n = Self::GAME_OUTPUT_SIZE),
            )
        };
        let mut serial_server = Self {
            uart,
            user_input,
            game_output,
        };
        serial_server.init();
        serial_server
    }

    fn init(&mut self) {
        self.set_reg(Self::UARTIMSC, 0x50);
    }

    fn get_reg(&self, reg: usize) -> u32 {
        self.uart.as_ptr().index(reg).read()
    }

    fn set_reg(&mut self, reg: usize, value: u32) {
        self.uart.as_mut_ptr().index(reg).write(value)
    }

    pub fn get_char(&self) -> char {
        if self.get_reg(Self::UARTFR).bitand(Self::PL011_UARTFR_RXFE) != 0 {
            return 0 as char;
        }
        let ch = self.get_reg(Self::UARTDR).bitand(Self::RHR_MASK);
        core::char::from_u32(ch).unwrap_or_default()
    }

    pub fn put_char(&mut self, ch: char) {
        while self.get_reg(Self::UARTFR).bitand(Self::PL011_UARTFR_TXFF) != 0 {}
        self.set_reg(Self::UARTDR, ch as u32);
        if ch == '\r' {
            self.put_char('\n');
        }
    }

    pub fn handle_irq(&mut self) {
        self.set_reg(Self::UARTICR, 0x7f0);
    }

    pub fn put_str(&mut self, str: &str) {
        for ch in str.chars() {
            self.put_char(ch);
        }
    }
}

impl Default for SerialServer {
    fn default() -> Self {
        Self::new()
    }
}

#[protection_domain]
fn init() -> impl Handler {
    let mut server = SerialServer::new();
    server.put_str("SERIAL SERVER starting\n");
    server
}

const INPUT_CHANNEL: Channel = Channel::new(0);
const CLIENT: Channel = Channel::new(1);

impl Handler for SerialServer {
    type Error = IrqAckError;

    fn notified(&mut self, channel: Channel) -> Result<(), Self::Error> {
        match channel {
            INPUT_CHANNEL => {
                let ch = self.get_char();
                self.user_input.as_mut_ptr().index(0).write(ch as u32);
                CLIENT.notify();
                self.handle_irq();
                channel.irq_ack()?;
            }
            CLIENT => {
                let s = unsafe {
                    CStr::from_ptr(self.game_output.as_ptr().as_raw_ptr().as_ptr() as *mut i8)
                };
                self.put_str(s.to_str().unwrap());
            }
            _ => unreachable!(),
        }
        Ok(())
    }
}
