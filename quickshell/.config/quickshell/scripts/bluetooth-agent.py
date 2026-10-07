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

    def is_paired(self, device):
        props = dbus.Interface(self.bus.get_object(BUS_NAME, device), 'org.freedesktop.DBus.Properties')
        return bool(props.Get(DEVICE_INTERFACE, 'Paired'))

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

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        close_quick_settings()

        # Most common case (phones, modern headphones)
        # Shows the number and asks Yes/No
        message = f"Device wants to pair.\nPIN: {passkey:06d}\nConfirm?"
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
