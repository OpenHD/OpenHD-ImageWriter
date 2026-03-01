
# -*- coding: utf-8 -*-
import os
import sys
import xml.etree.ElementTree as ET


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
I18N_DIR = os.path.join(ROOT, "src", "i18n")

QML_FILES = [
    os.path.join(ROOT, "src", "main.qml"),
    os.path.join(ROOT, "src", "flash.qml"),
    os.path.join(ROOT, "src", "update.qml"),
    os.path.join(ROOT, "src", "configure.qml"),
    os.path.join(ROOT, "src", "OptionsPopup.qml"),
    os.path.join(ROOT, "src", "MsgPopup.qml"),
    os.path.join(ROOT, "src", "UseSavedSettingsPopup.qml"),
]

LANG_TS = {
    "de": os.path.join(I18N_DIR, "rpi-imager_de.ts"),
    "es": os.path.join(I18N_DIR, "rpi-imager_es.ts"),
    "it": os.path.join(I18N_DIR, "rpi-imager_it.ts"),
    "uk": os.path.join(I18N_DIR, "rpi-imager_uk.ts"),
    "ro": os.path.join(I18N_DIR, "rpi-imager_ro.ts"),
}


def _unescape_qml_string(value: str) -> str:
    # QML strings are close enough to C-style escapes for our use.
    try:
        return value.encode("utf-8").decode("unicode_escape")
    except Exception:
        return value


def extract_qsTr_strings(text: str):
    results = []
    i = 0
    while True:
        idx = text.find("qsTr(", i)
        if idx == -1:
            break
        j = idx + len("qsTr(")
        depth = 1
        in_str = False
        esc = False
        buf = []
        k = j
        while k < len(text) and depth > 0:
            ch = text[k]
            if in_str:
                if esc:
                    buf.append(ch)
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == "\"":
                    in_str = False
                    s = _unescape_qml_string("".join(buf))
                    results.append(s)
                    buf = []
                else:
                    buf.append(ch)
            else:
                if ch == "\"":
                    in_str = True
                    buf = []
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
            k += 1
        i = k
    return results


def qml_strings_by_context():
    out = {}
    for path in QML_FILES:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        ctx_name = os.path.splitext(os.path.basename(path))[0]
        strings = extract_qsTr_strings(text)
        out[ctx_name] = sorted(set(strings))
    return out


def rel_to_i18n(path: str) -> str:
    rel = os.path.relpath(path, I18N_DIR)
    return rel.replace("\\", "/")


