const { app, BrowserWindow, Tray, Menu } = require('electron');

let win;
let tray;

const iconNormal = '/home/caio/Scripts/html-css-js/WhatsApp-electron/WhatsApp-icon-white.png';
const iconUnread = '/home/caio/Scripts/html-css-js/WhatsApp-electron/WhatsApp-icon-white-with-messages.png';

// Garante instância única
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    // Se já tiver uma janela aberta, apenas traz para frente
    if (win) {
      if (win.isMinimized()) win.restore();
      win.show();
      win.focus();
    }
  });

  app.on('ready', () => {
    win = new BrowserWindow({
      width: 1200,
      height: 800,
      show: false // não abre janela ao iniciar
    });

    win.loadURL('https://web.whatsapp.com');

    // Tray
    tray = new Tray(iconNormal);
    const contextMenu = Menu.buildFromTemplate([
      { label: 'Quit', click: () => { 
          app.isQuiting = true;
          app.quit(); 
        } 
      }
    ]);
    tray.setToolTip('WhatsApp');
    tray.setContextMenu(contextMenu);

    // Clique esquerdo no tray → mostra/ativa a janela
    tray.on('click', () => {
      if (win.isVisible()) {
        if (win.isMinimized()) win.restore();
        win.focus();
      } else {
        win.show();
      }
    });

    // Fechar janela → apenas esconder
    win.on('close', (event) => {
      if (!app.isQuiting) {
        event.preventDefault();
        win.hide();
      }
    });

    // Verifica mensagens não lidas pelo título da aba
    win.webContents.on('did-finish-load', () => {
      setInterval(() => {
        win.webContents.executeJavaScript(
          `document.title.includes("(")`, // WhatsApp usa "(n)" no título quando há mensagens
          true
        ).then(hasUnread => {
          if (hasUnread) {
            tray.setImage(iconUnread);
          } else {
            tray.setImage(iconNormal);
          }
        }).catch(() => {
          // se a página não estiver pronta, ignora o erro
        });
      }, 2000); // checa a cada 2s
    });
  });

  app.on('window-all-closed', (event) => {
    event.preventDefault();
  });
}
