#!/usr/bin/env python3

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import subprocess
import time
import os

# Configuração
BUS_NAME = 'org.bluez'
AGENT_INTERFACE = 'org.bluez.Agent1'
AGENT_PATH = '/org/bluez/agent'
LOCK_FILE = "/tmp/QsAnyModuleIsOpen"

def close_quick_settings():
    """
    Verifica se o menu está aberto (pela existência do arquivo)
    e só então simula o ESC.
    """
    if os.path.exists(LOCK_FILE):
        try:
            # O menu está aberto, então enviamos o ESC
            subprocess.run(["wtype", "-k", "Escape"], stderr=subprocess.DEVNULL)
            time.sleep(0.1)
        except Exception as e:
            print(f"Erro no wtype: {e}")
    else:
        # O menu NÃO está aberto. Não fazemos nada.
        # O script segue direto para abrir o kdialog.
        pass

class Agent(dbus.service.Object):
    def __init__(self, bus, path):
        dbus.service.Object.__init__(self, bus, path)

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        print("Release")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        # Aceita conexões de serviço automaticamente
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        close_quick_settings()
        # Para teclados antigos que pedem PIN manual
        try:
            output = subprocess.check_output(
                ["kdialog", "--title", "Bluetooth", "--inputbox", "Digite o PIN do dispositivo:"]
            )
            return output.decode().strip()
        except subprocess.CalledProcessError:
            raise Exception("Rejected")

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        close_quick_settings()

        # O caso mais comum (Celulares, Fones modernos)
        # Mostra o numero e pede Sim/Não
        message = f"Dispositivo deseja parear.\nPIN: {passkey:06d}\nConfirma?"
        try:
            subprocess.check_call(
                ["kdialog", "--title", "Pareamento Bluetooth", "--yesno", message]
            )
            return
        except subprocess.CalledProcessError:
            raise Exception("Rejected") # Usuário clicou em Não

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        close_quick_settings()

        try:
            subprocess.check_call(
                ["kdialog", "--title", "Bluetooth", "--yesno", "Autorizar pareamento com este dispositivo?"]
            )
            return
        except:
            raise Exception("Rejected")

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancelado pelo sistema")

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    
    # Inicia o Agente
    agent = Agent(bus, AGENT_PATH)
    
    # Registra o Agente no BlueZ
    obj = bus.get_object(BUS_NAME, "/org/bluez")
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    
    # Registra como o agente padrão (NoInputNoOutput, DisplayOnly, DisplayYesNo, KeyboardDisplay, KeyboardOnly)
    # KeyboardDisplay é o mais versátil para PCs
    manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
    manager.RequestDefaultAgent(AGENT_PATH)

    print("Agente Bluetooth rodando... Aguardando requisições.")
    
    mainloop = GLib.MainLoop()
    mainloop.run()
