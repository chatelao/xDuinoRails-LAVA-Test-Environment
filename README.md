# LAVA Server on Raspberry Pi 3 for Pico and STM32 Testing

This document provides a comprehensive guide to setting up and using a LAVA (Linaro Automated Validation Architecture) server on a Raspberry Pi 3. This setup is specifically designed to control and test two Raspberry Pi Picos via SWD and an STM32-446RE via its built-in ST-Link V2.

## Table of Contents

- [Hardware Setup](#hardware-setup)
  - [Raspberry Pi Pico](#raspberry-pi-pico)
  - [STM32-446RE](#stm32-446re)
- [Software Setup](#software-setup)
- [Firmware and Test Delivery](#firmware-and-test-delivery)
  - [Job Definition](#job-definition)
  - [Test Definition](#test-definition)
- [Follow-up Prompts](#follow-up-prompts)

## Hardware Setup

### Raspberry Pi Pico

The Raspberry Pi Picos are controlled directly by the Raspberry Pi 3's GPIO pins using SWD.

**Wiring:**

Connect the Raspberry Pi 3 to the target Picos using the following wiring. Note that both Picos share the same SWD lines.

| RPi3 Pin     | Target Pico 1 Pin | RPi3 Pin     | Target Pico 2 Pin |
| :----------- | :---------------- | :----------- | :---------------- |
| 22 (GPIO 25) | SWDIO             | 22 (GPIO 25) | SWDIO             |
| 23 (GPIO 11) | SWCLK             | 23 (GPIO 11) | SWCLK             |
| Any GND      | GND               | Any GND      | GND               |

**Note:** You will need a custom Raspberry Pi HAT to manage these connections cleanly.

### STM32-446RE

The STM32-446RE is controlled via its built-in ST-Link V2 debugger.

1.  **Connection:**
    *   Simply connect the STM32-446RE to the Raspberry Pi 3 using a USB cable.

## Software Setup

The included `setup_lava.sh` script automates the installation of the LAVA server, dispatcher, and all necessary tools.

1.  **Run the script:**
    ```bash
    ./setup_lava.sh
    ```

2.  **Device-Type Configuration:**
    *   After the script finishes, you will need to create custom device-types in the LAVA web interface for the Pico and STM32 boards.
    *   Go to `http://<your-pi-ip-address>/` and log in.
    *   Navigate to "Device-Types" and create new types for `pico` and `stm32-446re`.
    *   You will need to define the commands for flashing and resetting the devices using `openocd` for the Pico and `st-flash` for the STM32.

## Firmware and Test Delivery

LAVA uses "jobs" to define a set of actions to be performed on a device. A job consists of a job definition (in YAML format) and one or more test definitions.

### OpenOCD Script

You will need to create a custom OpenOCD script to program the Pico. Here's an example, which you can save as `openocd_pico.cfg`:

```
# OpenOCD script for Raspberry Pi Pico

interface raspberrypi-swd.cfg
transport select swd

# Target configuration
source [find target/rp2040.cfg]

# Program the firmware
program {$FIRMWARE} verify reset exit
```

### Job Definition

Here's an example of a job definition for flashing and testing a Pico. This job assumes you have the `openocd_pico.cfg` script available on a web server.

```yaml
device_type: pico
job_name: pico-blink-test

actions:
- deploy:
    to: tftp
    images:
      firmware:
        url: http://<your-server>/path/to/blink.elf
      openocd_script:
        url: http://<your-server>/path/to/openocd_pico.cfg
- boot:
    method: openocd
- test:
    definitions:
      - repository: http://<your-server>/path/to/test-repo.git
        from: git
        path: pico-blink-test.yaml
```

### Test Definition

A test definition describes the steps to be executed on the device. Here's an example of a test for the Pico blink example:

```yaml
metadata:
  name: pico-blink-test
  description: "Tests the Pico's onboard LED"

run:
  steps:
    - "lava-test-case led-blink --result pass"
```

## Follow-up Prompts

| Prompt                                                              | Description                                                                                                                              |
| :------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------- |
| "Create a LAVA device-type template for the Raspberry Pi Pico."     | This would generate a complete device-type template file that can be imported into LAVA, including the necessary OpenOCD commands.        |
| "Write a LAVA test definition for the STM32-446RE's user button."   | This would create a test definition that waits for a button press on the STM32 and reports the result back to LAVA.                         |
| "Develop a Python script to automatically submit LAVA jobs."        | This script would use the `lavacli` tool to submit jobs to the LAVA server, making it easier to integrate with other automation tools. |
| "Design a custom Raspberry Pi HAT for the LAVA test environment."   | This would involve creating a hardware design for a HAT that provides clean and reliable connections for the Picos and STM32.            |
