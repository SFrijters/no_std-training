#![no_std]
#![no_main]

use core::cell::RefCell;
use critical_section::Mutex;
use esp_backtrace as _;
use esp_println::println;
use hal::{
    clock::ClockControl,
    gpio::{Event, Gpio9, Input, PullUp, IO},
    interrupt,
    peripherals::{self, Peripherals},
    prelude::*,
    riscv, Delay,
};

static BUTTON: Mutex<RefCell<Option<Gpio9<Input<PullUp>>>>> = Mutex::new(RefCell::new(None));

#[entry]
fn main() -> ! {
    let peripherals = Peripherals::take();
    let system = peripherals.SYSTEM.split();
    let clocks = ClockControl::boot_defaults(system.clock_control).freeze();

    println!("Hello world!");

    let io = IO::new(peripherals.GPIO, peripherals.IO_MUX);
    // Set GPIO7 as an output, and set its state high initially.
    let mut led = io.pins.gpio7.into_push_pull_output();

    // Set GPIO9 as an input
    let mut button = io.pins.gpio9.into_pull_up_input();
    button.listen(Event::FallingEdge);

    // ANCHOR: critical_section
    critical_section::with(|cs| BUTTON.borrow_ref_mut(cs).replace(button));
    // ANCHOR_END: critical_section
    // ANCHOR: interrupt
    interrupt::enable(peripherals::Interrupt::GPIO, interrupt::Priority::Priority3).unwrap();
    // ANCHOR_END: interrupt

    unsafe {
        riscv::interrupt::enable();
    }

    let mut delay = Delay::new(&clocks);
    loop {
        led.toggle().unwrap();
        delay.delay_ms(500u32);
    }
}

#[interrupt]
fn GPIO() {
    critical_section::with(|cs| {
        println!("GPIO interrupt");
        BUTTON
            .borrow_ref_mut(cs)
            .as_mut()
            .unwrap()
            .clear_interrupt();
    });
}
