#!/usr/bin/env python3

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import subprocess
import time

# Configuration
BUS_NAME = 'org.bluez'
AGENT_INTERFACE = 'org.bluez.Agent1'
AGENT_PATH = '/org/bluez/agent'
DEVICE_INTERFACE = 'org.bluez.Device1'


class Rejected(dbus.DBusException):
    _dbus_error_name = 'org.bluez.Error.Rejected'


def close_quick_settings():
    """
    Pairing starts from the Quick Settings: close them so the dialog isn't
    opened under the panel (a no-op when they're closed)
    """
    try:
        subprocess.run(["qs", "ipc", "call", "quicksettings", "close"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
        time.sleep(0.2)
    except Exception as e:
        print(f"Couldn't close the Quick Settings: {e}")


class Agent(dbus.service.Object):
    def __init__(self, bus, path):
        dbus.service.Object.__init__(self, bus, path)
        self.bus = bus
        # The dialog showing a code to type on the device (Display*)
        self.display = None

    def device_prop(self, device, name):
        props = dbus.Interface(self.bus.get_object(BUS_NAME, device), 'org.freedesktop.DBus.Properties')
        return props.Get(DEVICE_INTERFACE, name)

    def is_paired(self, device):
        return bool(self.device_prop(device, 'Paired'))

    def device_name(self, device):
        try:
            return str(self.device_prop(device, 'Alias'))
        except dbus.DBusException:
            return "The device"

    def show_code(self, device, code):
        """
        Shows the code to type on the device without blocking the agent:
        BlueZ waits for no answer, and DisplayPasskey comes again with each
        key typed. One dialog per pairing; Cancel closes it
        """
        if self.display and self.display.poll() is None:
            return
        close_quick_settings()
        name = GLib.markup_escape_text(self.device_name(device))
        message = f"Type this code on {name}, then press Enter on it:\n\n<big><b>{code}</b></big>"
        self.display = subprocess.Popen(
            ["zenity", "--info", "--title=Bluetooth Pairing", f"--text={message}"]
        )

    def close_code(self):
        if self.display and self.display.poll() is None:
            self.display.terminate()
            # Reaped here, or it stays as a zombie
            try:
                self.display.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.display.kill()
        self.display = None

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        print("Release")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # BlueZ asks for services of devices that aren't trusted: accept the
        # paired ones, never one that never paired
        if self.is_paired(device):
            return
        print(f"Rejected a service from an unpaired device: {device}")
        raise Rejected("Device not paired")

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        close_quick_settings()
        # For older keyboards that require manual PIN entry
        try:
            output = subprocess.check_output(
                ["zenity", "--entry", "--title=Bluetooth", "--text=Enter the device PIN:"]
            )
            return output.decode().strip()
        except subprocess.CalledProcessError:
            raise Rejected("Rejected by the user")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        # Keyboards that pair by typing a PIN chosen here
        self.show_code(device, pincode)

    @dbus.service.method(AGENT_INTERFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        # Same, with a 6-digit passkey; `entered` counts the keys typed so far
        self.show_code(device, f"{passkey:06d}")

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        close_quick_settings()
        # Devices that show a 6-digit number to type here
        try:
            output = subprocess.check_output(
                ["zenity", "--entry", "--title=Bluetooth",
                 f"--text=Enter the number shown on {self.device_name(device)}:"]
            )
        except subprocess.CalledProcessError:
            raise Rejected("Rejected by the user")
        text = output.decode().strip()
        if not text.isdigit() or int(text) > 999999:
            raise Rejected("Not a passkey")
        return dbus.UInt32(int(text))

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        close_quick_settings()

        # Most common case (phones, modern headphones)
        # Shows the number and asks Yes/No
        message = f"{self.device_name(device)} wants to pair.\nPIN: {passkey:06d}\nConfirm?"
        try:
            subprocess.check_call(
                ["zenity", "--question", "--title=Bluetooth Pairing", f"--text={message}"]
            )
            return
        except subprocess.CalledProcessError:
            raise Rejected("Rejected by the user")

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        close_quick_settings()

        try:
            subprocess.check_call(
                ["zenity", "--question", "--title=Bluetooth", "--text=Authorize pairing with this device?"]
            )
            return
        except subprocess.CalledProcessError:
            raise Rejected("Rejected by the user")

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancelled by system")
        self.close_code()

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    # Start the Agent
    agent = Agent(bus, AGENT_PATH)

    # Register the Agent with BlueZ
    obj = bus.get_object(BUS_NAME, "/org/bluez")
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")

    # Register as default agent (NoInputNoOutput, DisplayOnly, DisplayYesNo, KeyboardDisplay, KeyboardOnly)
    # KeyboardDisplay is the most versatile for PCs
    manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
    manager.RequestDefaultAgent(AGENT_PATH)

    print("Bluetooth agent running... Waiting for requests.")

    mainloop = GLib.MainLoop()
    mainloop.run()
