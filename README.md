# LAVA Server on Raspberry Pi 3 for Microcontroller Testing

This document provides a comprehensive guide to setting up and using a LAVA (Linaro Automated Validation Architecture) server on a Raspberry Pi 3. This setup is specifically designed to control and test Raspberry Pi Picos, Seeed Studio XIAO RP2040s, and an ST Nucleo-F446RE.

## Table of Contents

- [Hardware Setup](#hardware-setup)
  - [RP2040 Boards (Pico, XIAO)](#rp2040-boards-pico-xiao)
  - [STM32-F446RE](#stm32-f446re)
- [Software Setup](#software-setup)
- [Firmware and Test Delivery](#firmware-and-test-delivery)
  - [Method 1: UF2 Flashing (Pico & XIAO)](#method-1-uf2-flashing-pico--xiao)
  - [Method 2: SWD Flashing (Pico & XIAO)](#method-2-swd-flashing-pico--xiao)
  - [Method 3: OpenOCD Flashing (STM32)](#method-3-openocd-flashing-stm32)
- [Follow-up Prompts](#follow-up-prompts)

## Hardware Setup

Connect all target devices to the Raspberry Pi 3 host via a powered USB hub.

### RP2040 Boards (Pico, XIAO)

The RP2040-based boards can be programmed using two methods: the simple UF2 drag-and-drop method over USB, or the more advanced SWD method for debugging.

#### UF2 Connection
-   Simply connect the Pico or XIAO board to the USB hub. The `setup_lava.sh` script installs `picotool` to automate putting the device into bootloader mode.

#### SWD Connection
For direct debugging, you can connect the boards to the Raspberry Pi 3's GPIO pins. Note that all SWD-connected devices share the same lines.

**Wiring:**

| RPi3 Pin     | Target Pico/XIAO Pin |
| :----------- | :------------------- |
| 22 (GPIO 25) | SWDIO                |
| 23 (GPIO 11) | SWCLK                |
| Any GND      | GND                  |

### STM32-F446RE

The STM32-F446RE is controlled via its built-in ST-Link v2 debugger.

-   **Connection:** Connect the Nucleo board to the Raspberry Pi 3's USB hub using the USB port on the ST-Link end of the board.

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

**OpenOCD Script (`openocd_rp2040.cfg`):**
```
# OpenOCD script for Raspberry Pi Pico / XIAO RP2040
interface raspberrypi-swd.cfg
transport select swd
source [find target/rp2040.cfg]
program {$FIRMWARE} verify reset exit
```

**Job Definition (SWD):**
```yaml
device_type: pico
job_name: pico-swd-debug-test

actions:
- deploy:
    to: tftp
    images:
      firmware:
        url: http://<your-server>/path/to/debug_build.elf
      openocd_script:
        url: http://<your-server>/path/to/openocd_rp2040.cfg
- boot:
    method: openocd
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: pico-debug-test.yaml
```

### Method 3: OpenOCD Flashing (STM32)

This method uses OpenOCD to flash the STM32 via its onboard ST-Link.

**OpenOCD Script (`openocd_stm32.cfg`):**
```
# OpenOCD script for STM32-F446RE Nucleo
source [find interface/stlink.cfg]
transport select hla_swd
source [find target/stm32f4x.cfg]
program {$FIRMWARE} verify reset exit
```

**Job Definition (STM32):**
```yaml
device_type: stm32-f446re
job_name: stm32-led-test

actions:
- deploy:
    to: tftp
    images:
      firmware:
        url: http://<your-server>/path/to/stm32_blink.elf
      openocd_script:
        url: http://<your-server>/path/to/openocd_stm32.cfg
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
