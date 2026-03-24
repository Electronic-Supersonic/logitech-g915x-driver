pub mod identify_led_codes;
pub mod keyboard;
use crate::keyboard::keyboard::functions::{handshake_before_color, send_colour, set_all_colors};
use evdev::{Device, LedType};
use hidapi::{HidApi, HidDevice};
use std::error::Error;
use std::sync::{Arc, Mutex};
use tokio::task;

const LOGITECH_VID: u16 = 0x046d;
const G915X_PID: u16 = 0xc356; // Adjust for Lightspeed/Wired if needed

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let devices = evdev::enumerate().filter(|(_, dev)| {
        dev.supported_leds()
            .map_or(false, |l| l.contains(LedType::LED_NUML))
    });

    let api = HidApi::new()?;

    let device_info = api
        .device_list()
        .find(|d| {
            d.vendor_id() == LOGITECH_VID
                && d.product_id() == G915X_PID
                && d.usage_page() == 0xff00
                && d.interface_number() == 2
                && d.usage() == 2
        }) // CRITICAL: Target interface 2
        .ok_or("Could not find G915X RGB interface")?;
    let hid_device = device_info.open_device(&api)?;
    let keyboard_state_information = KeyboardStateInformation {
        hid_device: hid_device,
        previous_button_state: -1,
    };

    let shared_keyboard = Arc::new(Mutex::new(keyboard_state_information));
    if let Ok(keyboard) = shared_keyboard.lock() {
        kill_hardware_control(&keyboard.hid_device).await?;
        set_all_colors(&keyboard.hid_device, 0, 0, 255);
    }

    println!("Listening for NumLock events...");
    for (path, device) in devices {
        if let Ok(keyboard) = shared_keyboard.lock() {
            kill_hardware_control(&keyboard.hid_device).await?;
            let state = get_numlock_state(&device).unwrap();
            let (r, g, b) = get_on_off_colour(state);
            handshake_before_color(&keyboard.hid_device).unwrap();
            send_colour(&keyboard.hid_device, 0x50, r, g, b).unwrap();
        }
        println!("Monitoring state on: {:?}", path);
        let keyboard_clone = Arc::clone(&shared_keyboard);
        task::spawn(async move {
            let mut events = device.into_event_stream().unwrap();
            while let Ok(event) = events.next_event().await {
                if let evdev::InputEventKind::Led(LedType::LED_NUML) = event.kind() {
                    let (r, g, b) = get_on_off_colour(event.value());
                    if let Ok(mut keyboard) = keyboard_clone.lock() {
                        if keyboard.previous_button_state != event.value() {
                            handshake_before_color(&keyboard.hid_device).unwrap();
                            send_colour(&keyboard.hid_device, 0x50, r, g, b).unwrap();
                        }
                        keyboard.previous_button_state = event.value();
                    }
                }
            }
        });
    }

    tokio::signal::ctrl_c().await?;
    println!("Shutdown signal received");
    Ok(())
}

fn get_on_off_colour(led_value: i32) -> (u8, u8, u8) {
    let (r, g, b) = if led_value == 1 {
        (0x00, 0xFF, 0x00) // Green if ON
    } else {
        (0xFF, 0x00, 0x00) // Red if OFF
    };
    (r, g, b)
}

fn get_numlock_state(device: &Device) -> Result<i32, std::io::Error> {
    let led_state = device.get_led_state()?;
    Ok(led_state.contains(LedType::LED_NUML) as i32)
}

struct KeyboardStateInformation {
    hid_device: HidDevice,
    previous_button_state: i32,
}

async fn kill_hardware_control(device: &hidapi::HidDevice) -> Result<(), Box<dyn Error>> {
    // 1. Disable OBM (Index 13)
    let kill_hardware_control: &[u8; 20] = &[
        0x11, 0xff, 0x08, 0x54, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
    ];
    device.write(kill_hardware_control)?;
    tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    Ok(())
}

// 11ff0915500000ff51ff00000000000000000000
//
// 0000   80 36 21 c7 1f 89 ff ff 43 02 00 02 05 00 2d 3e
// 0010   8d e9 a9 69 00 00 00 00 95 de 02 00 00 00 00 00
// 0020   14 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
// 0030   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
//
// Data Fragment: 11ff097600000000000000000000000000000000
//
// 0000   80 36 21 c7 1f 89 ff ff 53 02 00 02 05 00 00 00
// 0010   8d e9 a9 69 00 00 00 00 a6 e2 02 00 8d ff ff ff
// 0020   14 00 00 00 14 00 00 00 21 09 11 02 02 00 14 00
// 0030   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
// 0040   11 ff 09 76 00 00 00 00 00 00 00 00 00 00 00 00
// 0050   00 00 00 00

// Data Fragment: 11ff091950ff0000000000000000000000000000