TRANSLATIONS = {
    " ": {
        "de": " ",
        "es": " ",
        "it": " ",
        "uk": " ",
        "ro": " ",
    },
    "<b>%1</b> has been erased<br><br> You can now remove the SD card from the reader": {
        "de": "<b>%1</b> wurde gelöscht<br><br> Sie können die SD-Karte jetzt aus dem Leser entfernen",
        "es": "<b>%1</b> se ha borrado<br><br> Ya puede retirar la tarjeta SD del lector",
        "it": "<b>%1</b> è stato cancellato<br><br> Ora puoi rimuovere la scheda SD dal lettore",
        "uk": "<b>%1</b> було стерто<br><br> Тепер можна вийняти SD-карту з зчитувача",
        "ro": "<b>%1</b> a fost șters<br><br> Acum puteți scoate cardul SD din cititor",
    },
    "<b>%1</b> has been written to <b>%2</b>": {
        "de": "<b>%1</b> wurde auf <b>%2</b> geschrieben",
        "es": "<b>%1</b> se ha escrito en <b>%2</b>",
        "it": "<b>%1</b> è stato scritto su <b>%2</b>",
        "uk": "<b>%1</b> було записано на <b>%2</b>",
        "ro": "<b>%1</b> a fost scris pe <b>%2</b>",
    },
    "<b>%1</b> has been written to <b>%2</b>! You can now remove the SD card from the reader": {
        "de": "<b>%1</b> wurde auf <b>%2</b> geschrieben! Sie können die SD-Karte jetzt aus dem Leser entfernen",
        "es": "<b>%1</b> se ha escrito en <b>%2</b>! Ya puede retirar la tarjeta SD del lector",
        "it": "<b>%1</b> è stato scritto su <b>%2</b>! Ora puoi rimuovere la scheda SD dal lettore",
        "uk": "<b>%1</b> було записано на <b>%2</b>! Тепер можна вийняти SD-карту з зчитувача",
        "ro": "<b>%1</b> a fost scris pe <b>%2</b>! Acum puteți scoate cardul SD din cititor",
    },
    "<b>%1</b> was written to <b>%2</b>.<br>You can now safely remove the card.": {
        "de": "<b>%1</b> wurde auf <b>%2</b> geschrieben.<br>Sie können die Karte jetzt sicher entfernen.",
        "es": "<b>%1</b> se escribió en <b>%2</b>.<br>Ahora puede retirar la tarjeta con seguridad.",
        "it": "<b>%1</b> è stato scritto su <b>%2</b>.<br>Ora puoi rimuovere la scheda in sicurezza.",
        "uk": "<b>%1</b> було записано на <b>%2</b>.<br>Тепер можна безпечно вийняти карту.",
        "ro": "<b>%1</b> a fost scris pe <b>%2</b>.<br>Acum puteți scoate cardul în siguranță.",
    },
    "A QOpenHD.conf is already present on the drive.": {
        "de": "Eine QOpenHD.conf ist bereits auf dem Laufwerk vorhanden.",
        "es": "Ya hay un QOpenHD.conf en la unidad.",
        "it": "Un QOpenHD.conf è già presente nell'unità.",
        "uk": "Файл QOpenHD.conf вже є на диску.",
        "ro": "Un QOpenHD.conf este deja prezent pe unitate.",
    },
    "Advanced options": {
        "de": "Erweiterte Optionen",
        "es": "Opciones avanzadas",
        "it": "Opzioni avanzate",
        "uk": "Розширені параметри",
        "ro": "Opțiuni avansate",
    },
    "All existing data on <b>%1</b> will be erased.<br><b>This Device will boot as Air!</b><br>Are you sure you want to continue?": {
        "de": "Alle vorhandenen Daten auf <b>%1</b> werden gelöscht.<br><b>Dieses Gerät startet als Air!</b><br>Fortfahren?",
        "es": "Se borrarán todos los datos existentes en <b>%1</b>.<br><b>¡Este dispositivo arrancará como Air!</b><br>¿Seguro que desea continuar?",
        "it": "Tutti i dati esistenti su <b>%1</b> verranno cancellati.<br><b>Questo dispositivo avvierà come Air!</b><br>Sei sicuro di voler continuare?",
        "uk": "Усі наявні дані на <b>%1</b> буде стерто.<br><b>Цей пристрій завантажиться як Air!</b><br>Продовжити?",
        "ro": "Toate datele existente pe <b>%1</b> vor fi șterse.<br><b>Acest dispozitiv va porni ca Air!</b><br>Sunteți sigur că doriți să continuați?",
    },
    "All existing data on <b>%1</b> will be erased.<br><b>This Device will boot as Groundstation!</b><br>Are you sure you want to continue?": {
        "de": "Alle vorhandenen Daten auf <b>%1</b> werden gelöscht.<br><b>Dieses Gerät startet als Groundstation!</b><br>Fortfahren?",
        "es": "Se borrarán todos los datos existentes en <b>%1</b>.<br><b>¡Este dispositivo arrancará como Groundstation!</b><br>¿Seguro que desea continuar?",
        "it": "Tutti i dati esistenti su <b>%1</b> verranno cancellati.<br><b>Questo dispositivo avvierà come Groundstation!</b><br>Sei sicuro di voler continuare?",
        "uk": "Усі наявні дані на <b>%1</b> буде стерто.<br><b>Цей пристрій завантажиться як Groundstation!</b><br>Продовжити?",
        "ro": "Toate datele existente pe <b>%1</b> vor fi șterse.<br><b>Acest dispozitiv va porni ca Groundstation!</b><br>Sunteți sigur că doriți să continuați?",
    },
    "All existing data on <b>%1</b> will be erased.<br><br>Are you sure you want to continue?": {
        "de": "Alle vorhandenen Daten auf <b>%1</b> werden gelöscht.<br><br>Fortfahren?",
        "es": "Se borrarán todos los datos existentes en <b>%1</b>.<br><br>¿Seguro que desea continuar?",
        "it": "Tutti i dati esistenti su <b>%1</b> verranno cancellati.<br><br>Sei sicuro di voler continuare?",
        "uk": "Усі наявні дані на <b>%1</b> буде стерто.<br><br>Продовжити?",
        "ro": "Toate datele existente pe <b>%1</b> vor fi șterse.<br><br>Sunteți sigur că doriți să continuați?",
    },
    "Are you sure you want to quit?": {
        "de": "Möchten Sie wirklich beenden?",
        "es": "¿Seguro que desea salir?",
        "it": "Sei sicuro di voler uscire?",
        "uk": "Ви впевнені, що хочете вийти?",
        "ro": "Sigur doriți să ieșiți?",
    },
    "Back": {
        "de": "Zurück",
        "es": "Atrás",
        "it": "Indietro",
        "uk": "Назад",
        "ro": "Înapoi",
    },
    "Boot Mode": {
        "de": "Boot-Modus",
        "es": "Modo de arranque",
        "it": "Modalità di avvio",
        "uk": "Режим завантаження",
        "ro": "Mod de pornire",
    },
    "CANCEL VERIFY": {
        "de": "ÜBERPRÜFEN ABBRECHEN",
        "es": "CANCELAR VERIFICACIÓN",
        "it": "ANNULLA VERIFICA",
        "uk": "СКАСУВАТИ ПЕРЕВІРКУ",
        "ro": "ANULEAZĂ VERIFICAREA",
    },
    "CANCEL WRITE": {
        "de": "SCHREIBEN ABBRECHEN",
        "es": "CANCELAR ESCRITURA",
        "it": "ANNULLA SCRITTURA",
        "uk": "СКАСУВАТИ ЗАПИС",
        "ro": "ANULEAZĂ SCRIEREA",
    },
    "CHOOSE OS": {
        "de": "OS WÄHLEN",
        "es": "ELEGIR SO",
        "it": "SCEGLI SO",
        "uk": "ВИБРАТИ ОС",
        "ro": "ALEGEȚI SO",
    },
    "CHOOSE STORAGE": {
        "de": "SPEICHER WÄHLEN",
        "es": "ELEGIR ALMACENAMIENTO",
        "it": "SCEGLI ARCHIVIAZIONE",
        "uk": "ВИБРАТИ НОСІЙ",
        "ro": "ALEGEȚI STOCAREA",
    },
    "CHOOSE UPDATE": {
        "de": "UPDATE WÄHLEN",
        "es": "ELEGIR ACTUALIZACIÓN",
        "it": "SCEGLI AGGIORNAMENTO",
        "uk": "ВИБРАТИ ОНОВЛЕННЯ",
        "ro": "ALEGEȚI ACTUALIZAREA",
    },
    "CLOSE": {
        "de": "SCHLIESSEN",
        "es": "CERRAR",
        "it": "CHIUDI",
        "uk": "ЗАКРИТИ",
        "ro": "ÎNCHIDE",
    },
    "CONFIGURE": {
        "de": "KONFIGURIEREN",
        "es": "CONFIGURAR",
        "it": "CONFIGURA",
        "uk": "НАЛАШТУВАТИ",
        "ro": "CONFIGUREAZĂ",
    },
    "CONTINUE": {
        "de": "FORTFAHREN",
        "es": "CONTINUAR",
        "it": "CONTINUA",
        "uk": "ПРОДОВЖИТИ",
        "ro": "CONTINUĂ",
    },
    "Cached on your computer": {
        "de": "Auf Ihrem Computer zwischengespeichert",
        "es": "En caché en su ordenador",
        "it": "In cache sul tuo computer",
        "uk": "Кешовано на вашому комп'ютері",
        "ro": "În cache pe computerul dvs.",
    },
    "Camera": {
        "de": "Kamera",
        "es": "Cámara",
        "it": "Camera",
        "uk": "Камера",
        "ro": "Cameră",
    },
    "Camera Settings": {
        "de": "Kameraeinstellungen",
        "es": "Configuración de cámara",
        "it": "Impostazioni camera",
        "uk": "Налаштування камери",
        "ro": "Setări cameră",
    },
    "Cancelling...": {
        "de": "Wird abgebrochen...",
        "es": "Cancelando...",
        "it": "Annullamento...",
        "uk": "Скасування...",
        "ro": "Se anulează...",
    },
    "Choose File": {
        "de": "Datei wählen",
        "es": "Elegir archivo",
        "it": "Scegli file",
        "uk": "Вибрати файл",
        "ro": "Alegeți fișierul",
    },
    "Clear Selection": {
        "de": "Auswahl löschen",
        "es": "Borrar selección",
        "it": "Cancella selezione",
        "uk": "Очистити вибір",
        "ro": "Șterge selecția",
    },
    "Connect an USB stick containing images first.<br>The images must be located in the root folder of the USB stick.": {
        "de": "Schließen Sie zuerst einen USB-Stick mit Images an.<br>Die Images müssen sich im Stammordner des USB-Sticks befinden.",
        "es": "Conecte primero una memoria USB que contenga imágenes.<br>Las imágenes deben estar en la carpeta raíz de la memoria USB.",
        "it": "Collega prima una chiavetta USB contenente immagini.<br>Le immagini devono trovarsi nella cartella principale della chiavetta USB.",
        "uk": "Спочатку під’єднайте USB-накопичувач з образами.<br>Образи мають бути в кореневій теці USB-накопичувача.",
        "ro": "Conectați mai întâi un stick USB care conține imagini.<br>Imaginile trebuie să fie în folderul rădăcină al stickului USB.",
    },
    "Copying update... %1%": {
        "de": "Update wird kopiert... %1%",
        "es": "Copiando actualización... %1%",
        "it": "Copia dell'aggiornamento... %1%",
        "uk": "Копіювання оновлення... %1%",
        "ro": "Se copiază actualizarea... %1%",
    },
    "DEV": {
        "de": "DEV",
        "es": "DEV",
        "it": "DEV",
        "uk": "DEV",
        "ro": "DEV",
    },
    "Debug Mode": {
        "de": "Debug-Modus",
        "es": "Modo de depuración",
        "it": "Modalità di debug",
        "uk": "Режим налагодження",
        "ro": "Mod de depanare",
    },
    "Details": {
        "de": "Details",
        "es": "Detalles",
        "it": "Dettagli",
        "uk": "Деталі",
        "ro": "Detalii",
    },
    "Donate": {
        "de": "Spenden",
        "es": "Donar",
        "it": "Dona",
        "uk": "Пожертвувати",
        "ro": "Donează",
    },
    "EDIT SETTINGS": {
        "de": "EINSTELLUNGEN BEARBEITEN",
        "es": "EDITAR AJUSTES",
        "it": "MODIFICA IMPOSTAZIONI",
        "uk": "РЕДАГУВАТИ НАЛАШТУВАННЯ",
        "ro": "EDITEAZĂ SETĂRILE",
    },
    "Erase": {
        "de": "Löschen",
        "es": "Borrar",
        "it": "Cancella",
        "uk": "Стерти",
        "ro": "Șterge",
    },
    "Error": {
        "de": "Fehler",
        "es": "Error",
        "it": "Errore",
        "uk": "Помилка",
        "ro": "Eroare",
    },
    "Error downloading OS list from Internet": {
        "de": "Fehler beim Herunterladen der OS-Liste aus dem Internet",
        "es": "Error al descargar la lista de SO desde Internet",
        "it": "Errore nel download della lista dei SO da Internet",
        "uk": "Помилка завантаження списку ОС з Інтернету",
        "ro": "Eroare la descărcarea listei de SO de pe Internet",
    },
    "Error parsing os_list.json": {
        "de": "Fehler beim Parsen von os_list.json",
        "es": "Error al analizar os_list.json",
        "it": "Errore nell'analisi di os_list.json",
        "uk": "Помилка розбору os_list.json",
        "ro": "Eroare la parsarea os_list.json",
    },
    "Existing QOpenHD.conf on the target will be kept when no file is selected.": {
        "de": "Die vorhandene QOpenHD.conf auf dem Ziel bleibt erhalten, wenn keine Datei ausgewählt ist.",
        "es": "El QOpenHD.conf existente en el destino se conservará si no se selecciona ningún archivo.",
        "it": "Il QOpenHD.conf esistente nel target verrà mantenuto se non viene selezionato alcun file.",
        "uk": "Наявний QOpenHD.conf на цільовому носії буде збережено, якщо файл не вибрано.",
        "ro": "QOpenHD.conf existent pe destinație va fi păstrat dacă nu este selectat niciun fișier.",
    },
    "FLASH": {
        "de": "FLASHEN",
        "es": "FLASHEAR",
        "it": "FLASHARE",
        "uk": "ПРОШИТИ",
        "ro": "FLASHARE",
    },
    "Failed to copy QOpenHD.conf to the drive.": {
        "de": "QOpenHD.conf konnte nicht auf das Laufwerk kopiert werden.",
        "es": "No se pudo copiar QOpenHD.conf en la unidad.",
        "it": "Impossibile copiare QOpenHD.conf nell'unità.",
        "uk": "Не вдалося скопіювати QOpenHD.conf на диск.",
        "ro": "Nu s-a putut copia QOpenHD.conf pe unitate.",
    },
    "Failed to write settings.json to the drive.": {
        "de": "settings.json konnte nicht auf das Laufwerk geschrieben werden.",
        "es": "No se pudo escribir settings.json en la unidad.",
        "it": "Impossibile scrivere settings.json nell'unità.",
        "uk": "Не вдалося записати settings.json на диск.",
        "ro": "Nu s-a putut scrie settings.json pe unitate.",
    },
    "Finalizing...": {
        "de": "Wird abgeschlossen...",
        "es": "Finalizando...",
        "it": "Finalizzazione...",
        "uk": "Завершення...",
        "ro": "Se finalizează...",
    },
    "Format card as FAT32": {
        "de": "Karte als FAT32 formatieren",
        "es": "Formatear tarjeta como FAT32",
        "it": "Formatta scheda come FAT32",
        "uk": "Форматувати карту як FAT32",
        "ro": "Formatează cardul ca FAT32",
    },
    "Go back to main menu": {
        "de": "Zurück zum Hauptmenü",
        "es": "Volver al menú principal",
        "it": "Torna al menu principale",
        "uk": "Повернутися до головного меню",
        "ro": "Înapoi la meniul principal",
    },
    "Image was written successfully!": {
        "de": "Image wurde erfolgreich geschrieben!",
        "es": "¡La imagen se escribió correctamente!",
        "it": "L'immagine è stata scritta con successo!",
        "uk": "Образ успішно записано!",
        "ro": "Imaginea a fost scrisă cu succes!",
    },
    "Keep the existing file or select a new one to replace it.": {
        "de": "Behalten Sie die vorhandene Datei oder wählen Sie eine neue, um sie zu ersetzen.",
        "es": "Conserve el archivo existente o seleccione uno nuevo para reemplazarlo.",
        "it": "Mantieni il file esistente o selezionane uno nuovo per sostituirlo.",
        "uk": "Залиште наявний файл або виберіть новий для заміни.",
        "ro": "Păstrați fișierul existent sau selectați unul nou pentru a-l înlocui.",
    },
    "Keyboard navigation: <tab> navigate to next button <space> press button/select item <arrow up/down> go up/down in lists": {
        "de": "Tastaturnavigation: <tab> zum nächsten Button <space> Button drücken/Element auswählen <arrow up/down> in Listen hoch/runter",
        "es": "Navegación por teclado: <tab> ir al siguiente botón <space> pulsar botón/seleccionar elemento <arrow up/down> subir/bajar en listas",
        "it": "Navigazione da tastiera: <tab> vai al pulsante successivo <space> premi pulsante/seleziona elemento <arrow up/down> su/giù nelle liste",
        "uk": "Навігація клавіатурою: <tab> перейти до наступної кнопки <space> натиснути кнопку/вибрати елемент <arrow up/down> вгору/вниз у списках",
        "ro": "Navigare cu tastatura: <tab> la următorul buton <space> apasă butonul/selectează elementul <arrow up/down> sus/jos în liste",
    },
    "Keyboard: ": {
        "de": "Tastatur: ",
        "es": "Teclado: ",
        "it": "Tastiera: ",
        "uk": "Клавіатура: ",
        "ro": "Tastatură: ",
    },
    "Language": {
        "de": "Sprache",
        "es": "Idioma",
        "it": "Lingua",
        "uk": "Мова",
        "ro": "Limbă",
    },
    "Language settings": {
        "de": "Spracheinstellungen",
        "es": "Configuración de idioma",
        "it": "Impostazioni lingua",
        "uk": "Налаштування мови",
        "ro": "Setări de limbă",
    },
    "Language: ": {
        "de": "Sprache: ",
        "es": "Idioma: ",
        "it": "Lingua: ",
        "uk": "Мова: ",
        "ro": "Limbă: ",
    },
    "Local file": {
        "de": "Lokale Datei",
        "es": "Archivo local",
        "it": "File locale",
        "uk": "Локальний файл",
        "ro": "Fișier local",
    },
    "Misc Settings": {
        "de": "Sonstige Einstellungen",
        "es": "Ajustes varios",
        "it": "Impostazioni varie",
        "uk": "Інші налаштування",
        "ro": "Setări diverse",
    },
    "Mounted as %1": {
        "de": "Eingebunden als %1",
        "es": "Montado como %1",
        "it": "Montato come %1",
        "uk": "Змонтовано як %1",
        "ro": "Montat ca %1",
    },
    "NO": {
        "de": "NEIN",
        "es": "NO",
        "it": "NO",
        "uk": "НІ",
        "ro": "NU",
    },
    "NO, CLEAR SETTINGS": {
        "de": "NEIN, EINSTELLUNGEN LÖSCHEN",
        "es": "NO, BORRAR AJUSTES",
        "it": "NO, CANCELLA IMPOSTAZIONI",
        "uk": "НІ, ОЧИСТИТИ НАЛАШТУВАННЯ",
        "ro": "NU, ȘTERGE SETĂRILE",
    },
    "No QOpenHD.conf selected": {
        "de": "Keine QOpenHD.conf ausgewählt",
        "es": "No se seleccionó QOpenHD.conf",
        "it": "Nessun QOpenHD.conf selezionato",
        "uk": "QOpenHD.conf не вибрано",
        "ro": "Nu a fost selectat QOpenHD.conf",
    },
    "Online - %1 GB download": {
        "de": "Online - %1 GB Download",
        "es": "En línea - descarga de %1 GB",
        "it": "Online - download di %1 GB",
        "uk": "Онлайн - завантаження %1 ГБ",
        "ro": "Online - descărcare de %1 GB",
    },
    "OpenHD ImageWriter is still busy.<br>Are you sure you want to quit?": {
        "de": "OpenHD ImageWriter ist noch beschäftigt.<br>Möchten Sie wirklich beenden?",
        "es": "OpenHD ImageWriter aún está ocupado.<br>¿Seguro que desea salir?",
        "it": "OpenHD ImageWriter è ancora occupato.<br>Sei sicuro di voler uscire?",
        "uk": "OpenHD ImageWriter ще працює.<br>Ви впевнені, що хочете вийти?",
        "ro": "OpenHD ImageWriter este încă ocupat.<br>Sigur doriți să ieșiți?",
    },
    "OpenHD ImageWriter v%1": {
        "de": "OpenHD ImageWriter v%1",
        "es": "OpenHD ImageWriter v%1",
        "it": "OpenHD ImageWriter v%1",
        "uk": "OpenHD ImageWriter v%1",
        "ro": "OpenHD ImageWriter v%1",
    },
    "Operating System": {
        "de": "Betriebssystem",
        "es": "Sistema operativo",
        "it": "Sistema operativo",
        "uk": "Операційна система",
        "ro": "Sistem de operare",
    },
    "Preparing to write...": {
        "de": "Vorbereiten des Schreibvorgangs...",
        "es": "Preparando la escritura...",
        "it": "Preparazione della scrittura...",
        "uk": "Підготовка до запису...",
        "ro": "Se pregătește scrierea...",
    },
    "Preparing to write... (%1)": {
        "de": "Vorbereiten des Schreibvorgangs... (%1)",
        "es": "Preparando la escritura... (%1)",
        "it": "Preparazione della scrittura... (%1)",
        "uk": "Підготовка до запису... (%1)",
        "ro": "Se pregătește scrierea... (%1)",
    },
    "Preparing update transfer...": {
        "de": "Update-Übertragung wird vorbereitet...",
        "es": "Preparando la transferencia de actualización...",
        "it": "Preparazione del trasferimento dell'aggiornamento...",
        "uk": "Підготовка передачі оновлення...",
        "ro": "Se pregătește transferul actualizării...",
    },
    "All files (*)": {
        "de": "Alle Dateien (*)",
        "es": "Todos los archivos (*)",
        "it": "Tutti i file (*)",
        "uk": "Усі файли (*)",
        "ro": "Toate fișierele (*)",
    },
    "QOpenHD.conf (*.conf)": {
        "de": "QOpenHD.conf (*.conf)",
        "es": "QOpenHD.conf (*.conf)",
        "it": "QOpenHD.conf (*.conf)",
        "uk": "QOpenHD.conf (*.conf)",
        "ro": "QOpenHD.conf (*.conf)",
    },
    "QOpenHD.conf": {
        "de": "QOpenHD.conf",
        "es": "QOpenHD.conf",
        "it": "QOpenHD.conf",
        "uk": "QOpenHD.conf",
        "ro": "QOpenHD.conf",
    },
    "QUIT": {
        "de": "BEENDEN",
        "es": "SALIR",
        "it": "ESCI",
        "uk": "ВИЙТИ",
        "ro": "IEȘIRE",
    },
    "READ SETTINGS": {
        "de": "EINSTELLUNGEN LESEN",
        "es": "LEER AJUSTES",
        "it": "LEGGI IMPOSTAZIONI",
        "uk": "ЗЧИТАТИ НАЛАШТУВАННЯ",
        "ro": "CITEȘTE SETĂRILE",
    },
    "Released: %1": {
        "de": "Veröffentlicht: %1",
        "es": "Publicado: %1",
        "it": "Rilasciato: %1",
        "uk": "Випущено: %1",
        "ro": "Lansat: %1",
    },
    "SAVE": {
        "de": "SPEICHERN",
        "es": "GUARDAR",
        "it": "SALVA",
        "uk": "ЗБЕРЕГТИ",
        "ro": "SALVEAZĂ",
    },
    "SD card is write protected.<br>Push the lock switch on the left side of the card upwards, and try again.": {
        "de": "Die SD-Karte ist schreibgeschützt.<br>Schieben Sie den Sperrschalter an der linken Seite der Karte nach oben und versuchen Sie es erneut.",
        "es": "La tarjeta SD está protegida contra escritura.<br>Deslice el interruptor de bloqueo en el lado izquierdo de la tarjeta hacia arriba e inténtelo de nuevo.",
        "it": "La scheda SD è protetta da scrittura.<br>Spingi verso l'alto l'interruttore di blocco sul lato sinistro della scheda e riprova.",
        "uk": "SD-карта захищена від запису.<br>Посуньте перемикач блокування на лівому боці карти вгору та спробуйте знову.",
        "ro": "Cardul SD este protejat la scriere.<br>Glisați comutatorul de blocare de pe partea stângă a cardului în sus și încercați din nou.",
    },
    "Select QOpenHD.conf": {
        "de": "QOpenHD.conf auswählen",
        "es": "Seleccionar QOpenHD.conf",
        "it": "Seleziona QOpenHD.conf",
        "uk": "Вибрати QOpenHD.conf",
        "ro": "Selectați QOpenHD.conf",
    },
    "Select a custom .img from your computer": {
        "de": "Wählen Sie eine benutzerdefinierte .img von Ihrem Computer",
        "es": "Selecciona un .img personalizado de tu ordenador",
        "it": "Seleziona un .img personalizzato dal tuo computer",
        "uk": "Виберіть власний .img з вашого комп'ютера",
        "ro": "Selectați un .img personalizat de pe computer",
    },
    "Select this button to change the destination storage device": {
        "de": "Wählen Sie diese Schaltfläche, um das Ziel-Speichergerät zu ändern",
        "es": "Seleccione este botón para cambiar el dispositivo de almacenamiento de destino",
        "it": "Seleziona questo pulsante per cambiare il dispositivo di archiviazione di destinazione",
        "uk": "Натисніть цю кнопку, щоб змінити цільовий носій",
        "ro": "Selectați acest buton pentru a schimba dispozitivul de stocare de destinație",
    },
    "Select this button to change the operating system": {
        "de": "Wählen Sie diese Schaltfläche, um das Betriebssystem zu ändern",
        "es": "Seleccione este botón para cambiar el sistema operativo",
        "it": "Seleziona questo pulsante per cambiare il sistema operativo",
        "uk": "Натисніть цю кнопку, щоб змінити операційну систему",
        "ro": "Selectați acest buton pentru a schimba sistemul de operare",
    },
    "Select this button to configure Settings": {
        "de": "Wählen Sie diese Schaltfläche, um die Einstellungen zu konfigurieren",
        "es": "Seleccione este botón para configurar los ajustes",
        "it": "Seleziona questo pulsante per configurare le impostazioni",
        "uk": "Натисніть цю кнопку, щоб налаштувати параметри",
        "ro": "Selectați acest buton pentru a configura setările",
    },
    "Select this button to configure language": {
        "de": "Wählen Sie diese Schaltfläche, um die Sprache zu konfigurieren",
        "es": "Seleccione este botón para configurar el idioma",
        "it": "Seleziona questo pulsante per configurare la lingua",
        "uk": "Натисніть цю кнопку, щоб налаштувати мову",
        "ro": "Selectați acest buton pentru a configura limba",
    },
    "Select this button to start writing the image": {
        "de": "Wählen Sie diese Schaltfläche, um das Schreiben des Images zu starten",
        "es": "Seleccione este botón para empezar a escribir la imagen",
        "it": "Seleziona questo pulsante per avviare la scrittura dell'immagine",
        "uk": "Натисніть цю кнопку, щоб почати запис образу",
        "ro": "Selectați acest buton pentru a începe scrierea imaginii",
    },
    "Set SBC to %1": {
        "de": "SBC auf %1 setzen",
        "es": "Establecer SBC en %1",
        "it": "Imposta SBC su %1",
        "uk": "Встановити SBC на %1",
        "ro": "Setează SBC la %1",
    },
    "Settings were written to <b>%1</b>.": {
        "de": "Einstellungen wurden auf <b>%1</b> geschrieben.",
        "es": "Los ajustes se escribieron en <b>%1</b>.",
        "it": "Le impostazioni sono state scritte su <b>%1</b>.",
        "uk": "Налаштування записано на <b>%1</b>.",
        "ro": "Setările au fost scrise pe <b>%1</b>.",
    },
    "Settings written": {
        "de": "Einstellungen geschrieben",
        "es": "Ajustes escritos",
        "it": "Impostazioni scritte",
        "uk": "Налаштування записано",
        "ro": "Setări scrise",
    },
    "Storage": {
        "de": "Speicher",
        "es": "Almacenamiento",
        "it": "Archiviazione",
        "uk": "Сховище",
        "ro": "Stocare",
    },
    "The update package will be copied to <b>%1</b>.<br><b>This Device will boot as Air!</b><br>Are you sure you want to continue?": {
        "de": "Das Update-Paket wird nach <b>%1</b> kopiert.<br><b>Dieses Gerät startet als Air!</b><br>Fortfahren?",
        "es": "El paquete de actualización se copiará en <b>%1</b>.<br><b>¡Este dispositivo arrancará como Air!</b><br>¿Seguro que desea continuar?",
        "it": "Il pacchetto di aggiornamento verrà copiato su <b>%1</b>.<br><b>Questo dispositivo avvierà come Air!</b><br>Sei sicuro di voler continuare?",
        "uk": "Пакет оновлення буде скопійовано на <b>%1</b>.<br><b>Цей пристрій завантажиться як Air!</b><br>Продовжити?",
        "ro": "Pachetul de actualizare va fi copiat pe <b>%1</b>.<br><b>Acest dispozitiv va porni ca Air!</b><br>Sunteți sigur că doriți să continuați?",
    },
    "The update package will be copied to <b>%1</b>.<br><b>This Device will boot as Groundstation!</b><br>Are you sure you want to continue?": {
        "de": "Das Update-Paket wird nach <b>%1</b> kopiert.<br><b>Dieses Gerät startet als Groundstation!</b><br>Fortfahren?",
        "es": "El paquete de actualización se copiará en <b>%1</b>.<br><b>¡Este dispositivo arrancará como Groundstation!</b><br>¿Seguro que desea continuar?",
        "it": "Il pacchetto di aggiornamento verrà copiato su <b>%1</b>.<br><b>Questo dispositivo avvierà come Groundstation!</b><br>Sei sicuro di voler continuare?",
        "uk": "Пакет оновлення буде скопійовано на <b>%1</b>.<br><b>Цей пристрій завантажиться як Groundstation!</b><br>Продовжити?",
        "ro": "Pachetul de actualizare va fi copiat pe <b>%1</b>.<br><b>Acest dispozitiv va porni ca Groundstation!</b><br>Sunteți sigur că doriți să continuați?",
    },
    "The update package will be copied to <b>%1</b>.<br><br>Are you sure you want to continue?": {
        "de": "Das Update-Paket wird nach <b>%1</b> kopiert.<br><br>Fortfahren?",
        "es": "El paquete de actualización se copiará en <b>%1</b>.<br><br>¿Seguro que desea continuar?",
        "it": "Il pacchetto di aggiornamento verrà copiato su <b>%1</b>.<br><br>Sei sicuro di voler continuare?",
        "uk": "Пакет оновлення буде скопійовано на <b>%1</b>.<br><br>Продовжити?",
        "ro": "Pachetul de actualizare va fi copiat pe <b>%1</b>.<br><br>Sunteți sigur că doriți să continuați?",
    },
    "There is a newer version of the ImageWriter is available.<br>Would you like to visit the website to download it?": {
        "de": "Eine neuere Version des ImageWriter ist verfügbar.<br>Möchten Sie die Website besuchen, um sie herunterzuladen?",
        "es": "Hay una versión más reciente de ImageWriter disponible.<br>¿Desea visitar el sitio web para descargarla?",
        "it": "È disponibile una versione più recente di ImageWriter.<br>Vuoi visitare il sito web per scaricarla?",
        "uk": "Доступна новіша версія ImageWriter.<br>Бажаєте відвідати вебсайт, щоб завантажити її?",
        "ro": "Este disponibilă o versiune mai nouă a ImageWriter.<br>Doriți să vizitați site-ul pentru a o descărca?",
    },
    "UPDATE": {
        "de": "AKTUALISIEREN",
        "es": "ACTUALIZAR",
        "it": "AGGIORNA",
        "uk": "ОНОВИТИ",
        "ro": "ACTUALIZEAZĂ",
    },
    "Update available": {
        "de": "Update verfügbar",
        "es": "Actualización disponible",
        "it": "Aggiornamento disponibile",
        "uk": "Доступне оновлення",
        "ro": "Actualizare disponibilă",
    },
    "Update written": {
        "de": "Update geschrieben",
        "es": "Actualización escrita",
        "it": "Aggiornamento scritto",
        "uk": "Оновлення записано",
        "ro": "Actualizare scrisă",
    },
    "Use custom": {
        "de": "Benutzerdefiniert",
        "es": "Usar personalizado",
        "it": "Usa personalizzato",
        "uk": "Використати власний",
        "ro": "Folosește personalizat",
    },
    "Using custom repository: %1": {
        "de": "Benutzerdefiniertes Repository: %1",
        "es": "Usando repositorio personalizado: %1",
        "it": "Uso del repository personalizzato: %1",
        "uk": "Використовується власне сховище: %1",
        "ro": "Se folosește un depozit personalizat: %1",
    },
    "Verifying... %1%": {
        "de": "Überprüfung... %1%",
        "es": "Verificando... %1%",
        "it": "Verifica... %1%",
        "uk": "Перевірка... %1%",
        "ro": "Se verifică... %1%",
    },
    "WRITE": {
        "de": "SCHREIBEN",
        "es": "ESCRIBIR",
        "it": "SCRIVI",
        "uk": "ЗАПИСАТИ",
        "ro": "SCRIE",
    },
    "WRITE SETTINGS": {
        "de": "EINSTELLUNGEN SCHREIBEN",
        "es": "ESCRIBIR AJUSTES",
        "it": "SCRIVI IMPOSTAZIONI",
        "uk": "ЗАПИСАТИ НАЛАШТУВАННЯ",
        "ro": "SCRIE SETĂRILE",
    },
    "Warning": {
        "de": "Warnung",
        "es": "Advertencia",
        "it": "Avviso",
        "uk": "Попередження",
        "ro": "Avertisment",
    },
    "Warning: advanced settings set": {
        "de": "Warnung: Erweiterte Einstellungen gesetzt",
        "es": "Advertencia: ajustes avanzados establecidos",
        "it": "Avviso: impostazioni avanzate impostate",
        "uk": "Попередження: розширені налаштування встановлено",
        "ro": "Avertisment: setările avansate sunt setate",
    },
    "WifiHotspot": {
        "de": "WLAN-Hotspot",
        "es": "Punto de acceso WiFi",
        "it": "Hotspot WiFi",
        "uk": "Wi-Fi точка доступу",
        "ro": "Hotspot WiFi",
    },
    "Would you like to apply the image customization settings saved earlier?": {
        "de": "Möchten Sie die zuvor gespeicherten Image-Anpassungseinstellungen anwenden?",
        "es": "¿Desea aplicar los ajustes de personalización de la imagen guardados anteriormente?",
        "it": "Vuoi applicare le impostazioni di personalizzazione dell'immagine salvate in precedenza?",
        "uk": "Бажаєте застосувати раніше збережені налаштування персоналізації образу?",
        "ro": "Doriți să aplicați setările de personalizare a imaginii salvate anterior?",
    },
    "YES": {
        "de": "JA",
        "es": "SÍ",
        "it": "SÌ",
        "uk": "ТАК",
        "ro": "DA",
    },
    "[WRITE PROTECTED]": {
        "de": "[SCHREIBGESCHÜTZT]",
        "es": "[PROTEGIDO CONTRA ESCRITURA]",
        "it": "[PROTETTO DA SCRITTURA]",
        "uk": "[ЗАХИЩЕНО ВІД ЗАПИСУ]",
        "ro": "[PROTEJAT LA SCRIERE]",
    },
    "Writing... %1% (%2 MB/s)": {
        "de": "Schreiben... %1% (%2 MB/s)",
        "es": "Escribiendo... %1% (%2 MB/s)",
        "it": "Scrittura... %1% (%2 MB/s)",
        "uk": "Запис... %1% (%2 МБ/с)",
        "ro": "Se scrie... %1% (%2 MB/s)",
    },
    "Writing... %1% (%2 Mbit/s)": {
        "de": "Schreiben... %1% (%2 Mbit/s)",
        "es": "Escribiendo... %1% (%2 Mbit/s)",
        "it": "Scrittura... %1% (%2 Mbit/s)",
        "uk": "Запис... %1% (%2 Мбіт/с)",
        "ro": "Se scrie... %1% (%2 Mbit/s)",
    },
}


