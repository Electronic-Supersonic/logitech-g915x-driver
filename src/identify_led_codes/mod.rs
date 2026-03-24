pub mod identify_led_codes {
    use crate::keyboard::keyboard::functions::{handshake_before_color, send_colour};
    use hidapi::HidDevice;
    use std::fs::File;
    use std::io;
    use std::io::Write;

    pub fn identify_led_code(device: &HidDevice) {
        (0x01..0xFF).for_each(|key| {
            handshake_before_color(&device).unwrap();
            send_colour(&device, key, 0, 0, 0).unwrap();
        });

        let mapping: Vec<String> = (0x98..0xE0).map(|key| -> String {
            handshake_before_color(&device).unwrap();
            send_colour(&device, key, 255, 0, 76).unwrap();
            let mut input = String::new();
            println!("which button lit up text: ");
            io::stdin().read_line(&mut input).expect("Failed to read line");
            let hex_key = format!("{:x}", key);
            handshake_before_color(&device).unwrap();
            send_colour(&device, key, 0, 0, 0).unwrap();
            format!("{hex_key} = {input}")
        }).collect();

        let mut file = File::create("../../mapping.conf").expect("Unable to create file");
        file.write_all(mapping.join("").as_bytes()).expect("Unable to write data");
    }
}
