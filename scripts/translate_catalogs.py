"""Fill Qt catalogs with local Argos models (ctranslate2, sentencepiece, requests).

Run lupdate first, then run this script with --models pointing to an ignored
build directory. Existing translations are retained; common UI labels use the
explicit glossary below. Translation models are downloaded from the Argos index.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter

import ctranslate2
import requests
import sentencepiece
from auto_translate_qml import TRANSLATIONS as EXISTING_GLOSSARY

LANGUAGES = "ca es fr it ja ko nl ro sk sl tr uk zh".split()
# Columns follow LANGUAGES. Keep action labels consistent across UI contexts.
LABELS = {
    "Settings": ["Configuració", "Ajustes", "Paramètres", "Impostazioni", "設定", "설정", "Instellingen", "Setări", "Nastavenia", "Nastavitve", "Ayarlar", "Налаштування", "设置"],
    "Language": ["Idioma", "Idioma", "Langue", "Lingua", "言語", "언어", "Taal", "Limbă", "Jazyk", "Jezik", "Dil", "Мова", "语言"],
    "Application": ["Aplicació", "Aplicación", "Application", "Applicazione", "アプリケーション", "애플리케이션", "Applicatie", "Aplicație", "Aplikácia", "Aplikacija", "Uygulama", "Застосунок", "应用"],
    "Operator": ["Operador", "Operador", "Opérateur", "Operatore", "オペレーター", "운영자", "Operator", "Operator", "Operátor", "Operater", "Operatör", "Оператор", "操作员"],
    "Update complete": ["Actualització completada", "Actualización completada", "Mise à jour terminée", "Aggiornamento completato", "更新完了", "업데이트 완료", "Update voltooid", "Actualizare finalizată", "Aktualizácia dokončená", "Posodobitev končana", "Güncelleme tamamlandı", "Оновлення завершено", "更新完成"],
    "Home": ["Inici", "Inicio", "Accueil", "Home", "ホーム", "홈", "Startpagina", "Acasă", "Domov", "Domov", "Ana sayfa", "Головна", "主页"],
    "Help": ["Ajuda", "Ayuda", "Aide", "Aiuto", "ヘルプ", "도움말", "Help", "Ajutor", "Pomoc", "Pomoč", "Yardım", "Довідка", "帮助"],
    "Refresh": ["Actualitza", "Actualizar", "Actualiser", "Aggiorna", "更新", "새로 고침", "Vernieuwen", "Reîmprospătare", "Obnoviť", "Osveži", "Yenile", "Оновити", "刷新"],
    "Cancel": ["Cancel·la", "Cancelar", "Annuler", "Annulla", "キャンセル", "취소", "Annuleren", "Anulare", "Zrušiť", "Prekliči", "İptal", "Скасувати", "取消"],
    "Clear": ["Esborra la selecció", "Borrar selección", "Effacer la sélection", "Cancella selezione", "選択を解除", "선택 지우기", "Selectie wissen", "Șterge selecția", "Vymazať výber", "Počisti izbiro", "Seçimi temizle", "Очистити вибір", "清除选择"],
    "Apply": ["Aplica", "Aplicar", "Appliquer", "Applica", "適用", "적용", "Toepassen", "Aplică", "Použiť", "Uporabi", "Uygula", "Застосувати", "应用"],
    "Save and return": ["Desa i torna", "Guardar y volver", "Enregistrer et revenir", "Salva e torna", "保存して戻る", "저장 후 돌아가기", "Opslaan en teruggaan", "Salvează și revino", "Uložiť a vrátiť sa", "Shrani in se vrni", "Kaydet ve geri dön", "Зберегти й повернутися", "保存并返回"],
    "Save profile": ["Desa el perfil", "Guardar perfil", "Enregistrer le profil", "Salva profilo", "プロファイルを保存", "프로필 저장", "Profiel opslaan", "Salvează profilul", "Uložiť profil", "Shrani profil", "Profili kaydet", "Зберегти профіль", "保存配置"],
    "Saving...": ["S'està desant...", "Guardando...", "Enregistrement...", "Salvataggio...", "保存中...", "저장 중...", "Opslaan...", "Se salvează...", "Ukladanie...", "Shranjevanje...", "Kaydediliyor...", "Збереження...", "正在保存..."],
    "Sign out": ["Tanca la sessió", "Cerrar sesión", "Se déconnecter", "Esci", "ログアウト", "로그아웃", "Afmelden", "Deconectare", "Odhlásiť sa", "Odjava", "Oturumu kapat", "Вийти", "退出登录"],
    "Secure sign in": ["Inici de sessió segur", "Inicio de sesión seguro", "Connexion sécurisée", "Accesso sicuro", "安全なログイン", "보안 로그인", "Veilig aanmelden", "Autentificare securizată", "Zabezpečené prihlásenie", "Varna prijava", "Güvenli oturum açma", "Безпечний вхід", "安全登录"],
    "AUTHENTICATE": ["INICIA LA SESSIÓ", "INICIAR SESIÓN", "SE CONNECTER", "ACCEDI", "ログイン", "로그인", "AANMELDEN", "AUTENTIFICARE", "PRIHLÁSIŤ SA", "PRIJAVA", "OTURUM AÇ", "УВІЙТИ", "登录"],
    "AUTHENTICATING": ["S'ESTÀ INICIANT LA SESSIÓ", "INICIANDO SESIÓN", "CONNEXION EN COURS", "ACCESSO IN CORSO", "ログイン中", "로그인 중", "AANMELDEN...", "AUTENTIFICARE ÎN CURS", "PRIHLASOVANIE", "PRIJAVLJANJE", "OTURUM AÇILIYOR", "ВХІД...", "正在登录"],
    "SESSION ACTIVE": ["SESSIÓ ACTIVA", "SESIÓN ACTIVA", "SESSION ACTIVE", "SESSIONE ATTIVA", "セッション有効", "세션 활성", "SESSIE ACTIEF", "SESIUNE ACTIVĂ", "AKTÍVNA RELÁCIA", "AKTIVNA SEJA", "OTURUM ETKİN", "СЕАНС АКТИВНИЙ", "会话已激活"],
    "Choose image": ["Tria una imatge", "Elegir imagen", "Choisir une image", "Scegli immagine", "イメージを選択", "이미지 선택", "Image kiezen", "Alege imaginea", "Vybrať obraz", "Izberi sliko", "İmaj seç", "Вибрати образ", "选择镜像"],
    "Write image": ["Escriu la imatge", "Escribir imagen", "Écrire l'image", "Scrivi immagine", "イメージを書き込む", "이미지 쓰기", "Image schrijven", "Scrie imaginea", "Zapísať obraz", "Zapiši sliko", "İmajı yaz", "Записати образ", "写入镜像"],
    "Skip verification": ["Omet la verificació", "Omitir verificación", "Ignorer la vérification", "Salta verifica", "検証をスキップ", "검증 건너뛰기", "Verificatie overslaan", "Omite verificarea", "Preskočiť overenie", "Preskoči preverjanje", "Doğrulamayı atla", "Пропустити перевірку", "跳过验证"],
    "Review and write": ["Revisa i escriu", "Revisar y escribir", "Vérifier et écrire", "Verifica e scrivi", "確認して書き込む", "검토 후 쓰기", "Controleren en schrijven", "Verifică și scrie", "Skontrolovať a zapísať", "Preglej in zapiši", "İncele ve yaz", "Перевірити й записати", "检查并写入"],
    "Official": ["Oficial", "Oficial", "Officiel", "Ufficiale", "公式", "공식", "Officieel", "Oficial", "Oficiálne", "Uradno", "Resmî", "Офіційні", "官方"],
    "None": ["Cap", "Ninguna", "Aucune", "Nessuna", "なし", "없음", "Geen", "Niciuna", "Žiadna", "Brez", "Yok", "Немає", "无"],
    "Network": ["Xarxa", "Red", "Réseau", "Rete", "ネットワーク", "네트워크", "Netwerk", "Rețea", "Sieť", "Omrežje", "Ağ", "Мережа", "网络"],
    "General": ["General", "General", "Général", "Generale", "一般", "일반", "Algemeen", "General", "Všeobecné", "Splošno", "Genel", "Загальні", "常规"],
    "Advanced": ["Avançat", "Avanzado", "Avancé", "Avanzate", "詳細", "고급", "Geavanceerd", "Avansat", "Rozšírené", "Napredno", "Gelişmiş", "Розширені", "高级"],
    "Air": ["Unitat aèria", "Unidad aérea", "Unité aérienne", "Unità aerea", "機上ユニット", "기체 유닛", "Luchteenheid", "Unitate aeriană", "Vzdušná jednotka", "Zračna enota", "Hava birimi", "Повітряний модуль", "机载端"],
    "Ground": ["Estació de terra", "Estación terrestre", "Station au sol", "Stazione di terra", "地上局", "지상국", "Grondstation", "Stație de sol", "Pozemná stanica", "Zemeljska postaja", "Yer istasyonu", "Наземна станція", "地面站"],
    "Primary resolution": ["Resolució de la càmera principal", "Resolución de la cámara principal", "Résolution de la caméra principale", "Risoluzione della telecamera principale", "メインカメラの解像度", "기본 카메라 해상도", "Resolutie primaire camera", "Rezoluția camerei principale", "Rozlíšenie hlavnej kamery", "Ločljivost glavne kamere", "Birincil kamera çözünürlüğü", "Роздільність основної камери", "主摄像头分辨率"],
    "Secondary resolution": ["Resolució de la càmera secundària", "Resolución de la cámara secundaria", "Résolution de la caméra secondaire", "Risoluzione della telecamera secondaria", "サブカメラの解像度", "보조 카메라 해상도", "Resolutie secundaire camera", "Rezoluția camerei secundare", "Rozlíšenie vedľajšej kamery", "Ločljivost sekundarne kamere", "İkincil kamera çözünürlüğü", "Роздільність додаткової камери", "副摄像头分辨率"],
    "Refresh rate (Hz)": ["Freqüència d'actualització (Hz)", "Frecuencia de actualización (Hz)", "Fréquence de rafraîchissement (Hz)", "Frequenza di aggiornamento (Hz)", "リフレッシュレート (Hz)", "새로 고침 빈도 (Hz)", "Verversingssnelheid (Hz)", "Rată de reîmprospătare (Hz)", "Obnovovacia frekvencia (Hz)", "Hitrost osveževanja (Hz)", "Yenileme hızı (Hz)", "Частота оновлення (Гц)", "刷新率 (Hz)"],
    "Image": ["Imatge", "Imagen", "Image", "Immagine", "イメージ", "이미지", "Image", "Imagine", "Obraz", "Slika", "İmaj", "Образ", "镜像"],
    "Source image": ["Imatge d'origen", "Imagen de origen", "Image source", "Immagine sorgente", "書き込み元イメージ", "원본 이미지", "Bronimage", "Imagine sursă", "Zdrojový obraz", "Izvorna slika", "Kaynak imaj", "Вихідний образ", "源镜像"],
    "Local Images": ["Imatges locals", "Imágenes locales", "Images locales", "Immagini locali", "ローカルイメージ", "로컬 이미지", "Lokale images", "Imagini locale", "Lokálne obrazy", "Lokalne slike", "Yerel imajlar", "Локальні образи", "本地镜像"],
    "Use custom image": ["Utilitza una imatge pròpia", "Usar imagen personalizada", "Utiliser une image personnalisée", "Usa immagine personalizzata", "カスタムイメージを使用", "사용자 지정 이미지 사용", "Eigen image gebruiken", "Folosește o imagine personalizată", "Použiť vlastný obraz", "Uporabi lastno sliko", "Özel imaj kullan", "Використати власний образ", "使用自定义镜像"],
    "Configure image": ["Configura la imatge", "Configurar imagen", "Configurer l'image", "Configura immagine", "イメージを設定", "이미지 설정", "Image configureren", "Configurează imaginea", "Nastaviť obraz", "Nastavi sliko", "İmajı yapılandır", "Налаштувати образ", "配置镜像"],
    "Writing image": ["S'està escrivint la imatge", "Escribiendo imagen", "Écriture de l'image", "Scrittura dell'immagine", "イメージ書き込み中", "이미지 쓰는 중", "Image wordt geschreven", "Se scrie imaginea", "Zapisovanie obrazu", "Zapisovanje slike", "İmaj yazılıyor", "Запис образу", "正在写入镜像"],
    "Target device": ["Dispositiu de destinació", "Dispositivo de destino", "Périphérique cible", "Dispositivo di destinazione", "書き込み先デバイス", "대상 장치", "Doelapparaat", "Dispozitiv țintă", "Cieľové zariadenie", "Ciljna naprava", "Hedef cihaz", "Цільовий пристрій", "目标设备"],
    "Erase / Format": ["Esborra / Formata", "Borrar / Formatear", "Effacer / Formater", "Cancella / Formatta", "消去 / フォーマット", "지우기 / 포맷", "Wissen / Formatteren", "Șterge / Formatează", "Vymazať / Formátovať", "Izbriši / Formatiraj", "Sil / Biçimlendir", "Стерти / Форматувати", "擦除 / 格式化"],
    "OpenHD settings": ["Configuració d'OpenHD", "Ajustes de OpenHD", "Paramètres OpenHD", "Impostazioni OpenHD", "OpenHD の設定", "OpenHD 설정", "OpenHD-instellingen", "Setări OpenHD", "Nastavenia OpenHD", "Nastavitve OpenHD", "OpenHD ayarları", "Налаштування OpenHD", "OpenHD 设置"],
    "Flashing %1 (%2 MB)...": ["S'està escrivint %1 (%2 MB)...", "Escribiendo %1 (%2 MB)...", "Écriture de %1 (%2 MB)...", "Scrittura di %1 (%2 MB)...", "%1 を書き込み中 (%2 MB)...", "%1 쓰는 중 (%2 MB)...", "%1 wordt geschreven (%2 MB)...", "Se scrie %1 (%2 MB)...", "Zapisovanie %1 (%2 MB)...", "Zapisovanje %1 (%2 MB)...", "%1 yazılıyor (%2 MB)...", "Запис %1 (%2 MB)...", "正在写入 %1 (%2 MB)..."],
    "Donate": ["Fes una donació", "Donar", "Faire un don", "Dona", "寄付", "기부", "Doneren", "Donează", "Prispieť", "Doniraj", "Bağış yap", "Підтримати", "捐赠"],
    "Back": ["Enrere", "Atrás", "Retour", "Indietro", "戻る", "뒤로", "Terug", "Înapoi", "Späť", "Nazaj", "Geri", "Назад", "返回"],
    "Close": ["Tanca", "Cerrar", "Fermer", "Chiudi", "閉じる", "닫기", "Sluiten", "Închide", "Zavrieť", "Zapri", "Kapat", "Закрити", "关闭"],
    "More": ["Més", "Más", "Plus", "Altro", "その他", "더 보기", "Meer", "Mai multe", "Viac", "Več", "Diğer", "Інші", "更多"],
    "Info": ["Informació", "Información", "Informations", "Informazioni", "情報", "정보", "Informatie", "Informații", "Informácie", "Informacije", "Bilgi", "Інформація", "信息"],
    "Start": ["Inicia", "Iniciar", "Démarrer", "Avvia", "開始", "시작", "Starten", "Pornește", "Spustiť", "Začni", "Başlat", "Почати", "开始"],
    "Change": ["Canvia", "Cambiar", "Modifier", "Cambia", "変更", "변경", "Wijzigen", "Schimbă", "Zmeniť", "Spremeni", "Değiştir", "Змінити", "更改"],
    "Erase": ["Esborra", "Borrar", "Effacer", "Cancella", "消去", "지우기", "Wissen", "Șterge", "Vymazať", "Izbriši", "Sil", "Стерти", "擦除"],
    "Write": ["Escriu", "Escribir", "Écrire", "Scrivi", "書き込み", "쓰기", "Schrijven", "Scrie", "Zapísať", "Zapiši", "Yaz", "Записати", "写入"],
    "Configure": ["Configura", "Configurar", "Configurer", "Configura", "設定", "설정", "Configureren", "Configurează", "Nastaviť", "Nastavi", "Yapılandır", "Налаштувати", "配置"],
    "Details": ["Detalls", "Detalles", "Détails", "Dettagli", "詳細", "상세 정보", "Details", "Detalii", "Podrobnosti", "Podrobnosti", "Ayrıntılar", "Подробиці", "详情"],
    "Test camera": ["Càmera de prova", "Cámara de prueba", "Caméra de test", "Telecamera di prova", "テストカメラ", "테스트 카메라", "Testcamera", "Cameră de test", "Testovacia kamera", "Testna kamera", "Test kamerası", "Тестова камера", "测试摄像头"],
    "IP camera": ["Càmera IP", "Cámara IP", "Caméra IP", "Telecamera IP", "IP カメラ", "IP 카메라", "IP-camera", "Cameră IP", "IP kamera", "IP kamera", "IP kamera", "IP-камера", "IP 摄像头"],
    "Integrated camera": ["Càmera integrada", "Cámara integrada", "Caméra intégrée", "Telecamera integrata", "内蔵カメラ", "내장 카메라", "Geïntegreerde camera", "Cameră integrată", "Integrovaná kamera", "Vgrajena kamera", "Entegre kamera", "Вбудована камера", "内置摄像头"],
    "External camera": ["Càmera externa", "Cámara externa", "Caméra externe", "Telecamera esterna", "外部カメラ", "외부 카메라", "Externe camera", "Cameră externă", "Externá kamera", "Zunanja kamera", "Harici kamera", "Зовнішня камера", "外置摄像头"],
    "File source": ["Fitxer d'origen", "Archivo de origen", "Fichier source", "File sorgente", "ファイルソース", "파일 소스", "Bronbestand", "Fișier sursă", "Zdrojový súbor", "Izvorna datoteka", "Kaynak dosya", "Файл-джерело", "文件源"],
    "Open Source FPV for Everyone": ["FPV de codi obert per a tothom", "FPV de código abierto para todos", "FPV open source pour tous", "FPV open source per tutti", "すべての人にオープンソースの FPV を", "모두를 위한 오픈 소스 FPV", "Open source FPV voor iedereen", "FPV cu sursă deschisă pentru toți", "FPV s otvoreným zdrojovým kódom pre každého", "Odprtokodni FPV za vsakogar", "Herkes için açık kaynaklı FPV", "FPV з відкритим кодом для всіх", "面向所有人的开源 FPV"],
    "Support the continued development of OpenHD.": ["Doneu suport al desenvolupament continuat d'OpenHD.", "Apoya el desarrollo continuo de OpenHD.", "Soutenez le développement continu d'OpenHD.", "Sostieni lo sviluppo continuo di OpenHD.", "OpenHD の継続的な開発を支援します。", "OpenHD의 지속적인 개발을 지원하세요.", "Steun de verdere ontwikkeling van OpenHD.", "Susține dezvoltarea continuă a OpenHD.", "Podporte ďalší vývoj OpenHD.", "Podprite nadaljnji razvoj OpenHD.", "OpenHD'nin geliştirilmesine destek olun.", "Підтримайте подальший розвиток OpenHD.", "支持 OpenHD 的持续开发。"],
    "Sign in to securely coordinate your aircraft, links, and missions.": ["Inicieu la sessió per coordinar de manera segura les aeronaus, els enllaços i les missions.", "Inicia sesión para coordinar de forma segura tus aeronaves, enlaces y misiones.", "Connectez-vous pour coordonner en toute sécurité vos aéronefs, liaisons et missions.", "Accedi per coordinare in sicurezza i tuoi velivoli, collegamenti e missioni.", "ログインして、機体、通信リンク、ミッションを安全に管理します。", "로그인하여 기체, 통신 링크 및 임무를 안전하게 관리하세요.", "Meld u aan om uw vliegtuigen, verbindingen en missies veilig te coördineren.", "Autentifică-te pentru a coordona în siguranță aeronavele, legăturile și misiunile.", "Prihláste sa a bezpečne spravujte svoje lietadlá, spojenia a misie.", "Prijavite se za varno usklajevanje letal, povezav in misij.", "Hava araçlarınızı, bağlantılarınızı ve görevlerinizi güvenle yönetmek için oturum açın.", "Увійдіть, щоб безпечно керувати літальними апаратами, зв'язками та місіями.", "登录以安全管理您的飞行器、通信链路和任务。"],
    "Downloading update": ["S'està baixant l'actualització", "Descargando actualización", "Téléchargement de la mise à jour", "Download dell'aggiornamento", "更新をダウンロード中", "업데이트 다운로드 중", "Update wordt gedownload", "Se descarcă actualizarea", "Sťahovanie aktualizácie", "Prenašanje posodobitve", "Güncelleme indiriliyor", "Завантаження оновлення", "正在下载更新"],
    "Uploading update": ["S'està carregant l'actualització", "Subiendo actualización", "Transfert de la mise à jour", "Caricamento dell'aggiornamento", "更新をアップロード中", "업데이트 업로드 중", "Update wordt geüpload", "Se încarcă actualizarea", "Nahrávanie aktualizácie", "Nalaganje posodobitve", "Güncelleme yükleniyor", "Передавання оновлення", "正在上传更新"],
    "Updating device": ["S'està actualitzant el dispositiu", "Actualizando dispositivo", "Mise à jour du périphérique", "Aggiornamento del dispositivo", "デバイス更新中", "장치 업데이트 중", "Apparaat wordt bijgewerkt", "Se actualizează dispozitivul", "Aktualizácia zariadenia", "Posodabljanje naprave", "Cihaz güncelleniyor", "Оновлення пристрою", "正在更新设备"],
    "All existing data on <b>%1</b> will be permanently erased.<br><br>Write <b>%2</b> to this device?": [
        "Totes les dades de <b>%1</b> s'esborraran permanentment.<br><br>Voleu escriure <b>%2</b> en aquest dispositiu?",
        "Todos los datos de <b>%1</b> se borrarán permanentemente.<br><br>¿Escribir <b>%2</b> en este dispositivo?",
        "Toutes les données de <b>%1</b> seront définitivement effacées.<br><br>Écrire <b>%2</b> sur ce périphérique ?",
        "Tutti i dati su <b>%1</b> verranno cancellati definitivamente.<br><br>Scrivere <b>%2</b> su questo dispositivo?",
        "<b>%1</b> のすべてのデータが完全に消去されます。<br><br>このデバイスに <b>%2</b> を書き込みますか？",
        "<b>%1</b>의 모든 데이터가 영구적으로 삭제됩니다.<br><br>이 장치에 <b>%2</b>을(를) 쓰시겠습니까?",
        "Alle gegevens op <b>%1</b> worden permanent gewist.<br><br><b>%2</b> naar dit apparaat schrijven?",
        "Toate datele de pe <b>%1</b> vor fi șterse definitiv.<br><br>Scrieți <b>%2</b> pe acest dispozitiv?",
        "Všetky údaje na <b>%1</b> budú natrvalo vymazané.<br><br>Zapísať <b>%2</b> na toto zariadenie?",
        "Vsi podatki na <b>%1</b> bodo trajno izbrisani.<br><br>Zapišem <b>%2</b> na to napravo?",
        "<b>%1</b> üzerindeki tüm veriler kalıcı olarak silinecek.<br><br><b>%2</b> bu cihaza yazılsın mı?",
        "Усі дані на <b>%1</b> буде остаточно стерто.<br><br>Записати <b>%2</b> на цей пристрій?",
        "<b>%1</b> 上的所有数据将被永久擦除。<br><br>是否将 <b>%2</b> 写入此设备？",
    ],
}
LABEL_ALIASES = {"SIGN OUT": "Sign out", "Choose an image": "Choose image", "Write an image": "Write image", "Clear Selection": "Clear", "Destination device": "Target device", "DONATE": "Donate", "CLOSE": "Close", "WRITE": "Write", "CONFIGURE": "Configure", "OPERATOR": "Operator"}
OVERRIDES = {"tr": {
    "Connect the OpenHD X21 by USB in MaskROM or Loader mode, then select it below.": "OpenHD X21'i USB üzerinden MaskROM veya Loader modunda bağlayın, ardından aşağıdan seçin.",
}}
PROTECTED = re.compile(
    r"%\d+|%n|[<>–—·→←]|https?://\S+|\*\.[a-z]+|\(\*\)|"
    r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]+\.(?:txt|json|conf|zip|exe|ohdcert|img)(?![A-Za-z0-9_])|"
    r"\b(?:OpenHD ImageWriter|Raspberry Pi Imager|QOpenHD\.conf|settings\.json|firmware\.zip|OpenHD|QOpenHD|FleetControl|"
    r"GitHub(?: Actions)?|Cloudsmith|Raspberry Pi|Rockchip|Radxa|Luckfox|Orqa|"
    r"MaskROM|Loader|rpiboot|udisks2|sfdisk|mkfs\.fat|EDID|HDMI|FAT32|FAT|TLS|USB|"
    r"SBC|FPV|CAM[01]|X2[01]|HTTP|IP|MB/s|Mbit/s|GB|MB|KB|TB|Hz)\b"
)
TAGS = re.compile(r"(<[^>]+>)")
UNCHANGED = {"B", "KB", "MB", "GB", "TB", "Raspberry Pi", "Radxa", "Luckfox", "x86 / PC", "FleetControl", "QOpenHD.conf", "QOpenHD.conf (*.conf)", "SBC", "DEV", "GITHUB", "Rockchip %1 (%2:%3)", "OpenHD ImageWriter v%1"}


def download_model(lang, index, directory):
    target = directory / lang
    if list(target.glob("*/model/model.bin")):
        return
    item = next(x for x in reversed(index) if x["from_code"] == "en" and x["to_code"] == lang)
    archive = directory / (lang + ".argosmodel")
    if not archive.exists():
        response = requests.get(item["links"][0], timeout=120)
        response.raise_for_status()
        archive.write_bytes(response.content)
    target.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            resolved = (target / member.filename).resolve()
            if not resolved.is_relative_to(target.resolve()):
                raise ValueError("Unsafe model package path")
        package.extractall(target)
    print(f"Model ready: {lang}", flush=True)


class LocalTranslator:
    def __init__(self, directory):
        package = next(directory.glob("*/model/model.bin")).parent.parent
        self.sp = sentencepiece.SentencePieceProcessor(model_file=str(package / "sentencepiece.model"))
        self.model = ctranslate2.Translator(str(package / "model"), device="cpu", compute_type="int8", intra_threads=4)
        self.cache = {}

    def plain(self, source):
        if not source.strip():
            return source
        if source in self.cache:
            return self.cache[source]
        result = self.model.translate_batch([self.sp.encode(source.strip(), out_type=str)], beam_size=4, max_decoding_length=512, no_repeat_ngram_size=3)[0]
        text = self.sp.decode(result.hypotheses[0]).replace("\u2581", " ").strip()
        text = source[:len(source) - len(source.lstrip())] + text + source[len(source.rstrip()):]
        self.cache[source] = text
        return text

    def text(self, source):
        pieces = TAGS.split(source)
        output = []
        for piece in pieces:
            if TAGS.fullmatch(piece) or not piece.strip():
                output.append(piece)
                continue
            direct = self.plain(piece)
            direct = re.sub(r"%\s+(\d+)", r"%\1", direct)
            if Counter(PROTECTED.findall(piece)) == Counter(PROTECTED.findall(direct)):
                output.append(direct)
                continue
            tokens = []
            def protect(match):
                tokens.append(match.group())
                return str(98765000 + len(tokens))
            masked = PROTECTED.sub(protect, piece)
            translated = self.plain(masked)
            for number, token in enumerate(tokens, 1):
                marker = str(98765000 + number)
                if translated.count(marker) != 1:
                    # Translate text fragments separately if the model drops or
                    # changes a protected token. Never alter format arguments.
                    chunks = re.split("(" + PROTECTED.pattern + ")", piece)
                    translated = "".join(chunk if PROTECTED.fullmatch(chunk) else self.plain(chunk) for chunk in chunks if chunk)
                    break
                translated = translated.replace(marker, token)
            output.append(translated)
        return "".join(output)


def validate(source, target):
    for pattern in [r"%\d+|%n", r"<[^>]+>", r"\*\.[a-z]+|\(\*\)", r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]+\.(?:txt|json|conf|zip|exe|ohdcert|img)(?![A-Za-z0-9_])"]:
        if sorted(re.findall(pattern, source)) != sorted(re.findall(pattern, target)):
            raise ValueError(f"Translation changed formatting: {source!r} -> {target!r}")
    if not target.strip() and source.strip():
        raise ValueError(f"Empty translation: {source!r}")
    if any(marker in target for marker in ["\u2047", "\u2581", "\ufffd"]):
        raise ValueError(f"Translation contains a tokenizer artifact: {source!r}")
    if len(target) > max(100, len(source) * 4) or re.search(r"\b(\w+)(?:\s+\1){3,}\b", target, re.IGNORECASE):
        raise ValueError(f"Translation is suspiciously long or repetitive: {source!r}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, required=True)
    parser.add_argument("--retranslate", action="store_true", help="Regenerate text outside the glossary")
    args = parser.parse_args()
    args.models.mkdir(parents=True, exist_ok=True)
    missing_models = [lang for lang in LANGUAGES if not list((args.models / lang).glob("*/model/model.bin"))]
    if missing_models:
        response = requests.get("https://raw.githubusercontent.com/argosopentech/argospm-index/main/index.json", timeout=30)
        response.raise_for_status()
        index = response.json()
        with ThreadPoolExecutor(max_workers=3) as pool:
            list(pool.map(lambda lang: download_model(lang, index, args.models), missing_models))
    root = Path(__file__).resolve().parents[1]
    for lang_index, lang in enumerate(LANGUAGES):
        path = root / f"src/i18n/rpi-imager_{lang}.ts"
        tree = ET.parse(path)
        translator = LocalTranslator(args.models / lang)
        changed = 0
        for message in tree.findall("context/message"):
            source = message.findtext("source")
            translation = message.find("translation")
            existing = (translation.text or "").replace("\u2581", " ")
            label = LABEL_ALIASES.get(source, source)
            status = re.fullmatch(r"(Downloading update|Uploading update)( \(%1%\))", source)
            if source in OVERRIDES.get(lang, {}):
                target = OVERRIDES[lang][source]
            elif source == "Update complete!":
                target = LABELS["Update complete"][lang_index] + "!"
            elif label in LABELS:
                target = LABELS[label][lang_index]
            elif status:
                target = LABELS[status.group(1)][lang_index] + status.group(2)
            elif lang in EXISTING_GLOSSARY.get(source, {}):
                target = EXISTING_GLOSSARY[source][lang]
            elif source in UNCHANGED:
                target = source
            elif args.retranslate or not existing or translation.get("type") == "unfinished" or existing == source:
                target = translator.text(source)
            else:
                target = existing
            try:
                validate(source, target)
            except ValueError:
                target = translator.text(source)
                validate(source, target)
            if target != (translation.text or "") or translation.get("type"):
                translation.text = target
                translation.attrib.pop("type", None)
                changed += 1
        if changed:
            ET.indent(tree, space="    ")
            path.write_text('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n' + ET.tostring(tree.getroot(), encoding="unicode") + '\n', encoding="utf-8")
        print(f"{lang}: updated {changed} translations", flush=True)


if __name__ == "__main__":
    main()