def ensure_context(root, name):
    for ctx in root.findall("context"):
        n = ctx.find("name")
        if n is not None and n.text == name:
            return ctx
    ctx = ET.Element("context")
    name_el = ET.SubElement(ctx, "name")
    name_el.text = name
    root.append(ctx)
    return ctx


def find_message(ctx, source_text):
    for msg in ctx.findall("message"):
        src = msg.find("source")
        if src is not None and src.text == source_text:
            return msg
    return None


def update_ts(ts_path, qml_map):
    tree = ET.parse(ts_path)
    root = tree.getroot()

    missing = []
    updated = 0
    created = 0

    for ctx_name, strings in qml_map.items():
        ctx = ensure_context(root, ctx_name)
        for s in strings:
            msg = find_message(ctx, s)
            if msg is None:
                msg = ET.SubElement(ctx, "message")
                loc = ET.SubElement(msg, "location")
                loc.set("filename", rel_to_i18n(os.path.join(ROOT, "src", ctx_name + ".qml")))
                loc.set("line", "1")
                src = ET.SubElement(msg, "source")
                src.text = s
                tr = ET.SubElement(msg, "translation")
                tr.set("type", "unfinished")
                created += 1
            tr = msg.find("translation")
            if tr is None:
                tr = ET.SubElement(msg, "translation")

            lang_code = None
            for code, path in LANG_TS.items():
                if os.path.abspath(path) == os.path.abspath(ts_path):
                    lang_code = code
                    break
            if not lang_code:
                continue

            if s not in TRANSLATIONS or lang_code not in TRANSLATIONS[s]:
                missing.append(s)
                continue

            if tr.text is None or tr.text == "" or tr.get("type") == "unfinished":
                tr.text = TRANSLATIONS[s][lang_code]
                tr.attrib.pop("type", None)
                updated += 1

    ET.indent(tree, space="    ")
    xml_body = ET.tostring(root, encoding="utf-8")
    with open(ts_path, "wb") as f:
        f.write(b'<?xml version="1.0" encoding="utf-8"?>\n')
        f.write(b"<!DOCTYPE TS>\n")
        f.write(xml_body)
        f.write(b"\n")

    return created, updated, missing


def main():
    qml_map = qml_strings_by_context()

    any_missing = False
    for lang, ts_path in LANG_TS.items():
        created, updated, missing = update_ts(ts_path, qml_map)
        if missing:
            any_missing = True
            unique_missing = sorted(set(missing))
            print(f"[{lang}] Missing translations for {len(unique_missing)} strings:")
            for s in unique_missing:
                print(f"  - {s}")
        print(f"[{lang}] created {created} messages, updated {updated} translations")

    if any_missing:
        sys.exit(2)


if __name__ == "__main__":
    main()
