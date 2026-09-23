#!/usr/bin/env python3

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import subprocess
import time
import os

# Configuration
BUS_NAME = 'org.bluez'
AGENT_INTERFACE = 'org.bluez.Agent1'
AGENT_PATH = '/org/bluez/agent'
LOCK_FILE = "/tmp/QsAnyModuleIsOpen"

def close_quick_settings():
    """
    Checks if the menu is open (by the existence of the file)
    and only then simulates the ESC key.
    """
    if os.path.exists(LOCK_FILE):
        try:
            # The menu is open, so we send ESC
            subprocess.run(["wtype", "-k", "Escape"], stderr=subprocess.DEVNULL)
            time.sleep(0.1)
        except Exception as e:
            print(f"wtype error: {e}")
    else:
        # The menu is NOT open. Do nothing.
        # The script proceeds directly to open the zenity dialog.
        pass

class Agent(dbus.service.Object):
    def __init__(self, bus, path):
        dbus.service.Object.__init__(self, bus, path)

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        print("Release")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # Automatically accept service connections
        return

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
            raise Exception("Rejected")

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
            raise Exception("Rejected") # User clicked No

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        close_quick_settings()

        try:
            subprocess.check_call(
                ["zenity", "--question", "--title=Bluetooth", "--text=Authorize pairing with this device?"]
            )
            return
        except:
            raise Exception("Rejected")

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
