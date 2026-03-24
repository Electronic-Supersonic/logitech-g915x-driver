pub mod functions {
    use std::env;
    use std::fs::File;
    use std::io::{BufRead, BufReader};
    use std::io;
    use std::path::PathBuf;

    fn get_mapping_file() -> io::Result<File> {
        let config_path = env::var("G915X_CONFIG").unwrap_or_else(|_| "/etc/g915x-driver/mapping.conf".to_owned());
        let path = PathBuf::from(config_path);
        File::open(path).or(File::open("mapping.conf"))
    }

    pub fn send_colour(
        device: &hidapi::HidDevice,
        key_id: u8,
        r: u8,
        g: u8,
        b: u8,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Function 0x5a from your first Wireshark trace
        // key_id 0x4B was confirmed in your capture
        let send_color = &[
            0x11, 0xff, 0x09, 0x1a, key_id, r, g, b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ];
        device.write(send_color)?;
        let mut res = [0u8; 20];
        device.read_timeout(&mut res, 200)?;
        println!("{:?}", res);
        Ok(())
    }

    pub fn handshake_before_color(
        device: &hidapi::HidDevice,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Packet from your Wireshark: 11 ff 09 7a ...
        let pkt = [
            0x11, 0xFF, 0x09, 0x7a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        device.write(&pkt)?;
        let mut res = [0u8; 20];
        device.read_timeout(&mut res, 100)?;
        Ok(())
    }

    pub fn set_all_colors(device: &hidapi::HidDevice, r: u8, g: u8, b: u8) {
        let file = get_mapping_file().expect("Could not get mapping file");
        let reader = BufReader::new(file);
        let mapping: Vec<(u8, String)> = reader
            .lines()
            .filter_map(|line| {
                line.ok().and_then(|l| {
                    l.split_once(" = ")
                        .and_then(|(hex, key)| {
                            let padded_hex: String = format!("{:0>2}", hex);
                            let byte_vec = hex::decode(&padded_hex).expect(format!("couldn't decode {padded_hex}").as_str());
                            if byte_vec.len() == 1 {
                                let byte = byte_vec[0];
                                let name = key.trim().to_string();
                                Some((byte, name))
                            } else {
                                None // Invalid length
                            }
                        })
                })
            })
            .collect();
        mapping.iter().for_each(|(hex, key)| {
            println!("Setting color to {} for {}", *hex, key);
            handshake_before_color(&device).unwrap();
            send_colour(&device, *hex, r, g, b).unwrap();
        });
    }
}
