"""
ProCon 2 Controller Initializer
Sends initialization sequence to Nintendo Switch 2 Pro Controller
Based on the procon2tool JavaScript implementation by https://github.com/HandHeldLegend
"""

import usb.core
import usb.util
import sys
import time

# Device ID
VENDOR_ID = 0x057E
PRODUCT_ID = 0x2069  # Nintendo Pro Controller 2
USB_INTERFACE_NUMBER = 1

# Initialization commands (from the JavaScript code)
COMMANDS = [
    # 1. Initialization Command 0x03 - Starts HID output at 4ms intervals
    bytes([0x03, 0x91, 0x00, 0x0d, 0x00, 0x08, 0x00, 0x00, 0x01, 0x00,
           0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),

    # 2. Unknown Command 0x07
    bytes([0x07, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]),

    # 3. Unknown Command 0x16
    bytes([0x16, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]),

    # 4. Request Controller MAC Command 0x15 Arg 0x01
    bytes([0x15, 0x91, 0x00, 0x01, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x02,
           0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),

    # 5. LTK Request Command 0x15 Arg 0x02
    bytes([0x15, 0x91, 0x00, 0x02, 0x00, 0x11, 0x00, 0x00, 0x00,
           0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
           0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),

    # 6. Unknown Command 0x15 Arg 0x03
    bytes([0x15, 0x91, 0x00, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00]),

    # 7. Unknown Command 0x09
    bytes([0x09, 0x91, 0x00, 0x07, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00,
           0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),

    # 8. IMU Command 0x0C Arg 0x02
    bytes([0x0c, 0x91, 0x00, 0x02, 0x00, 0x04, 0x00, 0x00, 0x27,
           0x00, 0x00, 0x00]),

    # 9. OUT Unknown Command 0x11
    bytes([0x11, 0x91, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00]),

    # 10. Unknown Command 0x0A
    bytes([0x0a, 0x91, 0x00, 0x08, 0x00, 0x14, 0x00, 0x00, 0x01,
           0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
           0x35, 0x00, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),

    # 11. IMU Command 0x0C Arg 0x04
    bytes([0x0c, 0x91, 0x00, 0x04, 0x00, 0x04, 0x00, 0x00, 0x27,
           0x00, 0x00, 0x00]),

    # 12. Enable Haptics
    bytes([0x03, 0x91, 0x00, 0x0a, 0x00, 0x04, 0x00, 0x00, 0x09,
           0x00, 0x00, 0x00]),

    # 13. OUT Unknown Command 0x10
    bytes([0x10, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]),

    # 14. OUT Unknown Command 0x01
    bytes([0x01, 0x91, 0x00, 0x0c, 0x00, 0x00, 0x00, 0x00]),

    # 15. OUT Unknown Command 0x03
    bytes([0x03, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00]),

    # 16. OUT Unknown Command 0x0A (alternate)
    bytes([0x0a, 0x91, 0x00, 0x02, 0x00, 0x04, 0x00, 0x00, 0x03,
           0x00, 0x00]),

    # 17. Set Player LED (LED 1 on)
    bytes([0x09, 0x91, 0x00, 0x07, 0x00, 0x08, 0x00, 0x00,
           0x01,  # LED bitfield
           0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
]


def find_controller():
    """Find Nintendo Pro Controller 2"""
    dev = usb.core.find(idVendor=VENDOR_ID, idProduct=PRODUCT_ID)
    if dev is not None:
        return dev, "Pro Controller 2"
    return None, None


def initialize_controller(dev, name):
    """Initialize the controller by sending command sequence"""
    print(f"Found: {name}")
    print(f"Bus: {dev.bus}, Address: {dev.address}")

    # Detach kernel driver if active
    if dev.is_kernel_driver_active(USB_INTERFACE_NUMBER):
        print(f"Detaching kernel driver from interface {USB_INTERFACE_NUMBER}")
        dev.detach_kernel_driver(USB_INTERFACE_NUMBER)

    # Set configuration
    try:
        dev.set_configuration()
        print("Configuration set")
    except usb.core.USBError as e:
        print(f"Warning: Could not set configuration: {e}")

    # Claim interface
    usb.util.claim_interface(dev, USB_INTERFACE_NUMBER)
    print(f"Claimed interface {USB_INTERFACE_NUMBER}")

    # Find bulk OUT endpoint
    cfg = dev.get_active_configuration()
    intf = cfg[(USB_INTERFACE_NUMBER, 0)]

    ep_out = usb.util.find_descriptor(
        intf,
        custom_match=lambda e: \
            usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT
    )

    ep_in = usb.util.find_descriptor(
        intf,
        custom_match=lambda e: \
            usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN
    )

    if ep_out is None or ep_in is None:
        raise ValueError("Could not find bulk endpoints")

    print(f"Using endpoints: OUT={hex(ep_out.bEndpointAddress)}, IN={hex(ep_in.bEndpointAddress)}")

    # Send initialization sequence
    print("\nSending initialization sequence...")
    for i, cmd in enumerate(COMMANDS, 1):
        try:
            # Write command
            bytes_written = ep_out.write(cmd)
            print(f"  [{i}/{len(COMMANDS)}] Sent {bytes_written} bytes: {cmd[:8].hex()}...")

            # Try to read response (with short timeout)
            time.sleep(0.01)  # 10ms delay
            try:
                response = ep_in.read(32, timeout=100)  # 100ms timeout
                print(f"           Response: {bytes(response[:8]).hex()}...")
            except usb.core.USBTimeoutError:
                pass  # No response expected for some commands

        except usb.core.USBError as e:
            print(f"  Warning: Command {i} failed: {e}")

    print("\n✓ Initialization complete!")
    print("Controller should now be active and sending input data.")

    # Release interface
    usb.util.release_interface(dev, USB_INTERFACE_NUMBER)

    # Reattach kernel driver if needed
    try:
        dev.attach_kernel_driver(USB_INTERFACE_NUMBER)
        print("Kernel driver reattached")
    except usb.core.USBError:
        pass  # Driver may not have been attached originally


def main():
    print("ProCon 2 Controller Initializer")
    print("=" * 50)

    # Find controller
    print("Searching for Nintendo Pro Controller 2...")
    dev, name = find_controller()

    if dev is None:
        print("✗ No Nintendo Pro Controller 2 found!")
        print(f"\nLooking for device: 057E:{PRODUCT_ID:04X}")
        print("Make sure the controller is connected via USB.")
        return 1

    try:
        initialize_controller(dev, name)
        return 0
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
