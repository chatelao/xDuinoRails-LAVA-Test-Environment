# LAVA Server on Raspberry Pi 3 for Microcontroller Testing

This document provides a comprehensive guide to setting up and using a LAVA (Linaro Automated Validation Architecture) server on a Raspberry Pi 3. This setup is specifically designed to control and test Raspberry Pi Picos, Seeed Studio XIAO RP2040s, and an ST Nucleo-F446RE.

## Table of Contents

- [Hardware Setup](#hardware-setup)
  - [RP2040 Boards (Pico, XIAO)](#rp2040-boards-pico-xiao)
  - [STM32-F446RE](#stm32-f446re)
  - [ESP32-WROOM](#esp32-wroom)
  - [Arduino Mega](#arduino-mega)
- [Software Setup](#software-setup)
- [Firmware and Test Delivery](#firmware-and-test-delivery)
  - [Method 1: UF2 Flashing (Pico & XIAO)](#method-1-uf2-flashing-pico--xiao)
  - [Method 2: SWD Flashing (Pico & XIAO)](#method-2-swd-flashing-pico--xiao)
  - [Method 3: OpenOCD Flashing (STM32)](#method-3-openocd-flashing-stm32)
  - [Method 4: Esptool Flashing (ESP32)](#method-4-esptool-flashing-esp32)
  - [Method 5: Avrdude Flashing (Arduino Mega)](#method-5-avrdude-flashing-arduino-mega)
- [Follow-up Prompts](#follow-up-prompts)

## Hardware Setup

Connect all target devices to the Raspberry Pi 3 host via a powered USB hub.

### Direct GPIO Control (HAT Interface)

For advanced debugging and flashing, a custom 26-pin HAT is used to connect the Raspberry Pi directly to the JTAG and SWD interfaces of the target devices. This approach bypasses the onboard debuggers (like ST-Link) and provides dedicated programming lines for each device.

**HAT Pin Mapping (26-pin Interface):**

| HAT Pin # | RPi Funktion | Signal Name | Zielgerät | Ziel Pin(s) |
| :--- | :--- | :--- | :--- | :--- |
| **_JTAG (STM32)_** | | | `target-stm32-f446re` | |
| 7 | GPIO 4 | JTAG\_TCK | Nucleo-F446RE | PA14 |
| 11 | GPIO 17 | JTAG\_TMS | Nucleo-F446RE | PA13 |
| 12 | GPIO 18 | JTAG\_TDI | Nucleo-F446RE | PA15 |
| 13 | GPIO 27 | JTAG\_TDO | Nucleo-F446RE | PB3 |
| **_SWD Port 1_** | | | `target-pico-1` | |
| 15 | GPIO 22 | SWD1\_CLK | RP2040-1 | SWCLK |
| 16 | GPIO 23 | SWD1\_DIO | RP2040-1 | SWDIO |
| **_SWD Port 2_** | | | `target-pico-2` | |
| 18 | GPIO 24 | SWD2\_CLK | RP2040-2 | SWCLK |
| 22 | GPIO 25 | SWD2\_DIO | RP2040-2 | SWDIO |
| **_Strom & GND_** | | | Alle | |
| 1 | 3V3 Power | +3.3V | (Optional) | |
| 6 | Ground | GND | Alle | GND |

### ESP32-WROOM

The ESP32-WROOM is flashed using `esptool.py`.

-   **Connection:** Connect the ESP32 board to the Raspberry Pi 3's USB hub. The `setup_lava.sh` script adds a udev rule to ensure it is accessible at `/dev/ttyUSB0`.

### Arduino Mega

The Arduino Mega is flashed using `avrdude`.

-   **Connection:** Connect the Arduino Mega to the Raspberry Pi 3's USB hub.

## Software Setup

The included `setup_lava.sh` script automates the installation of the LAVA server, dispatcher, and all necessary tools (`openocd`, `picotool`, `stlink-tools`, `esptool.py`, `avrdude`).

1.  **Run the script:**
    ```bash
    ./setup_lava.sh
    ```

2.  **Device-Type Configuration:**
    *   After the script finishes, create custom device-types in the LAVA web interface for `pico`, `xiao-rp2040`, and `stm32-f446re`.
    *   Go to `http://<your-pi-ip-address>/` and log in.
    *   In the device-type commands, use `picotool` for UF2 flashing, and `openocd` for SWD and STM32 flashing.

## Firmware and Test Delivery

LAVA uses YAML job definitions to deploy firmware and run tests.

### Method 1: UF2 Flashing (Pico & XIAO)

This method is ideal for `.uf2` firmware files.

**Job Definition (UF2):**
This job uses `picotool` to reboot the device into the bootloader and then deploys the firmware.

```yaml
device_type: pico
job_name: pico-uf2-blink-test

actions:
- deploy:
    to: host
    images:
      firmware:
        url: http://<your-server>/path/to/blink.uf2
- boot:
    method: custom
    commands: |
      picotool reboot --bootrom
      sleep 2
      picotool load -f {firmware}
      sleep 1
      picotool reboot
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: pico-blink-test.yaml
```

### Method 2: SWD Flashing (Pico & XIAO)

This method uses OpenOCD to flash `.elf` files, which is useful for debugging.

**Job Definition (SWD on Port 1):**
```yaml
device_type: pico
job_name: pico-swd-port1-test

actions:
- deploy:
    to: tftp
    images:
      firmware:
        url: http://<your-server>/path/to/debug_build.elf
      openocd_script:
        url: http://<your-server>/path/to/openocd_configs/pico_swd1.cfg
- boot:
    method: openocd
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: pico-debug-test.yaml
```

### Method 3: OpenOCD Flashing (STM32 via JTAG)

This method uses OpenOCD and the Raspberry Pi's GPIO pins to flash the STM32 via JTAG, which is ideal for boundary scan testing.

**Job Definition (STM32 JTAG):**
```yaml
device_type: stm32-f446re
job_name: stm32-jtag-led-test

actions:
- deploy:
    to: tftp
    images:
      firmware:
        url: http://<your-server>/path/to/stm32_blink.elf
      openocd_script:
        url: http://<your-server>/path/to/openocd_configs/stm32_jtag.cfg
- boot:
    method: openocd
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: stm32-led-test.yaml
```

### Method 4: Esptool Flashing (ESP32)

This method uses `esptool.py` to flash `.bin` files to the ESP32.

**Job Definition (ESP32):**
```yaml
device_type: esp32-wroom
job_name: esp32-blink-test

actions:
- deploy:
    to: host
    images:
      firmware:
        url: http://<your-server>/path/to/blink.bin
- boot:
    method: custom
    commands: |
      esptool.py --chip esp32 --port /dev/ttyUSB0 write_flash -z 0x1000 {firmware}
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: esp32-blink-test.yaml
```

### Method 5: Avrdude Flashing (Arduino Mega)

This method uses `avrdude` to flash `.hex` files to the Arduino Mega.

**Job Definition (Arduino Mega):**
```yaml
device_type: arduino-mega
job_name: arduino-mega-blink-test

actions:
- deploy:
    to: host
    images:
      firmware:
        url: http://<your-server>/path/to/blink.hex
- boot:
    method: custom
    commands: |
      avrdude -c wiring -p atmega2560 -P /dev/ttyACM4 -b 115200 -D -U flash:w:{firmware}:i
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: arduino-mega-blink-test.yaml
```

## Follow-up Prompts

| Prompt                                                              | Description                                                                                                                              |
| :------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------- |
| "Create a LAVA device-type template for UF2 flashing a Pico."       | This would generate a complete device-type template file that can be imported into LAVA, including the necessary `picotool` commands.      |
| "Write a LAVA test definition for the STM32-F446RE's user button."  | This would create a test definition that waits for a button press on the STM32 and reports the result back to LAVA via the serial port.      |
| "Develop a Python script to automatically submit LAVA jobs."        | This script would use the `lavacli` tool to submit jobs to the LAVA server, making it easier to integrate with other automation tools. |
