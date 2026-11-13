--[[
    Bike Universe  |  Auto Drive + Anti-AFK  |  CHRISTMAS EDITION
    NostraTeam

    - 2 fixed teleport locations (Location 1 / Location 2 / Alternate)
    - Locations are fixed and their coordinates are not shown in the menu
    - Christmas theme: snow, lights, candy-cane bar, Santa hat
    - Frosted intro: NOSTRA TEAM -> key system + Discord -> menu
]]

---------------------------------------------------------------------
-- FIXED LOCATIONS
-- Coordinates are intentionally not displayed anywhere in the menu.
---------------------------------------------------------------------
local LOCATION_1_POSITION = Vector3.new(5344.32, 3.5, 493.93)
local LOCATION_1_YAW = -90
local LOCATION_2_POSITION = Vector3.new(391.8, 4.4, 387.1)
local LOCATION_2_YAW = -90

---------------------------------------------------------------------
-- KEY SYSTEM / DISCORD
---------------------------------------------------------------------
local SCRIPT_KEY = "ZERONVSBATUGEN23345"
local DISCORD_LINK = "https://discord.gg/s6HmYXrjX"

local SharedEnv = _G
pcall(function()
    if type(getgenv) == "function" then SharedEnv = getgenv() end
end)
pcall(function()
    if type(SharedEnv.__BikeUniverseCleanup) == "function" then
        SharedEnv.__BikeUniverseCleanup()
    end
end)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local Cfg = {
    AutoDrive = false,
    AutoTeleport = false,
    AntiAFK = false,
    Notifications = true,
    RespawnTeleport = false,
    AutoRejoin = false,
    AutoReseat = false,
    FpsBoost = false,
    Render3DOff = false,
    Snow = true,
    TeleMode = 3, -- 1 = Location 1 only, 2 = Location 2 only, 3 = alternate after falling off
    JumpInterval = 45,
    HoldTime = 0.5,
}

local FlagNames = {
    AutoRejoin = "Auto Rejoin",
    AutoReseat = "Auto Re-sit",
    FpsBoost = "FPS Boost",
    Render3DOff = "Save GPU mode",
    AutoDrive = "Auto Drive",
    AutoTeleport = "Auto Teleport",
    AntiAFK = "Anti-AFK",
    Notifications = "Notifications",
    RespawnTeleport = "Teleport on respawn",
    Snow = "Snowfall",
}

local ModeNames = { "Location 1", "Location 2", "Random" }

local Locs = {
    { pos = LOCATION_1_POSITION, yaw = LOCATION_1_YAW },
    { pos = LOCATION_2_POSITION, yaw = LOCATION_2_YAW },
}
local CurrentLoc = 1
local PendingRandomSwitch = false
local NextTeleportAttempt = 0

local Alive = true
local HasTeleported = false
local TeleportCount = 0
local JumpCount = 0
local Jumping = false
local JumpEnd = 0
local StartTime = os.clock()
local LastJump = os.clock()
local TopSpeed = 0
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = nil
pcall(function() CoreGui = game:GetService("CoreGui") end)
local Rejoining = false
local SavedSeat = nil
local SavedVehicleName = nil
local NextReseat = 0
local PendingReseat = false
local LastFullScan = -100
local ReseatFails = 0
local Lighting = game:GetService("Lighting")
local WeatherMode = "Default"
local WeatherCustomStatusLabel = nil
local WeatherBackup = nil
local WeatherAtmosphereBackup = nil
local WeatherCreatedAtmosphere = nil
local WeatherCustom = {
    Enabled = false,
    Time = 12,
    Brightness = 2.0,
    Fog = 0,
}
local BoostBackup = nil
local ToggleKey = Enum.KeyCode.K
local HideKey = Enum.KeyCode.RightShift
local SwapKey = Enum.KeyCode.L
local AntiAFKKey = Enum.KeyCode.Space
local Listening = nil
local Connections = {}
local Minimized = false
local SnowLayer = nil
local IntroDone = false
local IntroGui = nil
local IntroBlur = nil
local IntroSnowConn = nil

-- drive state
local Humanoid = nil
local LastSeat = nil
local UnseatedSince = nil
local CurrentVehicleModel = nil
local CurrentVehicleName = "No vehicle detected"
local VehicleChangeCount = 0
local KeyHeld = false
local NextKeyRefresh = 0
local LastEngineError = 0

local function track(conn)
    table.insert(Connections, conn)
    return conn
end

---------------------------------------------------------------------
-- Theme  (Christmas)
---------------------------------------------------------------------
local C = {
    bg = Color3.fromRGB(9, 15, 16),
    side = Color3.fromRGB(12, 21, 20),
    card = Color3.fromRGB(19, 31, 29),
    cardHi = Color3.fromRGB(29, 46, 41),
    line = Color3.fromRGB(54, 78, 67),
    text = Color3.fromRGB(247, 248, 244),
    dim = Color3.fromRGB(166, 184, 173),
    accent = Color3.fromRGB(207, 49, 63),
    good = Color3.fromRGB(91, 201, 133),
    warn = Color3.fromRGB(235, 190, 91),
    bad = Color3.fromRGB(225, 82, 88),
    off = Color3.fromRGB(47, 66, 58),
}
local GOLD = Color3.fromRGB(245, 205, 120)
local PINE = Color3.fromRGB(27, 91, 65)
local WHITE = Color3.new(1, 1, 1)

---------------------------------------------------------------------
-- Languages
---------------------------------------------------------------------
local Languages = {
    { "en", "English" },
    { "tr", "Türkçe" },
    { "es", "Español" },
    { "de", "Deutsch" },
    { "fr", "Français" },
}
local Lang = "en"
local Strings = { tr = {}, es = {}, de = {}, fr = {} }
local LangCols = { tr = 2, es = 3, de = 4, fr = 5 }

-- { English, Türkçe, Español, Deutsch, Français }
local Rows = {
    -- tabs
    { "Main", "Ana Sayfa", "Principal", "Start", "Accueil" },
    { "Settings", "Ayarlar", "Ajustes", "Einstellungen", "Paramètres" },
    { "Log", "Kayıt", "Registro", "Protokoll", "Journal" },
    { "Info", "Bilgi", "Info", "Info", "Infos" },
    { "Weather", "Hava", "Clima", "Wetter", "Météo" },
    { "Vehicle detection", "Araç algılama", "Detección de vehículo", "Fahrzeugerkennung", "Détection du véhicule" },
    { "Detected vehicle", "Algılanan araç", "Vehículo detectado", "Erkanntes Fahrzeug", "Véhicule détecté" },
    { "Vehicle changes", "Araç değişimleri", "Cambios de vehículo", "Fahrzeugwechsel", "Changements de véhicule" },
    { "Not seated", "Araçta değil", "No estás sentado", "Nicht sitzend", "Pas installé" },
    { "No vehicle detected", "Araç algılanmadı", "No se detectó ningún vehículo", "Kein Fahrzeug erkannt", "Aucun véhicule détecté" },
    { "Vehicle changed: %s", "Araç değişti: %s", "Vehículo cambiado: %s", "Fahrzeug gewechselt: %s", "Véhicule changé : %s" },
    { "Ready after dismount", "Araçtan inince hazır", "Listo al bajar", "Nach dem Absteigen bereit", "Prêt après être descendu" },
    { "Protected while riding", "Sürüş sırasında koruma aktif", "Protección activa al conducir", "Schutz während der Fahrt aktiv", "Protection active en conduite" },
    { "CUSTOMIZE WEATHER", "HAVAYI ÖZELLEŞTİR", "PERSONALIZAR CLIMA", "WETTER ANPASSEN", "PERSONNALISER LA MÉTÉO" },
    { "Time of day", "Günün saati", "Hora del día", "Tageszeit", "Heure de la journée" },
    { "Set your local sky time", "Kendi ekranındaki saati ayarla", "Ajusta la hora local", "Stelle deine lokale Uhrzeit ein", "Réglez votre heure locale" },
    { "Brightness", "Parlaklık", "Brillo", "Helligkeit", "Luminosité" },
    { "Adjust local brightness", "Kendi ekranındaki parlaklığı ayarla", "Ajusta el brillo local", "Stelle die lokale Helligkeit ein", "Réglez la luminosité locale" },
    { "Fog intensity", "Sis yoğunluğu", "Intensidad de niebla", "Nebelintensität", "Intensité du brouillard" },
    { "Adjust local fog visibility", "Kendi ekranındaki sis yoğunluğunu ayarla", "Ajusta la niebla local", "Stelle den lokalen Nebel ein", "Réglez le brouillard local" },
    { "Custom weather active", "Özel hava görünümü açık", "Clima personalizado activo", "Benutzerdefiniertes Wetter aktiv", "Météo personnalisée active" },
    { "Adjust the sliders to build your own look", "Kendi görünümünü oluşturmak için kaydırıcıları ayarla", "Ajusta los controles para crear tu aspecto", "Passe die Regler für deinen eigenen Look an", "Ajustez les curseurs pour créer votre style" },
    -- status
    { "Waiting", "Bekleniyor", "Esperando", "Warten", "En attente" },
    { "Driving", "Sürüyor", "Conduciendo", "Fährt", "Conduite" },
    { "Paused", "Duraklatıldı", "En pausa", "Pausiert", "En pause" },
    { "Rejoining", "Yeniden bağlanıyor", "Reconectando", "Verbinde neu", "Reconnexion" },
    { "Sit on a vehicle to begin", "Başlamak için bir araca bin", "Siéntate en un vehículo para empezar", "Setz dich zum Start auf ein Fahrzeug", "Montez sur un véhicule pour commencer" },
    { "Auto Drive is turned off", "Otomatik sürüş kapalı", "La conducción automática está desactivada", "Auto-Fahren ist ausgeschaltet", "La conduite auto est désactivée" },
    { "Connection lost - joining a new server", "Bağlantı koptu - yeni sunucuya giriliyor", "Conexión perdida - entrando a un servidor nuevo", "Verbindung verloren - neuer Server wird betreten", "Connexion perdue - rejoint un nouveau serveur" },
    { "Vehicle: ", "Araç: ", "Vehículo: ", "Fahrzeug: ", "Véhicule : " },
    { "SPEED", "HIZ", "VELOCIDAD", "TEMPO", "VITESSE" },
    { "studs / sec", "stud / sn", "studs / s", "Studs / s", "studs / s" },
    { "RUNTIME", "SÜRE", "TIEMPO", "LAUFZEIT", "DURÉE" },
    { "TELEPORTS", "IŞINLANMA", "TELEPORTES", "TELEPORTS", "TÉLÉPORTS" },
    { "JUMPS", "ZIPLAMA", "SALTOS", "SPRÜNGE", "SAUTS" },
    { "TO TARGET", "HEDEFE", "AL OBJETIVO", "ZUM ZIEL", "VERS LA CIBLE" },
    { "Next anti-AFK jump", "Sonraki anti-AFK basışı", "Próxima pulsación anti-AFK", "Nächster Anti-AFK-Tastendruck", "Prochain appui anti-AFK" },
    { "Next location switch", "Sonraki konum değişimi", "Próximo cambio de ubicación", "Nächster Ortswechsel", "Prochain changement de lieu" },
    { "Off", "Kapalı", "Apagado", "Aus", "Désactivé" },
    { "Pressing...", "Basılıyor...", "Pulsando...", "Drücke...", "Appui..." },
    -- sections
    { "AUTOMATION", "OTOMASYON", "AUTOMATIZACIÓN", "AUTOMATISIERUNG", "AUTOMATISATION" },
    { "LOCATIONS", "KONUMLAR", "UBICACIONES", "ORTE", "LIEUX" },
    { "KEYBINDS", "TUŞ ATAMALARI", "ATAJOS", "TASTENBELEGUNG", "RACCOURCIS" },
    { "ANTI-AFK TIMING", "ANTI-AFK ZAMANLAMASI", "TIEMPOS ANTI-AFK", "ANTI-AFK-ZEITEN", "DÉLAIS ANTI-AFK" },
    { "BEHAVIOR", "DAVRANIŞ", "COMPORTAMIENTO", "VERHALTEN", "COMPORTEMENT" },
    { "PERFORMANCE", "PERFORMANS", "RENDIMIENTO", "LEISTUNG", "PERFORMANCES" },
    { "APPEARANCE", "GÖRÜNÜM", "APARIENCIA", "DESIGN", "APPARENCE" },
    { "LANGUAGE", "DİL", "IDIOMA", "SPRACHE", "LANGUE" },
    { "SCRIPT", "SCRİPT", "SCRIPT", "SKRIPT", "SCRIPT" },
    { "ABOUT", "HAKKINDA", "ACERCA DE", "ÜBER", "À PROPOS" },
    { "HOW IT WORKS", "NASIL ÇALIŞIR", "CÓMO FUNCIONA", "SO FUNKTIONIERT'S", "FONCTIONNEMENT" },
    { "SESSION", "OTURUM", "SESIÓN", "SITZUNG", "SESSION" },
    { "HOTKEYS", "KISAYOLLAR", "TECLAS RÁPIDAS", "TASTENKÜRZEL", "RACCOURCIS CLAVIER" },
    { "ACTIVITY", "ETKİNLİK", "ACTIVIDAD", "AKTIVITÄT", "ACTIVITÉ" },
    -- locations
    { "Location 1", "Konum 1", "Ubicación 1", "Ort 1", "Lieu 1" },
    { "Location 2", "Konum 2", "Ubicación 2", "Ort 2", "Lieu 2" },
    { "Alternate", "Dönüşümlü", "Alternar", "Abwechselnd", "Alterner" },
    { "Random", "Rastgele", "Aleatorio", "Zufällig", "Aléatoire" },
    { "Go", "Git", "Ir", "Los", "Aller" },
    { "Teleport Mode", "Işınlanma Modu", "Modo de teletransporte", "Teleport-Modus", "Mode de téléportation" },
    { "Use one spot, or switch between both", "Tek nokta kullan veya ikisi arasında geç", "Usa un punto o alterna entre ambos", "Einen Ort nutzen oder abwechseln", "Un seul lieu ou alterner entre les deux" },
    { "Switch Interval", "Geçiş Aralığı", "Intervalo de cambio", "Wechselintervall", "Intervalle de changement" },
    { "Seconds before switching location", "Konum değiştirmeden önceki saniye", "Segundos antes de cambiar", "Sekunden bis zum Ortswechsel", "Secondes avant de changer de lieu" },
    { "Swap Location", "Konumu Değiştir", "Cambiar ubicación", "Ort wechseln", "Changer de lieu" },
    { "Teleport to the other location", "Diğer konuma ışınlan", "Teletransporta a la otra ubicación", "Zum anderen Ort teleportieren", "Se téléporte vers l'autre lieu" },
    -- toggles
    { "Auto Drive", "Otomatik Sürüş", "Conducción automática", "Auto-Fahren", "Conduite auto" },
    { "Holds W continuously while enabled", "Açıkken W tuşunu sürekli basılı tutar", "Mantiene W pulsada mientras esté activo", "Hält W gedrückt, solange aktiv", "Maintient W enfoncée tant que c'est activé" },
    { "Auto Teleport", "Otomatik Işınlanma", "Teletransporte automático", "Auto-Teleport", "Téléportation auto" },
    { "Moves your vehicle to the target point", "Aracını hedef noktaya taşır", "Mueve tu vehículo al punto objetivo", "Bringt dein Fahrzeug zum Zielpunkt", "Déplace votre véhicule vers le point cible" },
    { "Anti-AFK", "Anti-AFK", "Anti-AFK", "Anti-AFK", "Anti-AFK" },
    { "One short key press every interval", "Her aralıkta seçilen tuşa kısa basış", "Una pulsación breve de la tecla elegida en cada intervalo", "Ein kurzer Druck auf die gewählte Taste pro Intervall", "Une brève pression sur la touche choisie à chaque intervalle" },
    { "Auto Re-sit", "Otomatik Tekrar Oturma", "Volver a sentarse automático", "Auto-Wiederhinsetzen", "Reprise de place auto" },
    { "Sits back on your vehicle if you fall off", "Düşersen aracına tekrar oturur", "Te vuelve a sentar en el vehículo si te caes", "Setzt dich zurück aufs Fahrzeug, wenn du fällst", "Vous remet sur le véhicule si vous tombez" },
    { "Auto Rejoin", "Otomatik Yeniden Giriş", "Reentrada automática", "Auto-Wiederbeitritt", "Reconnexion auto" },
    { "Rejoins if disconnected (public servers only)", "Bağlantı koparsa yeniden girer (sadece herkese açık sunucular)", "Reentra si te desconectas (solo servidores públicos)", "Tritt bei Trennung neu bei (nur öffentliche Server)", "Se reconnecte en cas de déconnexion (serveurs publics uniquement)" },
    -- buttons
    { "Teleport Now", "Şimdi Işınla", "Teletransportar ya", "Jetzt teleportieren", "Se téléporter" },
    { "Reset Stats", "İstatistikleri Sıfırla", "Restablecer estadísticas", "Statistik zurücksetzen", "Réinitialiser les stats" },
    { "Clear Log", "Kaydı Temizle", "Borrar registro", "Protokoll leeren", "Effacer le journal" },
    { "Unload Script", "Scripti Kapat", "Descargar script", "Skript beenden", "Décharger le script" },
    -- settings
    { "Toggle Auto Drive", "Otomatik Sürüşü Aç/Kapat", "Alternar conducción automática", "Auto-Fahren umschalten", "Basculer la conduite auto" },
    { "Quickly start or stop driving", "Sürüşü hızlıca başlat veya durdur", "Inicia o detén la conducción rápidamente", "Fahren schnell starten oder stoppen", "Démarrer ou arrêter la conduite rapidement" },
    { "Show / Hide Menu", "Menüyü Göster / Gizle", "Mostrar / ocultar menú", "Menü ein-/ausblenden", "Afficher / masquer le menu" },
    { "Hide the window out of the way", "Pencereyi yoldan çekmek için gizle", "Oculta la ventana para despejar la vista", "Blendet das Fenster aus", "Masque la fenêtre pour dégager la vue" },
    { "Press a key...", "Bir tuşa bas...", "Pulsa una tecla...", "Taste drücken...", "Appuyez sur une touche..." },
    { "Jump Interval", "Basış Aralığı", "Intervalo de pulsación", "Tastenintervall", "Intervalle d'appui" },
    { "Key Interval", "Tuş Aralığı", "Intervalo de tecla", "Tastenintervall", "Intervalle de touche" },
    { "Next anti-AFK key press", "Sonraki anti-AFK tuş basışı", "Próxima pulsación anti-AFK", "Nächster Anti-AFK-Tastendruck", "Prochaine pression de touche anti-AFK" },
    { "PRESSES", "BASIŞ", "PULSACIONES", "TASTENDRÜCKE", "PRESSIONS" },
    { "Random", "Rastgele", "Aleatorio", "Zufällig", "Aléatoire" },
    { "Seconds between key presses", "Tuş basışları arası saniye", "Segundos entre pulsaciones", "Sekunden zwischen Tastendrücken", "Secondes entre les pressions" },
    { "Press Length", "Basış Süresi", "Duración de pulsación", "Tastendauer", "Durée d'appui" },
    { "How long the selected key is held (seconds)", "Seçilen tuşun basılı kalma süresi (saniye)", "Cuánto se mantiene la tecla elegida (segundos)", "Wie lange die gewählte Taste gehalten wird (Sekunden)", "Durée de maintien de la touche choisie (secondes)" },
    { "Teleport on respawn", "Doğunca ışınlan", "Teletransportar al reaparecer", "Beim Respawn teleportieren", "Téléportation à la réapparition" },
    { "Teleport again after your character respawns", "Karakterin yeniden doğduktan sonra tekrar ışınlar", "Teletransporta de nuevo tras reaparecer", "Teleportiert erneut nach dem Respawn", "Se téléporte à nouveau après la réapparition" },
    { "Notifications", "Bildirimler", "Notificaciones", "Benachrichtigungen", "Notifications" },
    { "Show pop-up messages in the corner", "Köşede açılır mesajları göster", "Muestra mensajes emergentes en la esquina", "Zeigt Pop-up-Meldungen in der Ecke", "Affiche des messages contextuels dans le coin" },
    { "FPS Boost", "FPS Artırıcı", "Mejora de FPS", "FPS-Boost", "Boost FPS" },
    { "Lowest graphics quality and no shadows", "En düşük grafik kalitesi ve gölgesiz", "Calidad gráfica mínima y sin sombras", "Niedrigste Grafikqualität und keine Schatten", "Qualité graphique minimale et sans ombres" },
    { "Save GPU mode", "GPU Tasarruf Modu", "Modo ahorro de GPU", "GPU-Sparmodus", "Mode économie GPU" },
    { "Turns off 3D rendering while AFK (screen goes blank)", "AFK iken 3D çizimi kapatır (ekran boşalır)", "Desactiva el renderizado 3D en AFK (la pantalla queda en blanco)", "Schaltet 3D-Darstellung im AFK aus (Bildschirm wird leer)", "Désactive le rendu 3D en AFK (l'écran devient vide)" },
    { "Snowfall", "Kar Yağışı", "Nevada", "Schneefall", "Chutes de neige" },
    { "PERSONAL WEATHER", "KİŞİSEL HAVA", "CLIMA PERSONAL", "PERSÖNLICHES WETTER", "MÉTÉO PERSONNELLE" },
    { "Only changes the lighting on your screen", "Yalnızca kendi ekranındaki ışığı ve sisi değiştirir", "Solo cambia la iluminación de tu pantalla", "Ändert nur Licht und Nebel auf deinem Bildschirm", "Ne change que la lumière sur votre écran" },
    { "Default", "Varsayılan", "Predeterminado", "Standard", "Par défaut" },
    { "Day", "Gündüz", "Día", "Tag", "Jour" },
    { "Sunset", "Gün Batımı", "Atardecer", "Sonnenuntergang", "Coucher de soleil" },
    { "Night", "Gece", "Noche", "Nacht", "Nuit" },
    { "Fog", "Sis", "Niebla", "Nebel", "Brouillard" },
    { "Winter", "Kış", "Invierno", "Winter", "Hiver" },
    { "Weather applied", "Hava görünümü uygulandı", "Clima aplicado", "Wetter angewendet", "Météo appliquée" },
    { "Choose a look just for yourself", "Yalnızca kendin için bir görünüm seç", "Elige un aspecto solo para ti", "Wähle eine Ansicht nur für dich", "Choisissez un style uniquement pour vous" },
    { "Random mode", "Rastgele mod", "Modo aleatorio", "Zufallsmodus", "Mode aléatoire" },
    { "After falling off the vehicle", "Araçtan düştükten sonra", "Después de caer del vehículo", "Nach dem Sturz vom Fahrzeug", "Après être tombé du véhicule" },
    { "Falling snow inside the menu", "Menüde yağan kar", "Nieve cayendo en el menú", "Fallender Schnee im Menü", "Neige qui tombe dans le menu" },
    { "Accent Color", "Vurgu Rengi", "Color de acento", "Akzentfarbe", "Couleur d'accent" },
    { "Changes highlights across the menu", "Menüdeki vurguları değiştirir", "Cambia los resaltados del menú", "Ändert die Hervorhebungen im Menü", "Change les accents du menu" },
    { "Language", "Dil", "Idioma", "Sprache", "Langue" },
    { "Choose the menu language", "Menü dilini seç", "Elige el idioma del menú", "Menüsprache wählen", "Choisissez la langue du menu" },
    -- info
    { "Script", "Script", "Script", "Skript", "Script" },
    { "Developer", "Geliştirici", "Desarrollador", "Entwickler", "Développeur" },
    { "Dual Teleport", "Çift Işınlanma", "Doble teletransporte", "Doppel-Teleport", "Double téléportation" },
    { "Switches between 2 spots", "2 nokta arasında geçiş yapar", "Alterna entre 2 puntos", "Wechselt zwischen 2 Punkten", "Alterne entre 2 points" },
    { "Holds W non-stop", "W'yi kesintisiz basılı tutar", "Mantiene W sin parar", "Hält W dauerhaft gedrückt", "Maintient W sans arrêt" },
    { "Sits back on vehicle", "Araca tekrar oturur", "Vuelve a sentarse en el vehículo", "Setzt sich zurück aufs Fahrzeug", "Se remet sur le véhicule" },
    { "Reconnects if kicked", "Atılırsan yeniden bağlanır", "Se reconecta si te expulsan", "Verbindet neu bei Kick", "Se reconnecte en cas d'expulsion" },
    { "Top speed", "En yüksek hız", "Velocidad máxima", "Höchstgeschwindigkeit", "Vitesse max" },
    { "Show / Hide", "Göster / Gizle", "Mostrar / ocultar", "Ein-/Ausblenden", "Afficher / masquer" },
    -- messages
    { "%s enabled", "%s açıldı", "%s activado", "%s aktiviert", "%s activé" },
    { "%s disabled", "%s kapatıldı", "%s desactivado", "%s deaktiviert", "%s désactivé" },
    { "Respawned - resyncing", "Yeniden doğdun - senkronize ediliyor", "Reapareciste - resincronizando", "Respawn - synchronisiere neu", "Réapparition - resynchronisation" },
    { "Disconnected - rejoining", "Bağlantı koptu - yeniden giriliyor", "Desconectado - reentrando", "Getrennt - Wiederbeitritt", "Déconnecté - reconnexion" },
    { "No vehicle found - sit on one first", "Araç bulunamadı - önce bir araca bin", "No se encontró vehículo - siéntate en uno primero", "Kein Fahrzeug gefunden - setz dich zuerst auf eins", "Aucun véhicule - montez d'abord sur un" },
    { "Session stats reset", "Oturum istatistikleri sıfırlandı", "Estadísticas de sesión restablecidas", "Sitzungsstatistik zurückgesetzt", "Stats de session réinitialisées" },
    { "Key set to %s", "Tuş %s olarak ayarlandı", "Tecla establecida en %s", "Taste auf %s gesetzt", "Touche définie sur %s" },
    { "Bike Universe loaded", "Bike Universe yüklendi", "Bike Universe cargado", "Bike Universe geladen", "Bike Universe chargé" },
    { "Teleported to Location %d", "Konum %d'e ışınlandı", "Teletransportado a la ubicación %d", "Zu Ort %d teleportiert", "Téléporté au lieu %d" },
    { "Location %d is unavailable", "Konum %d kullanılamıyor", "La ubicación %d no está disponible", "Ort %d ist nicht verfügbar", "L'emplacement %d est indisponible" },
    { "Mode: %s", "Mod: %s", "Modo: %s", "Modus: %s", "Mode : %s" },
    { "Anti-AFK: key pressed", "Anti-AFK: tuşa basıldı", "Anti-AFK: tecla pulsada", "Anti-AFK: Taste gedrückt", "Anti-AFK : touche appuyée" },
    { "Re-sitting on vehicle", "Araca tekrar oturuluyor", "Volviendo a sentarse en el vehículo", "Setze mich zurück aufs Fahrzeug", "Remise sur le véhicule" },
    { "Private server - Auto Rejoin is off", "Özel sunucu - Otomatik Yeniden Giriş kapalı", "Servidor privado - reentrada automática desactivada", "Privater Server - Auto-Wiederbeitritt aus", "Serveur privé - reconnexion auto désactivée" },
    { "%s every %ds (%.1fs)", "%s tuşu, %d sn'de bir (%.1f sn)", "%s cada %ds (%.1fs)", "%s alle %ds (%.1fs)", "%s toutes les %ds (%.1fs)" },
    { "%d studs/s", "%d stud/sn", "%d studs/s", "%d Studs/s", "%d studs/s" },
    -- christmas
    { "Merry Christmas", "Mutlu Noeller", "Feliz Navidad", "Frohe Weihnachten", "Joyeux Noël" },
    { "NostraTeam · Christmas Edition", "NostraTeam · Yılbaşı Sürümü", "NostraTeam · Edición Navideña", "NostraTeam · Weihnachtsedition", "NostraTeam · Édition de Noël" },
    -- key system / discord
    { "Key System", "Anahtar Sistemi", "Sistema de clave", "Schlüsselsystem", "Système de clé" },
    { "WINTER ACCESS", "KIŞ ERİŞİMİ", "ACCESO DE INVIERNO", "WINTERZUGANG", "ACCÈS HIVERNAL" },
    { "Welcome to Bike Universe", "Bike Universe'e hoş geldin", "Bienvenido a Bike Universe", "Willkommen bei Bike Universe", "Bienvenue sur Bike Universe" },
    { "Enter your access key to continue", "Devam etmek için erişim anahtarını gir", "Introduce tu clave de acceso para continuar", "Gib deinen Zugangsschlüssel ein", "Saisissez votre clé d'accès pour continuer" },
    { "ACCESS KEY", "ERİŞİM ANAHTARI", "CLAVE DE ACCESO", "ZUGANGSSCHLÜSSEL", "CLÉ D'ACCÈS" },
    { "Paste or type your key", "Keyini yapıştır veya yaz", "Pega o escribe tu clave", "Füge deinen Schlüssel ein oder tippe ihn", "Collez ou saisissez votre clé" },
    { "VERIFY & CONTINUE", "DOĞRULA VE DEVAM ET", "VERIFICAR Y CONTINUAR", "PRÜFEN & WEITER", "VÉRIFIER & CONTINUER" },
    { "Need help getting access?", "Erişim için yardıma mı ihtiyacın var?", "¿Necesitas ayuda para acceder?", "Brauchst du Hilfe beim Zugriff?", "Besoin d'aide pour accéder ?" },
    { "Join the NostraTeam community", "NostraTeam topluluğuna katıl", "Únete a la comunidad NostraTeam", "Tritt der NostraTeam-Community bei", "Rejoignez la communauté NostraTeam" },
    { "COPY INVITE", "DAVETİ KOPYALA", "COPIAR INVITACIÓN", "EINLADUNG KOPIEREN", "COPIER L'INVITATION" },
    { "After fall", "Düştükten sonra", "Después de caer", "Nach dem Sturz", "Après la chute" },
    { "Waiting for re-seat", "Tekrar oturman bekleniyor", "Esperando a que vuelvas a sentarte", "Warte auf erneutes Aufsitzen", "En attente de réinstallation" },
    { "Change location only after you fall off", "Konum yalnızca araçtan düştüğünde değişir", "La ubicación cambia solo cuando te caes del vehículo", "Der Ort wechselt erst, wenn du vom Fahrzeug fällst", "Le lieu change uniquement après être tombé du véhicule" },
    { "This key is already assigned to another control", "Bu tuş başka bir kontrole atanmış", "Esta tecla ya está asignada a otro control", "Diese Taste ist bereits einer anderen Steuerung zugewiesen", "Cette touche est déjà affectée à un autre contrôle" },
    { "Enter your key", "Keyini gir", "Introduce tu clave", "Schlüssel eingeben", "Entrez votre clé" },
    { "Verify", "Doğrula", "Verificar", "Prüfen", "Vérifier" },
    { "TRY AGAIN", "TEKRAR DENE", "INTENTAR DE NUEVO", "ERNEUT VERSUCHEN", "RÉESSAYER" },
    { "Enter the access key to continue", "Devam etmek için erişim keyini gir", "Introduce la clave para continuar", "Gib den Zugangsschlüssel ein", "Saisissez la clé pour continuer" },
    { "Anti-AFK Key", "Anti-AFK Tuşu", "Tecla Anti-AFK", "Anti-AFK-Taste", "Touche Anti-AFK" },
    { "Choose which key Anti-AFK presses", "Anti-AFK'nin basacağı tuşu seç", "Elige la tecla que pulsa Anti-AFK", "Wähle die Taste für Anti-AFK", "Choisissez la touche utilisée par Anti-AFK" },
    { "Verifying key...", "Key doğrulanıyor...", "Verificando clave...", "Schlüssel wird geprüft...", "Vérification de la clé..." },
    { "Key accepted", "Key onaylandı", "Clave aceptada", "Schlüssel akzeptiert", "Clé acceptée" },
    { "Invalid key", "Geçersiz key", "Clave inválida", "Ungültiger Schlüssel", "Clé invalide" },
    { "Join our Discord", "Discord sunucumuza katıl", "Únete a nuestro Discord", "Tritt unserem Discord bei", "Rejoignez notre Discord" },
    { "Copy", "Kopyala", "Copiar", "Kopieren", "Copier" },
    { "Copied", "Kopyalandı", "Copiado", "Kopiert", "Copié" },
}
for _, row in ipairs(Rows) do
    for code, col in pairs(LangCols) do
        Strings[code][row[1]] = row[col]
    end
end

local function T(s)
    local t = Strings[Lang]
    return t and t[s] or s
end

local Localized = {}
local function localize(obj, key)
    table.insert(Localized, { obj, key })
end

---------------------------------------------------------------------
-- CORE ENGINE  (runs on its own - does not depend on the UI at all)
---------------------------------------------------------------------
local log = function() end
local notify = function() end
local saveConfig = function() end
local Painters = {}

-- Cosmetic weather affects only this client's Lighting; it does not change the server.
local WeatherPresets = {
    Day = {
        ClockTime = 13.5, Brightness = 2.4, ExposureCompensation = 0.05,
        FogColor = Color3.fromRGB(196, 211, 205), FogStart = 0, FogEnd = 100000,
        Ambient = Color3.fromRGB(118, 124, 118), OutdoorAmbient = Color3.fromRGB(145, 150, 142),
        ColorShift_Top = Color3.fromRGB(0, 0, 0), ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
        Atmosphere = { Color = Color3.fromRGB(199, 218, 220), Decay = Color3.fromRGB(106, 125, 125), Density = 0.22, Glare = 0.05, Haze = 0.5, Offset = 0.1 },
    },
    Sunset = {
        ClockTime = 18.15, Brightness = 2.0, ExposureCompensation = 0.0,
        FogColor = Color3.fromRGB(220, 151, 123), FogStart = 0, FogEnd = 100000,
        Ambient = Color3.fromRGB(115, 74, 68), OutdoorAmbient = Color3.fromRGB(137, 91, 76),
        ColorShift_Top = Color3.fromRGB(255, 137, 92), ColorShift_Bottom = Color3.fromRGB(95, 52, 64),
        Atmosphere = { Color = Color3.fromRGB(255, 185, 145), Decay = Color3.fromRGB(143, 87, 87), Density = 0.28, Glare = 0.28, Haze = 1.4, Offset = 0.05 },
    },
    Night = {
        ClockTime = 0.35, Brightness = 1.05, ExposureCompensation = -0.15,
        FogColor = Color3.fromRGB(28, 39, 65), FogStart = 0, FogEnd = 100000,
        Ambient = Color3.fromRGB(35, 43, 67), OutdoorAmbient = Color3.fromRGB(48, 57, 83),
        ColorShift_Top = Color3.fromRGB(30, 42, 80), ColorShift_Bottom = Color3.fromRGB(12, 17, 38),
        Atmosphere = { Color = Color3.fromRGB(95, 113, 165), Decay = Color3.fromRGB(32, 42, 76), Density = 0.32, Glare = 0, Haze = 1.0, Offset = 0.1 },
    },
    Fog = {
        ClockTime = 9.2, Brightness = 1.55, ExposureCompensation = -0.05,
        FogColor = Color3.fromRGB(167, 180, 178), FogStart = 0, FogEnd = 520,
        Ambient = Color3.fromRGB(100, 108, 106), OutdoorAmbient = Color3.fromRGB(116, 125, 122),
        ColorShift_Top = Color3.fromRGB(195, 205, 201), ColorShift_Bottom = Color3.fromRGB(120, 132, 130),
        Atmosphere = { Color = Color3.fromRGB(185, 197, 190), Decay = Color3.fromRGB(106, 119, 116), Density = 0.48, Glare = 0, Haze = 2.6, Offset = 0.2 },
    },
    Winter = {
        ClockTime = 20.2, Brightness = 1.35, ExposureCompensation = -0.05,
        FogColor = Color3.fromRGB(119, 147, 174), FogStart = 0, FogEnd = 1800,
        Ambient = Color3.fromRGB(65, 83, 111), OutdoorAmbient = Color3.fromRGB(78, 101, 132),
        ColorShift_Top = Color3.fromRGB(92, 132, 182), ColorShift_Bottom = Color3.fromRGB(31, 49, 82),
        Atmosphere = { Color = Color3.fromRGB(156, 190, 225), Decay = Color3.fromRGB(62, 88, 126), Density = 0.36, Glare = 0.02, Haze = 1.7, Offset = 0.12 },
    },
}

local function captureWeather()
    if WeatherBackup then return end
    WeatherBackup = {
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        ExposureCompensation = Lighting.ExposureCompensation,
        FogColor = Lighting.FogColor,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
    }
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        WeatherAtmosphereBackup = {
            Instance = atmosphere,
            Color = atmosphere.Color,
            Decay = atmosphere.Decay,
            Density = atmosphere.Density,
            Glare = atmosphere.Glare,
            Haze = atmosphere.Haze,
            Offset = atmosphere.Offset,
        }
    end
end

local function restoreWeather()
    if WeatherBackup then
        for property, value in pairs(WeatherBackup) do
            pcall(function() Lighting[property] = value end)
        end
    end
    if WeatherAtmosphereBackup then
        local atmosphere = WeatherAtmosphereBackup.Instance
        if atmosphere and atmosphere.Parent then
            for property, value in pairs(WeatherAtmosphereBackup) do
                if property ~= "Instance" then
                    pcall(function() atmosphere[property] = value end)
                end
            end
        end
    end
    if WeatherCreatedAtmosphere and WeatherCreatedAtmosphere.Parent then
        WeatherCreatedAtmosphere:Destroy()
    end
    WeatherBackup = nil
    WeatherAtmosphereBackup = nil
    WeatherCreatedAtmosphere = nil
end

local function applyWeather(mode)
    if mode == "Default" then
        restoreWeather()
        WeatherMode = "Default"
        return true
    end
    local preset = WeatherPresets[mode]
    if not preset then return false end
    captureWeather()
    for property, value in pairs(preset) do
        if property ~= "Atmosphere" then
            Lighting[property] = value
        end
    end
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "BikeUniverseLocalAtmosphere"
        atmosphere.Parent = Lighting
        WeatherCreatedAtmosphere = atmosphere
    end
    for property, value in pairs(preset.Atmosphere) do
        atmosphere[property] = value
    end
    WeatherMode = mode
    return true
end

-- Sliders modify only the local client's Lighting. The original scene is
-- captured once and restored when the user selects Default or unloads.
local function applyWeatherCustomization()
    captureWeather()
    Lighting.ClockTime = math.clamp(WeatherCustom.Time, 0, 23.9)
    Lighting.Brightness = math.clamp(WeatherCustom.Brightness, 0.1, 5)
    local fog = math.clamp(WeatherCustom.Fog, 0, 100) / 100
    Lighting.FogStart = 0
    Lighting.FogEnd = 100000 - (fog * 98500)

    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "BikeUniverseLocalAtmosphere"
        atmosphere.Parent = Lighting
        WeatherCreatedAtmosphere = atmosphere
    end
    atmosphere.Density = 0.02 + (fog * 0.58)
    atmosphere.Haze = fog * 2.4
    WeatherCustom.Enabled = true
    return true
end

local function chooseWeather(mode)
    WeatherCustom.Enabled = false
    local ok, result = pcall(applyWeather, mode)
    if not ok or not result then
        warn("[BikeUniverse] weather could not be applied: " .. tostring(result))
        return
    end
    if Painters._weather then Painters._weather() end
    if WeatherCustomStatusLabel and WeatherCustomStatusLabel.Parent then
        WeatherCustomStatusLabel.Text = T("Adjust the sliders to build your own look")
    end
    saveConfig()
    notify("Weather applied", C.good)
end

local function getHumanoid()
    if Humanoid and Humanoid.Parent then
        return Humanoid
    end
    local char = LocalPlayer.Character
    Humanoid = char and char:FindFirstChildOfClass("Humanoid") or nil
    return Humanoid
end

local function getSeat()
    local hum = getHumanoid()
    return hum and hum.SeatPart or nil
end

local function getVehicle()
    local seat = getSeat()
    if not seat then return nil end
    local model = seat:FindFirstAncestorOfClass("Model")
    return model or seat
end

local function zeroVelocity(part)
    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function sendKey(down, key)
    local ok = pcall(function()
        VIM:SendKeyEvent(down, key, false, game)
    end)
    return ok
end

local LastVirtualAttempt = 0
local LastVirtualPingWarning = 0
local function sendVirtualKeepAlive(force)
    if not Cfg.AntiAFK then return false end
    local now = os.clock()
    if not force and now - LastVirtualAttempt < 25 then return true end
    if force and now - LastVirtualAttempt < 2 then return false end

    -- Record attempts too: an unsupported VirtualUser call must not be retried
    -- on every Heartbeat when the executor blocks it.
    LastVirtualAttempt = now
    local ok = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
    if ok then
        return true
    end

    if now - LastVirtualPingWarning >= 30 then
        LastVirtualPingWarning = now
        warn("[BikeUniverse] VirtualUser keep-alive is unavailable in this executor")
    end
    return false
end

local function releaseKeys()
    sendKey(false, Enum.KeyCode.W)
    sendKey(false, AntiAFKKey)
    Jumping = false
    KeyHeld = false
end

---------------------------------------------------------------------
-- Locations / teleport
---------------------------------------------------------------------
local function activeIdx()
    if Cfg.TeleMode == 1 then return 1 end
    if Cfg.TeleMode == 2 then return 2 end
    return CurrentLoc
end

local function locCFrame(i)
    local l = Locs[i]
    if not l or not l.pos then return nil end
    return CFrame.new(l.pos) * CFrame.Angles(0, math.rad(l.yaw or 0), 0)
end

local function TryTeleport(idx, manual)
    idx = idx or activeIdx()
    local vehicle = getVehicle()
    if not vehicle or not vehicle.Parent then
        HasTeleported = false
        NextTeleportAttempt = os.clock() + 1
        return false
    end

    local cf = locCFrame(idx)
    if not cf then
        HasTeleported = false
        NextTeleportAttempt = os.clock() + 2
        notify(string.format(T("Location %d is unavailable"), idx), C.bad)
        return false
    end

    local ok, err = pcall(function()
        if vehicle:IsA("Model") then
            vehicle:PivotTo(cf)
            local assemblyRoot = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart", true)
            if assemblyRoot then pcall(zeroVelocity, assemblyRoot) end
        elseif vehicle:IsA("BasePart") then
            vehicle.CFrame = cf
            pcall(zeroVelocity, vehicle)
        else
            error("Vehicle model is no longer available")
        end
    end)

    if not ok then
        HasTeleported = false
        NextTeleportAttempt = os.clock() + 1.5
        log("Teleport failed: " .. tostring(err), C.bad)
        return false
    end

    HasTeleported = true
    NextTeleportAttempt = 0
    TeleportCount = TeleportCount + 1
    local msg = string.format(T("Teleported to Location %d"), idx)
    if manual then notify(msg, C.good) else log(msg, C.good) end
    return true
end

local function goTo(idx)
    if not getVehicle() then
        notify("No vehicle found - sit on one first", C.bad)
        return
    end
    CurrentLoc = idx
    PendingRandomSwitch = false
    TryTeleport(idx, true)
end

local function setMode(m)
    Cfg.TeleMode = m
    if m == 1 then
        CurrentLoc = 1
    elseif m == 2 then
        CurrentLoc = 2
    elseif m == 3 then
        CurrentLoc = math.random(1, 2)
    end
    PendingRandomSwitch = false
    HasTeleported = false
    NextTeleportAttempt = 0
    if Painters._mode then Painters._mode() end
    saveConfig()
    notify(string.format(T("Mode: %s"), T(ModeNames[m])), C.accent)
end

local MAX_RESEAT_DISTANCE = 10

local function findSeat()
    local hum = getHumanoid()
    local root = hum and hum.RootPart
    if not root then return nil end

    local function usableSeat(seat)
        if not seat or not seat.Parent then return false end
        if not (seat:IsA("VehicleSeat") or seat:IsA("Seat")) then return false end
        if seat.Occupant ~= nil or seat.Disabled then return false end
        local model = seat:FindFirstAncestorOfClass("Model")
        local name = model and model.Name or (seat.Parent and seat.Parent.Name or seat.Name)
        if SavedVehicleName and name ~= SavedVehicleName then return false end
        return (seat.Position - root.Position).Magnitude <= MAX_RESEAT_DISTANCE
    end

    if usableSeat(SavedSeat) then return SavedSeat end

    local best, bestDist = nil, MAX_RESEAT_DISTANCE
    local function consider(part)
        if usableSeat(part) then
            local dist = (part.Position - root.Position).Magnitude
            if dist < bestDist then
                best, bestDist = part, dist
            end
        end
    end

    local okN, near = pcall(function()
        return workspace:GetPartBoundsInRadius(root.Position, MAX_RESEAT_DISTANCE)
    end)
    if okN and near then
        for _, part in ipairs(near) do consider(part) end
    end
    if best then return best end

    -- Deliberately avoid scanning every descendant in Workspace. On large
    -- maps that scan can hitch the client; nearby-seat detection is sufficient.
    return best
end

local function tryReseat()
    local hum = getHumanoid()
    if not hum or hum.Health <= 0 or not hum.RootPart or hum.SeatPart then return false end
    local seat = findSeat()
    if not seat then return false end

    -- Never teleport the character root to the seat: that can break joints/animations
    -- when the bike has moved away. Roblox's seat interaction handles the alignment.
    local ok = pcall(function() seat:Sit(hum) end)
    if not ok then return false end

    PendingReseat = true
    task.delay(1.25, function()
        if Alive and (not hum.Parent or hum.SeatPart ~= seat) then
            PendingReseat = false
        end
    end)
    log("Re-sitting on vehicle", C.dim)
    return true
end

local function applyBoost(on)
    pcall(function()
        if on then
            if not BoostBackup then
                BoostBackup = {
                    quality = settings().Rendering.QualityLevel,
                    shadows = Lighting.GlobalShadows,
                }
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
        elseif BoostBackup then
            settings().Rendering.QualityLevel = BoostBackup.quality
            Lighting.GlobalShadows = BoostBackup.shadows
            BoostBackup = nil
        end
    end)
end

local function apply3D(off)
    pcall(function()
        RunService:Set3dRenderingEnabled(not off)
    end)
end

local function setFlag(key, value)
    Cfg[key] = value
    if Painters[key] then Painters[key]() end
    if key == "FpsBoost" then
        applyBoost(value)
    elseif key == "Render3DOff" then
        apply3D(value)
    elseif key == "Snow" then
        if SnowLayer then SnowLayer.Visible = value and not Minimized end
    elseif key == "AutoDrive" then
        if value then
            KeyHeld = false
        else
            releaseKeys()
        end
    elseif key == "AutoTeleport" then
        if value then
            HasTeleported = false
            NextTeleportAttempt = 0
        else
            PendingRandomSwitch = false
            UnseatedSince = nil
        end
    elseif key == "AntiAFK" then
        LastJump = os.clock()
        if not value and Jumping then
            sendKey(false, AntiAFKKey)
            Jumping = false
        end
    end
    saveConfig()
    notify(string.format(T(value and "%s enabled" or "%s disabled"), T(FlagNames[key])), value and C.good or C.warn)
end

-- anti-afk (idle event)
track(LocalPlayer.Idled:Connect(function()
    if Cfg.AntiAFK then
        sendVirtualKeepAlive(true)
    end
end))

local function queueReload()
    pcall(function()
        local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        if q then
            q('pcall(function() if isfile and isfile("BikeUniverse.lua") then loadstring(readfile("BikeUniverse.lua"))() end end)')
        end
    end)
end

local PrivateNotice = false
local function rejoin()
    if Rejoining or not Alive or not Cfg.AutoRejoin then return end
    if game.PrivateServerId ~= "" then
        if not PrivateNotice then
            PrivateNotice = true
            notify("Private server - Auto Rejoin is off", C.warn)
        end
        return
    end
    Rejoining = true
    notify("Disconnected - rejoining", C.warn)
    task.spawn(function()
        task.wait(1.5)
        queueReload()
        while Alive and Cfg.AutoRejoin do
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            task.wait(10)
        end
        Rejoining = false
    end)
end

track(GuiService.ErrorMessageChanged:Connect(function()
    local msg = ""
    pcall(function() msg = GuiService:GetErrorMessage() end)
    if msg ~= "" then rejoin() end
end))

task.spawn(function()
    if not CoreGui then return end
    local ok, overlay = pcall(function()
        return CoreGui:WaitForChild("RobloxPromptGui", 15):WaitForChild("promptOverlay", 15)
    end)
    if ok and overlay and Alive then
        track(overlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then rejoin() end
        end))
    end
end)

-- One throttled engine loop (20Hz): enough for seat/drive checks without
-- running all automation work on every rendered frame.
local EngineAccumulator = 0
track(RunService.Heartbeat:Connect(function(dt)
    if not Alive then return end
    EngineAccumulator = EngineAccumulator + math.min(dt, 0.2)
    if EngineAccumulator < 0.05 then return end
    EngineAccumulator = 0
    local ok, err = pcall(function()
    local now = os.clock()
    local seat = getSeat()

    if seat ~= LastSeat then
        local previousSeat = LastSeat
        LastSeat = seat
        KeyHeld = false

        if previousSeat and not seat then
            UnseatedSince = now
            if Jumping then
                sendKey(false, AntiAFKKey)
                Jumping = false
            end
            sendKey(false, Enum.KeyCode.W)
        end

        if seat then
            SavedSeat = seat
            ReseatFails = 0
            local vehicleModel = seat:FindFirstAncestorOfClass("Model")
            local vehicleName = vehicleModel and vehicleModel.Name or (seat.Parent and seat.Parent.Name or seat.Name)
            SavedVehicleName = vehicleName

            if vehicleModel and vehicleModel ~= CurrentVehicleModel then
                if CurrentVehicleModel and CurrentVehicleModel.Parent then
                    VehicleChangeCount = VehicleChangeCount + 1
                    log(string.format(T("Vehicle changed: %s"), vehicleName), C.accent)
                end
                CurrentVehicleModel = vehicleModel
                CurrentVehicleName = vehicleName
            elseif not vehicleModel then
                CurrentVehicleName = vehicleName
            end

            if PendingRandomSwitch and Cfg.TeleMode == 3 and Cfg.AutoTeleport then
                CurrentLoc = (CurrentLoc == 1) and 2 or 1
                PendingRandomSwitch = false
                HasTeleported = false
                NextTeleportAttempt = now + 0.25
                log("Fall confirmed - alternate location selected", C.accent)
            elseif PendingReseat then
                HasTeleported = not Cfg.RespawnTeleport
            end
            UnseatedSince = nil
            PendingReseat = false
        end
    end

    if CurrentVehicleModel and not CurrentVehicleModel.Parent then
        CurrentVehicleModel = nil
        CurrentVehicleName = "No vehicle detected"
    end

    if not seat and UnseatedSince and not PendingRandomSwitch
        and Cfg.TeleMode == 3 and Cfg.AutoTeleport and now - UnseatedSince >= 0.45 then
        PendingRandomSwitch = true
    end

    if not seat and Cfg.AutoReseat and SavedVehicleName and now >= NextReseat
        and (not UnseatedSince or now - UnseatedSince >= 0.5) then
        if tryReseat() then
            ReseatFails = 0
            NextReseat = now + 2
        else
            ReseatFails = math.min(ReseatFails + 1, 8)
            NextReseat = now + math.min(4 * ReseatFails, 30)
        end
    end

    if Cfg.AutoDrive then
        if seat then
            if (not KeyHeld) or now >= NextKeyRefresh then
                sendKey(true, Enum.KeyCode.W)
                KeyHeld = true
                NextKeyRefresh = now + 1
            end

        elseif KeyHeld then
            -- Never keep accelerating on foot while waiting to re-seat.
            sendKey(false, Enum.KeyCode.W)
            KeyHeld = false
        end
    end

    -- Auto Teleport is independent from Auto Drive; either can be enabled alone.
    if seat and Cfg.AutoTeleport and not HasTeleported and now >= NextTeleportAttempt then
        TryTeleport(activeIdx(), false)
    end

    if Cfg.AntiAFK then
        -- Keep the AFK session active even while mounted. A keyboard action
        -- such as Space can eject riders in some bike systems, so the chosen
        -- key is sent only while the character is on foot.
        if now - LastVirtualAttempt >= 25 then
            sendVirtualKeepAlive(false)
        end

        if seat then
            if Jumping then
                sendKey(false, AntiAFKKey)
                Jumping = false
            end
        elseif Jumping then
            if now >= JumpEnd then
                sendKey(false, AntiAFKKey)
                Jumping = false
            end
        elseif now - LastJump >= Cfg.JumpInterval then
            local sent = sendKey(true, AntiAFKKey)
            LastJump = now
            if sent then
                Jumping = true
                JumpEnd = now + Cfg.HoldTime
                JumpCount = JumpCount + 1
                log("Anti-AFK: " .. AntiAFKKey.Name .. " pressed", C.dim)
            else
                -- VirtualUser still provides a keep-alive if key injection is
                -- blocked by the current executor.
                sendVirtualKeepAlive(true)
            end
        end
    else
        if Jumping then
            sendKey(false, AntiAFKKey)
            Jumping = false
        end
        LastJump = now
    end
    end)
    if not ok and os.clock() - LastEngineError >= 5 then
        LastEngineError = os.clock()
        warn("[BikeUniverse] engine recovered from an error: " .. tostring(err))
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function()
    sendKey(false, Enum.KeyCode.W)
    sendKey(false, AntiAFKKey)
    Humanoid = nil
    LastSeat = nil
    UnseatedSince = nil
    CurrentVehicleModel = nil
    CurrentVehicleName = "No vehicle detected"
    KeyHeld = false
    Jumping = false
    LastJump = os.clock()
    LastVirtualAttempt = 0
    HasTeleported = not Cfg.RespawnTeleport
    PendingRandomSwitch = false
    NextTeleportAttempt = os.clock() + 2.5
    NextReseat = os.clock() + 2.5
    notify("Respawned - resyncing", C.dim)
end))

local Swatches = {
    { "Santa Red", Color3.fromRGB(214, 40, 57) },
    { "Pine Green", Color3.fromRGB(46, 160, 98) },
    { "Gold", Color3.fromRGB(245, 182, 50) },
    { "Ice Blue", Color3.fromRGB(96, 176, 255) },
    { "Candy Pink", Color3.fromRGB(244, 106, 150) },
    { "Silver", Color3.fromRGB(190, 200, 210) },
}

---------------------------------------------------------------------
-- Saved settings (only works if your executor supports readfile/writefile)
---------------------------------------------------------------------
local CONFIG_FILE = "BikeUniverse_config.json"
local AccentIndex = 1
local ConfigReady = false
local saveToken = 0

local function loadConfig()
    local ok, data = pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if not ok or type(data) ~= "table" then return end

    for _, k in ipairs({ "Notifications", "Snow" }) do
        if type(data[k]) == "boolean" then Cfg[k] = data[k] end
    end
    if type(data.Language) == "string" and (data.Language == "en" or Strings[data.Language]) then
        Lang = data.Language
    end
    if type(data.JumpInterval) == "number" then Cfg.JumpInterval = math.clamp(math.floor(data.JumpInterval), 15, 120) end
    if type(data.HoldSeconds) == "number" then Cfg.HoldTime = math.clamp(math.floor(data.HoldSeconds * 10 + 0.5) / 10, 0.1, 3) end
    if type(data.TeleMode) == "number" and data.TeleMode >= 1 and data.TeleMode <= 3 then
        Cfg.TeleMode = math.floor(data.TeleMode)
        CurrentLoc = (Cfg.TeleMode == 2) and 2 or 1
    end
    if type(data.WeatherMode) == "string"
        and (data.WeatherMode == "Default" or WeatherPresets[data.WeatherMode]) then
        WeatherMode = data.WeatherMode
    end
    if type(data.WeatherCustom) == "table" then
        if type(data.WeatherCustom.Enabled) == "boolean" then WeatherCustom.Enabled = data.WeatherCustom.Enabled end
        if type(data.WeatherCustom.Time) == "number" then WeatherCustom.Time = math.clamp(data.WeatherCustom.Time, 0, 23.9) end
        if type(data.WeatherCustom.Brightness) == "number" then WeatherCustom.Brightness = math.clamp(data.WeatherCustom.Brightness, 0.1, 5) end
        if type(data.WeatherCustom.Fog) == "number" then WeatherCustom.Fog = math.clamp(data.WeatherCustom.Fog, 0, 100) end
    end

    local function keyFrom(name)
        if type(name) ~= "string" then return nil end
        local okk, kc = pcall(function() return Enum.KeyCode[name] end)
        return okk and kc or nil
    end
    ToggleKey = keyFrom(data.ToggleKey) or ToggleKey
    HideKey = keyFrom(data.HideKey) or HideKey
    SwapKey = keyFrom(data.SwapKey) or SwapKey
    AntiAFKKey = keyFrom(data.AntiAFKKey) or AntiAFKKey

    if type(data.Accent) == "number" and Swatches[data.Accent] then
        AccentIndex = data.Accent
        C.accent = Swatches[AccentIndex][2]
    end
end

saveConfig = function()
    if not ConfigReady then return end
    saveToken = saveToken + 1
    local mine = saveToken
    task.delay(0.6, function()
        if mine ~= saveToken then return end
        pcall(function()
            if type(writefile) ~= "function" then return end
            writefile(CONFIG_FILE, HttpService:JSONEncode({
                Notifications = Cfg.Notifications,
                Snow = Cfg.Snow,
                Language = Lang,
                JumpInterval = Cfg.JumpInterval,
                HoldSeconds = Cfg.HoldTime,
                TeleMode = Cfg.TeleMode,
                WeatherMode = WeatherMode,
                WeatherCustom = {
                    Enabled = WeatherCustom.Enabled,
                    Time = WeatherCustom.Time,
                    Brightness = WeatherCustom.Brightness,
                    Fog = WeatherCustom.Fog,
                },
                ToggleKey = ToggleKey.Name,
                HideKey = HideKey.Name,
                SwapKey = SwapKey.Name,
                AntiAFKKey = AntiAFKKey.Name,
                Accent = AccentIndex,
            }))
        end)
    end)
end

loadConfig()
if WeatherMode ~= "Default" then
    local weatherOk, weatherErr = pcall(applyWeather, WeatherMode)
    if not weatherOk then
        warn("[BikeUniverse] saved weather could not be restored: " .. tostring(weatherErr))
        WeatherMode = "Default"
    end
end
if WeatherCustom.Enabled then
    local customOk, customErr = pcall(applyWeatherCustomization)
    if not customOk then
        warn("[BikeUniverse] saved custom weather could not be restored: " .. tostring(customErr))
        WeatherCustom.Enabled = false
    end
end
if Cfg.TeleMode == 3 then
    CurrentLoc = math.random(1, 2)
end
if AntiAFKKey == Enum.KeyCode.Unknown or AntiAFKKey == Enum.KeyCode.W
    or AntiAFKKey == Enum.KeyCode.A or AntiAFKKey == Enum.KeyCode.S or AntiAFKKey == Enum.KeyCode.D
    or AntiAFKKey == ToggleKey or AntiAFKKey == SwapKey or AntiAFKKey == HideKey then
    AntiAFKKey = Enum.KeyCode.Space
end

-- Safety default: the user must enable every gameplay automation manually.
Cfg.AutoDrive = false
Cfg.AutoTeleport = false
Cfg.AntiAFK = false
Cfg.AutoReseat = false
Cfg.AutoRejoin = false
Cfg.RespawnTeleport = false

local function buildUI()

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local F_REG = Enum.Font.Gotham
local F_MED = Enum.Font.GothamMedium
local F_BOLD = Enum.Font.GothamBold
local F_BLACK = Enum.Font.GothamBlack

local WIN_W, WIN_H, TOP_H, SIDE_W = 620, 480, 50, 150
local fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function new(class, props, parent)
    local inst = Instance.new(class)
    if class == "TextLabel" or class == "TextButton" or class == "TextBox" or class == "ScreenGui" then
        pcall(function() inst.AutoLocalize = false end)
    end
    for k, v in pairs(props) do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent, color, transparency)
    return new("UIStroke", {
        Color = color or C.line,
        Thickness = 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, t, r, b, l)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r),
        PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l),
    }, parent)
end

local function label(parent, str, size, color, font, pos, sz, align)
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = T(str),
        TextSize = size,
        TextColor3 = color,
        Font = font,
        Position = pos or UDim2.new(),
        Size = sz or UDim2.new(1, 0, 1, 0),
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if str ~= "" then localize(l, str) end
    return l
end

local function setProp(obj, prop, value)
    if obj[prop] ~= value then
        obj[prop] = value
    end
end

local AccentRefs = {}
local function reg(obj, prop)
    obj[prop] = C.accent
    table.insert(AccentRefs, { obj, prop })
    return obj
end

-- little motorbike icon built from plain frames
local function bikeIcon(parent, size)
    local u = size / 24
    local function px(n) return math.max(1, math.floor(n * u + 0.5)) end

    local holder = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
    }, parent)

    local function wheel(x)
        local w = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(px(x), px(12)),
            Size = UDim2.fromOffset(px(9), px(9)),
        }, holder)
        corner(w, 99)
        new("UIStroke", {
            Color = WHITE,
            Thickness = math.max(1.5, 2 * u),
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, w)
    end
    wheel(2)
    wheel(13)

    local function bar(x, y, w, h, rot)
        local b = new("Frame", {
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(px(x), px(y)),
            Size = UDim2.fromOffset(px(w), px(h)),
            Rotation = rot or 0,
        }, holder)
        corner(b, px(1))
    end
    bar(11.5, 16, 10, 2)
    bar(8.5, 11, 7, 2.4)
    bar(17, 11, 2, 10, 18)
    bar(15.5, 6, 5, 2, 18)
    return holder
end

-- Small Santa cap attached to the icon's top edge.
local function santaHat(parent, x, y, s, z)
    local hat = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(18 * s, 15 * s),
        ZIndex = z,
    }, parent)
    local crown = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(194, 35, 49),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(9 * s, 7 * s),
        Size = UDim2.fromOffset(13 * s, 9 * s),
        Rotation = -24,
        ZIndex = z,
    }, hat)
    corner(crown, math.max(2, math.floor(4 * s)))
    local brim = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(250, 249, 242),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(9 * s, 11 * s),
        Size = UDim2.fromOffset(17 * s, 3.5 * s),
        Rotation = -24,
        ZIndex = z + 1,
    }, hat)
    corner(brim, 3 * s)
    local pom = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(250, 249, 242),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1 * s, 0),
        Size = UDim2.fromOffset(5 * s, 5 * s),
        ZIndex = z + 2,
    }, hat)
    corner(pom, 99)
    return hat
end

-- falling snow: returns the layer and a step(dt) function
local function makeSnow(parent, count, z, maxSize)
    z = z or 20
    maxSize = maxSize or 5
    local layer = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ClipsDescendants = true,
        ZIndex = z,
    }, parent)
    local flakes = {}
    for i = 1, count do
        local sz = math.random(2, maxSize)
        local f = new("Frame", {
            BackgroundColor3 = WHITE,
            BackgroundTransparency = math.random(15, 60) / 100,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(sz, sz),
            ZIndex = z,
        }, layer)
        corner(f, 99)
        flakes[i] = {
            f = f,
            x = math.random(),
            y = math.random(),
            speed = 0.05 + math.random() * 0.1 + sz * 0.006,
            sway = 0.6 + math.random() * 1.2,
            phase = math.random() * 6.28,
        }
        f.Position = UDim2.fromScale(flakes[i].x, flakes[i].y)
    end
    local t = 0
    local accumulator = 0
    local updateStep = 1 / 24
    local function step(dt)
        accumulator = accumulator + math.min(dt, 0.1)
        if accumulator < updateStep then return end
        local elapsed = accumulator
        accumulator = 0
        t = t + elapsed
        for _, flake in ipairs(flakes) do
            flake.y = flake.y + flake.speed * elapsed
            if flake.y > 1.03 then
                flake.y = -0.03
                flake.x = math.random()
            end
            flake.f.Position = UDim2.fromScale(
                flake.x + math.sin(t * flake.sway + flake.phase) * 0.012,
                flake.y
            )
        end
    end
    return layer, step
end

local function cleanupIntro()
    if IntroSnowConn then
        pcall(function() IntroSnowConn:Disconnect() end)
        IntroSnowConn = nil
    end
    if IntroBlur then pcall(function() IntroBlur:Destroy() end) IntroBlur = nil end
    if IntroGui then pcall(function() IntroGui:Destroy() end) IntroGui = nil end
end

---------------------------------------------------------------------
-- Root window
---------------------------------------------------------------------
local old = PlayerGui:FindFirstChild("BikeUniverseUI")
if old then old:Destroy() end

local Gui = new("ScreenGui", { Name = "BikeUniverseUI", ResetOnSpawn = false, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, PlayerGui)

local Root = new("Frame", {
    BackgroundTransparency = 1,
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.5, -WIN_H / 2),
    Size = UDim2.fromOffset(WIN_W, WIN_H),
}, Gui)

local RootScale = new("UIScale", { Scale = 1 }, Root)
local function fitScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    RootScale.Scale = math.clamp(math.min((vp.X - 24) / WIN_W, (vp.Y - 70) / WIN_H), 0.5, 1)
end
fitScale()
Root.Position = UDim2.new(0.5, 0, 0.5, -math.floor(WIN_H * RootScale.Scale / 2))
pcall(function()
    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale))
end)

local Shadow2 = new("Frame", {
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.85, ZIndex = 0,
    Position = UDim2.fromOffset(-10, -6), Size = UDim2.new(1, 20, 1, 22),
}, Root)
corner(Shadow2, 16)
local Shadow1 = new("Frame", {
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, ZIndex = 0,
    Position = UDim2.fromOffset(-4, -2), Size = UDim2.new(1, 8, 1, 10),
}, Root)
corner(Shadow1, 12)

local Window = new("Frame", {
    BackgroundColor3 = C.bg,
    Size = UDim2.new(1, 0, 1, 0),
    ClipsDescendants = true,
    ZIndex = 1,
}, Root)
corner(Window, 10)
reg(stroke(Window, C.accent, 0.3), "Color")

-- top bar
local TopBar = new("Frame", {
    BackgroundColor3 = C.side,
    Size = UDim2.new(1, 0, 0, TOP_H),
    BorderSizePixel = 0,
    ZIndex = 5,
}, Window)

-- candy-cane stripe along the bottom of the title bar
for i = 0, math.ceil(WIN_W / 12) do
    new("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(214, 40, 57) or Color3.fromRGB(245, 245, 245),
        Position = UDim2.fromOffset(i * 12, TOP_H - 4),
        Size = UDim2.fromOffset(12, 4),
        ZIndex = 5,
    }, TopBar)
end

-- string of Christmas lights across the top edge
local Bulbs = {}
do
    local colors = {
        Color3.fromRGB(235, 60, 70),
        Color3.fromRGB(70, 210, 120),
        Color3.fromRGB(255, 205, 80),
        Color3.fromRGB(90, 170, 255),
    }
    new("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(40, 62, 55),
        Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 2), ZIndex = 7,
    }, TopBar)
    local count = 28
    local step = WIN_W / count
    for i = 1, count do
        local x = (i - 0.5) * step
        local b = new("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = colors[(i - 1) % 4 + 1],
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromOffset(x, 2),
            Size = UDim2.fromOffset(5, 7),
            ZIndex = 7,
        }, TopBar)
        corner(b, 3)
        table.insert(Bulbs, b)
    end
end

-- logo (pine tile + bike icon + Santa hat)
local Logo = new("Frame", { BackgroundColor3 = PINE, Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(32, 32), ZIndex = 6 }, TopBar)
corner(Logo, 9)
new("UIGradient", {
    Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 150, 165)),
    Rotation = 55,
}, Logo)
bikeIcon(Logo, 22)
santaHat(Logo, 13, 0, 0.76, 8)

label(TopBar, "Bike Universe", 14, C.text, F_BOLD, UDim2.fromOffset(54, 12), UDim2.new(0, 190, 0, 17)).ZIndex = 6
label(TopBar, "NostraTeam · Christmas Edition", 10, GOLD, F_MED, UDim2.fromOffset(54, 29), UDim2.new(0, 200, 0, 12)).ZIndex = 6

local FpsLabel = label(TopBar, "-- FPS", 11, C.dim, F_MED, UDim2.new(1, -190, 0, 12), UDim2.new(0, 90, 0, 20), Enum.TextXAlignment.Right)
FpsLabel.ZIndex = 6

local function topButton(symbol, xOff)
    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, xOff, 0.5, 1),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = C.card,
        BackgroundTransparency = 1,
        Text = symbol,
        TextColor3 = C.dim,
        TextSize = 16,
        Font = F_BOLD,
        AutoButtonColor = false,
        ZIndex = 6,
    }, TopBar)
    corner(b, 6)
    return b
end

local CloseBtn = topButton("×", -10)
local MinBtn = topButton("–", -42)

local function hoverButton(btn, bg, fg)
    btn.MouseEnter:Connect(function()
        tween(btn, fast, { BackgroundTransparency = 0, BackgroundColor3 = bg, TextColor3 = fg })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, fast, { BackgroundTransparency = 1, TextColor3 = C.dim })
    end)
end
hoverButton(MinBtn, C.cardHi, C.text)
hoverButton(CloseBtn, C.bad, WHITE)

local Body = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(0, TOP_H),
    Size = UDim2.new(1, 0, 1, -TOP_H),
    ClipsDescendants = true,
}, Window)

local Sidebar = new("Frame", {
    BackgroundColor3 = C.side,
    Size = UDim2.new(0, SIDE_W, 1, 0),
    BorderSizePixel = 0,
}, Body)
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0) }, Sidebar)

local NavHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -70) }, Sidebar)
padding(NavHolder, 12, 10, 0, 12)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, NavHolder)

local ProfileCard = new("Frame", {
    BackgroundColor3 = C.card,
    Position = UDim2.new(0, 8, 1, -58),
    Size = UDim2.new(1, -16, 0, 48),
    ClipsDescendants = true,
}, Sidebar)
corner(ProfileCard, 8)
stroke(ProfileCard, C.line, 0.35)
local ProfileAvatar = new("ImageLabel", {
    BackgroundColor3 = C.cardHi,
    Position = UDim2.fromOffset(7, 7),
    Size = UDim2.fromOffset(34, 34),
    Image = "",
    ScaleType = Enum.ScaleType.Crop,
}, ProfileCard)
corner(ProfileAvatar, 17)
local ProfileName = label(ProfileCard, LocalPlayer.DisplayName or LocalPlayer.Name, 11, C.text, F_BOLD,
    UDim2.fromOffset(48, 8), UDim2.new(1, -55, 0, 16))
local ProfileUsername = label(ProfileCard, "@" .. LocalPlayer.Name, 9, C.dim, F_REG,
    UDim2.fromOffset(48, 25), UDim2.new(1, -55, 0, 13))
local PillDot = new("Frame", {
    BackgroundColor3 = C.good,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -6, 0, 6),
    Size = UDim2.fromOffset(6, 6),
}, ProfileCard)
corner(PillDot, 3)
task.spawn(function()
    local ok, imageUrl = pcall(function()
        return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if ok and ProfileAvatar.Parent then
        ProfileAvatar.Image = imageUrl
    end
end)

local Content = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(SIDE_W, 0),
    Size = UDim2.new(1, -SIDE_W, 1, 0),
    ClipsDescendants = true,
}, Body)

local SnowStep
SnowLayer, SnowStep = makeSnow(Window, 10, 20, 4)
SnowLayer.Position = UDim2.fromOffset(0, TOP_H)
SnowLayer.Size = UDim2.new(1, 0, 1, -TOP_H)
SnowLayer.Visible = Cfg.Snow

---------------------------------------------------------------------
-- Pages / tabs
---------------------------------------------------------------------
local Pages, NavButtons, Order = {}, {}, {}
local CurrentTab

local function nextOrder(parent)
    Order[parent] = (Order[parent] or 0) + 1
    return Order[parent]
end

local function selectTab(name)
    CurrentTab = name
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
    end
    for n, nav in pairs(NavButtons) do
        local active = (n == name)
        tween(nav.btn, fast, { BackgroundTransparency = active and 0 or 1, TextColor3 = active and C.text or C.dim })
        tween(nav.bar, fast, { BackgroundTransparency = active and 0 or 1 })
    end
end

local function addTab(name)
    local btn = new("TextButton", {
        BackgroundColor3 = C.card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Text = T(name),
        TextColor3 = C.dim,
        TextSize = 13,
        Font = F_MED,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = nextOrder(NavHolder),
    }, NavHolder)
    localize(btn, name)
    corner(btn, 6)
    padding(btn, 0, 0, 0, 14)

    local bar = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, -10, 0.5, 0),
        Size = UDim2.fromOffset(3, 16),
        BorderSizePixel = 0,
    }, btn)
    reg(bar, "BackgroundColor3")
    corner(bar, 2)

    NavButtons[name] = { btn = btn, bar = bar }

    local page = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.line,
        BorderSizePixel = 0,
        Visible = false,
    }, Content)
    padding(page, 12, 16, 12, 14)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        selectTab(name)
    end)
    btn.MouseEnter:Connect(function()
        if CurrentTab ~= name then tween(btn, fast, { TextColor3 = C.text }) end
    end)
    btn.MouseLeave:Connect(function()
        if CurrentTab ~= name then tween(btn, fast, { TextColor3 = C.dim }) end
    end)
    return page
end

---------------------------------------------------------------------
-- Components
---------------------------------------------------------------------
local function section(page, text)
    local l = label(page, string.upper(text), 10, GOLD, F_BOLD, nil, UDim2.new(1, 0, 0, 16))
    l.LayoutOrder = nextOrder(page)
    return l
end

local function makeRow(page, height)
    local row = new("Frame", {
        BackgroundColor3 = C.card,
        Size = UDim2.new(1, 0, 0, height),
        LayoutOrder = nextOrder(page),
        ClipsDescendants = true,
    }, page)
    corner(row, 7)
    stroke(row, C.line, 0.4)
    return row
end

local function rowTitle(row, title, desc, rightW)
    local reserve = -((rightW or 60) + 28)
    if desc then
        label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 5), UDim2.new(1, reserve, 0, 18))
        label(row, desc, 11, C.dim, F_REG, UDim2.fromOffset(14, 22), UDim2.new(1, reserve, 0, 14))
    else
        label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 0), UDim2.new(1, reserve, 1, 0))
    end
end

local function toggleRow(page, title, desc, key)
    local row = makeRow(page, 42)
    rowTitle(row, title, desc, 54)

    local trackBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(40, 20),
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = C.off,
    }, row)
    corner(trackBtn, 10)
    local knob = new("Frame", {
        BackgroundColor3 = WHITE,
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(3, 3),
    }, trackBtn)
    corner(knob, 7)

    Painters[key] = function()
        local on = Cfg[key]
        tween(trackBtn, fast, { BackgroundColor3 = on and C.accent or C.off })
        tween(knob, fast, { Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) })
    end
    Painters[key]()

    trackBtn.MouseButton1Click:Connect(function()
        setFlag(key, not Cfg[key])
    end)
end

local function makeButton(parent, text, color, callback, size, order)
    local isAccent = (color == "accent")
    local function base() return isAccent and C.accent or color end
    local btn = new("TextButton", {
        BackgroundColor3 = base(),
        Size = size or UDim2.new(1, 0, 0, 36),
        Text = T(text),
        TextColor3 = WHITE,
        TextSize = 13,
        Font = F_BOLD,
        AutoButtonColor = false,
        LayoutOrder = order or 0,
    }, parent)
    localize(btn, text)
    if isAccent then reg(btn, "BackgroundColor3") end
    corner(btn, 7)
    btn.MouseEnter:Connect(function()
        tween(btn, fast, { BackgroundColor3 = base():Lerp(WHITE, 0.12) })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, fast, { BackgroundColor3 = base() })
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function buttonRow(page, text, color, callback)
    return makeButton(page, text, color, callback, nil, nextOrder(page))
end

local function buttonPair(page, a, b)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = nextOrder(page),
    }, page)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
    makeButton(holder, a[1], a[2], a[3], UDim2.new(0.5, -4, 1, 0), 1)
    makeButton(holder, b[1], b[2], b[3], UDim2.new(0.5, -4, 1, 0), 2)
end

local function keybindRow(page, title, desc, getKey, setKey)
    local row = makeRow(page, 42)
    rowTitle(row, title, desc, 114)

    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(100, 26),
        BackgroundColor3 = C.bg,
        Text = getKey().Name,
        TextSize = 12,
        Font = F_BOLD,
        AutoButtonColor = false,
    }, row)
    reg(btn, "TextColor3")
    corner(btn, 6)
    stroke(btn)

    btn.MouseButton1Click:Connect(function()
        if Listening then
            Listening.btn.Text = Listening.get().Name
            Listening.btn.TextColor3 = C.accent
        end
        Listening = { btn = btn, get = getKey, set = setKey }
        btn.Text = T("Press a key...")
        btn.TextColor3 = C.dim
    end)
end

local function sliderRow(page, title, desc, min, max, default, suffix, callback, fmt)
    local row = makeRow(page, 62)
    label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 7), UDim2.new(1, -100, 0, 18))
    label(row, desc, 11, C.dim, F_REG, UDim2.fromOffset(14, 24), UDim2.new(1, -100, 0, 14))
    local valueLbl = label(row, "", 12, C.accent, F_BOLD, UDim2.new(1, -74, 0, 8), UDim2.fromOffset(60, 18), Enum.TextXAlignment.Right)
    reg(valueLbl, "TextColor3")

    local rail = new("Frame", {
        BackgroundColor3 = C.off,
        Position = UDim2.new(0, 14, 0, 47),
        Size = UDim2.new(1, -28, 0, 5),
        BorderSizePixel = 0,
    }, row)
    corner(rail, 3)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, rail)
    reg(fill, "BackgroundColor3")
    corner(fill, 3)
    local knob = new("Frame", {
        BackgroundColor3 = WHITE,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(13, 13),
        Position = UDim2.new(0, 0, 0.5, 0),
    }, rail)
    corner(knob, 7)

    local current = nil
    local function apply(value)
        value = math.clamp(value, min, max)
        if value == current then return end
        current = value
        local a = (value - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        valueLbl.Text = fmt and fmt(value) or (value .. suffix)
        callback(value)
    end
    apply(default)

    local hit = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        Position = UDim2.new(0, 8, 0, 38),
        Size = UDim2.new(1, -16, 0, 22),
    }, row)

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
        apply(math.floor(min + a * (max - min) + 0.5))
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end))
    track(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function infoRow(page, key, value)
    local row = makeRow(page, 34)
    label(row, key, 12, C.dim, F_MED, UDim2.fromOffset(14, 0), UDim2.new(0.5, -14, 1, 0))
    return label(row, value, 12, C.text, F_MED, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -14, 1, 0), Enum.TextXAlignment.Right)
end

local LocTitles = {}
local function locationRow(page, idx)
    local row = makeRow(page, 42)
    LocTitles[idx] = label(row, "Location " .. idx, 13, C.text, F_MED, UDim2.fromOffset(14, 0), UDim2.new(1, -92, 1, 0))

    local go = makeButton(row, "Go", "accent", function() goTo(idx) end, UDim2.fromOffset(62, 28), 1)
    go.AnchorPoint = Vector2.new(1, 0.5)
    go.Position = UDim2.new(1, -10, 0.5, 0)
end

---------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------
local MainPage = addTab("Main")
local WeatherPage = addTab("Weather")
local SettingsPage = addTab("Settings")
local LogPage = addTab("Log")
local InfoPage = addTab("Info")

---------------------------------------------------------------------
-- Personal weather page (client-side visual settings only)
---------------------------------------------------------------------
section(WeatherPage, "PERSONAL WEATHER")
local WeatherIntro = makeRow(WeatherPage, 52)
label(WeatherIntro, "Choose a look just for yourself", 13, C.text, F_MED,
    UDim2.fromOffset(14, 5), UDim2.new(1, -28, 0, 18))
label(WeatherIntro, "Only changes the lighting on your screen", 10, C.dim, F_REG,
    UDim2.fromOffset(14, 26), UDim2.new(1, -28, 0, 15))
local WeatherGrid = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 76),
    LayoutOrder = nextOrder(WeatherPage),
}, WeatherPage)
new("UIGridLayout", {
    CellSize = UDim2.new(1 / 3, -6, 0, 32),
    CellPadding = UDim2.fromOffset(7, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, WeatherGrid)
local WeatherButtons = {}
local WeatherChoices = { "Default", "Day", "Sunset", "Night", "Fog", "Winter" }
local function paintWeather()
    for mode, button in pairs(WeatherButtons) do
        local selected = WeatherMode == mode
        button.BackgroundColor3 = selected and C.accent or C.cardHi
        button.TextColor3 = selected and WHITE or C.dim
    end
end
Painters._weather = paintWeather
for i, mode in ipairs(WeatherChoices) do
    local button = new("TextButton", {
        LayoutOrder = i,
        BackgroundColor3 = C.cardHi,
        Text = T(mode),
        TextColor3 = C.dim,
        TextSize = 11,
        Font = F_BOLD,
        AutoButtonColor = false,
    }, WeatherGrid)
    localize(button, mode)
    corner(button, 7)
    stroke(button, C.line, 0.55)
    WeatherButtons[mode] = button
    button.MouseButton1Click:Connect(function()
        chooseWeather(mode)
    end)
end
paintWeather()

section(WeatherPage, "CUSTOMIZE WEATHER")
local WeatherCustomStatus = makeRow(WeatherPage, 34)
WeatherCustomStatusLabel = label(WeatherCustomStatus, "Adjust the sliders to build your own look", 11, C.dim, F_MED,
    UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0))
local WeatherUiReady = false
local function updateCustomWeather()
    local ok, err = pcall(applyWeatherCustomization)
    if not ok then
        warn("[BikeUniverse] custom weather error: " .. tostring(err))
        return
    end
    if WeatherCustomStatusLabel and WeatherCustomStatusLabel.Parent then
        WeatherCustomStatusLabel.Text = T("Custom weather active")
    end
    saveConfig()
end
sliderRow(WeatherPage, "Time of day", "Set your local sky time", 0, 23,
    math.floor(WeatherCustom.Time + 0.5), "h", function(v)
        if not WeatherUiReady then return end
        WeatherCustom.Time = v
        updateCustomWeather()
    end)
sliderRow(WeatherPage, "Brightness", "Adjust local brightness", 5, 40,
    math.floor(WeatherCustom.Brightness * 10 + 0.5), "", function(v)
        if not WeatherUiReady then return end
        WeatherCustom.Brightness = v / 10
        updateCustomWeather()
    end, function(v) return string.format("%.1f", v / 10) end)
sliderRow(WeatherPage, "Fog intensity", "Adjust local fog visibility", 0, 100,
    math.floor(WeatherCustom.Fog + 0.5), "%", function(v)
        if not WeatherUiReady then return end
        WeatherCustom.Fog = v
        updateCustomWeather()
    end)
WeatherUiReady = true
if WeatherCustom.Enabled then
    updateCustomWeather()
else
    WeatherCustomStatusLabel.Text = T("Adjust the sliders to build your own look")
end

---------------------------------------------------------------------
-- Activity log + toast
---------------------------------------------------------------------
local LogEntries, logCount = {}, 0

log = function(msg, color)
    logCount = logCount + 1
    local row = new("Frame", {
        BackgroundColor3 = C.card,
        Size = UDim2.new(1, 0, 0, 26),
        LayoutOrder = -logCount,
    }, LogPage)
    corner(row, 5)
    label(row, os.date("%H:%M:%S"), 11, C.dim, F_MED, UDim2.fromOffset(10, 0), UDim2.fromOffset(56, 26))
    local dot = new("Frame", { BackgroundColor3 = color or C.accent, Position = UDim2.fromOffset(70, 10), Size = UDim2.fromOffset(6, 6) }, row)
    corner(dot, 3)
    label(row, msg, 12, C.text, F_REG, UDim2.fromOffset(86, 0), UDim2.new(1, -94, 1, 0))
    table.insert(LogEntries, row)
    if #LogEntries > 40 then
        table.remove(LogEntries, 1):Destroy()
    end
end

do
    local head = label(LogPage, "ACTIVITY", 10, GOLD, F_BOLD, nil, UDim2.new(1, 0, 0, 16))
    head.LayoutOrder = -1000000
    makeButton(LogPage, "Clear Log", C.cardHi, function()
        for _, r in ipairs(LogEntries) do r:Destroy() end
        LogEntries = {}
    end, UDim2.new(1, 0, 0, 30), -999999)
end

local Toast = new("Frame", {
    BackgroundColor3 = C.card,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, -70),
    Size = UDim2.fromOffset(300, 40),
    ZIndex = 50,
}, Gui)
corner(Toast, 8)
stroke(Toast)
local ToastBar = new("Frame", { BackgroundColor3 = C.accent, Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(9, 8), BorderSizePixel = 0, ZIndex = 51 }, Toast)
corner(ToastBar, 2)
local ToastText = label(Toast, "", 12, C.text, F_MED, UDim2.fromOffset(24, 0), UDim2.new(1, -32, 1, 0))
ToastText.ZIndex = 51
local toastToken = 0

notify = function(msg, color)
    log(msg, color)
    if not Cfg.Notifications then return end
    toastToken = toastToken + 1
    local mine = toastToken
    ToastText.Text = T(msg)
    ToastBar.BackgroundColor3 = color or C.accent
    tween(Toast, smooth, { Position = UDim2.new(0.5, 0, 0, 12) })
    task.delay(2.4, function()
        if mine == toastToken and Alive then
            tween(Toast, smooth, { Position = UDim2.new(0.5, 0, 0, -70) })
        end
    end)
end

---------------------------------------------------------------------
-- Main page
---------------------------------------------------------------------
local Hero = new("Frame", {
    BackgroundColor3 = C.card,
    ClipsDescendants = true,
    Size = UDim2.new(1, 0, 0, 74),
    LayoutOrder = nextOrder(MainPage),
}, MainPage)
corner(Hero, 8)
stroke(Hero, C.line, 0.3)

local HeroDot = new("Frame", { BackgroundColor3 = C.dim, Position = UDim2.fromOffset(16, 19), Size = UDim2.fromOffset(10, 10) }, Hero)
corner(HeroDot, 5)
local HeroStatus = label(Hero, "Waiting", 20, C.text, F_BOLD, UDim2.fromOffset(34, 8), UDim2.new(0.6, -34, 0, 30))
local HeroSub = label(Hero, "Sit on a vehicle to begin", 12, C.dim, F_REG, UDim2.fromOffset(16, 42), UDim2.new(0.6, -16, 0, 18))
label(Hero, "SPEED", 10, C.dim, F_BOLD, UDim2.new(0.6, 0, 0, 9), UDim2.new(0.4, -16, 0, 12), Enum.TextXAlignment.Right)
local SpeedVal = label(Hero, "0", 24, C.accent, F_BOLD, UDim2.new(0.6, 0, 0, 21), UDim2.new(0.4, -16, 0, 30), Enum.TextXAlignment.Right)
reg(SpeedVal, "TextColor3")
label(Hero, "studs / sec", 10, C.dim, F_REG, UDim2.new(0.6, 0, 0, 53), UDim2.new(0.4, -16, 0, 14), Enum.TextXAlignment.Right)

local StatsRow = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 50),
    LayoutOrder = nextOrder(MainPage),
}, MainPage)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, StatsRow)

local function statCard(order, title, value)
    local card = new("Frame", {
        BackgroundColor3 = C.card,
        ClipsDescendants = true,
        Size = UDim2.new(0.25, -6, 1, 0),
        LayoutOrder = order,
    }, StatsRow)
    corner(card, 7)
    stroke(card, C.line, 0.4)
    label(card, title, 10, C.dim, F_BOLD, UDim2.fromOffset(12, 7), UDim2.new(1, -20, 0, 12))
    return label(card, value, 15, C.text, F_BOLD, UDim2.fromOffset(12, 21), UDim2.new(1, -20, 0, 22))
end

local RuntimeVal = statCard(1, "RUNTIME", "00:00")
local TeleportVal = statCard(2, "TELEPORTS", "0")
local JumpVal = statCard(3, "PRESSES", "0")
local DistVal = statCard(4, "TO TARGET", "-")

local function countdownRow(page, title, initial)
    local row = makeRow(page, 42)
    label(row, title, 13, C.text, F_MED, UDim2.fromOffset(14, 5), UDim2.new(0.6, 0, 0, 18))
    local val = label(row, initial, 12, C.accent, F_BOLD, UDim2.new(0.6, 0, 0, 5), UDim2.new(0.4, -14, 0, 18), Enum.TextXAlignment.Right)
    reg(val, "TextColor3")
    local rail = new("Frame", { BackgroundColor3 = C.off, Position = UDim2.new(0, 14, 0, 31), Size = UDim2.new(1, -28, 0, 4), BorderSizePixel = 0 }, row)
    corner(rail, 2)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, rail)
    reg(fill, "BackgroundColor3")
    corner(fill, 2)
    return val, fill
end

local CountVal, CountFill = countdownRow(MainPage, "Next anti-AFK key press", "45s")

section(MainPage, "Locations")
locationRow(MainPage, 1)
locationRow(MainPage, 2)

section(MainPage, "Vehicle detection")
local VehicleDetectedValue = infoRow(MainPage, "Detected vehicle", "Not seated")

do
    local row = makeRow(MainPage, 82)
    label(row, "Teleport Mode", 13, C.text, F_MED, UDim2.fromOffset(14, 6), UDim2.new(1, -28, 0, 18))
    label(row, T("Change location only after you fall off"), 11, C.dim, F_REG, UDim2.fromOffset(14, 24), UDim2.new(1, -28, 0, 14))
    local grid = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 47),
        Size = UDim2.new(1, -28, 0, 26),
    }, row)
    new("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -5, 0, 26),
        CellPadding = UDim2.fromOffset(7, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local chips = {}
    local function paintMode()
        for m, b in pairs(chips) do
            local on = (Cfg.TeleMode == m)
            b.BackgroundColor3 = on and C.accent or C.cardHi
            b.TextColor3 = on and WHITE or C.dim
        end
    end
    Painters._mode = paintMode

    for m, name in ipairs(ModeNames) do
        local b = new("TextButton", {
            LayoutOrder = m,
            BackgroundColor3 = C.cardHi,
            Text = T(name),
            TextColor3 = C.dim,
            TextSize = 12,
            Font = F_BOLD,
            AutoButtonColor = false,
        }, grid)
        localize(b, name)
        corner(b, 6)
        chips[m] = b
        b.MouseButton1Click:Connect(function()
            setMode(m)
        end)
    end
    paintMode()
end

local SwitchVal, SwitchFill = countdownRow(MainPage, "Next location switch", "Off")

section(MainPage, "Automation")
toggleRow(MainPage, "Auto Drive", "Holds W continuously while enabled", "AutoDrive")
toggleRow(MainPage, "Auto Teleport", "Moves your vehicle to the target point", "AutoTeleport")
toggleRow(MainPage, "Anti-AFK", "One short key press every interval", "AntiAFK")
toggleRow(MainPage, "Auto Re-sit", "Sits back on your vehicle if you fall off", "AutoReseat")
toggleRow(MainPage, "Auto Rejoin", "Rejoins if disconnected (public servers only)", "AutoRejoin")

---------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------
section(SettingsPage, "Keybinds")
keybindRow(SettingsPage, "Toggle Auto Drive", "Quickly start or stop driving",
    function() return ToggleKey end, function(k)
        if k == Enum.KeyCode.Unknown or k == Enum.KeyCode.Escape or k == HideKey or k == SwapKey or k == AntiAFKKey then return false end
        ToggleKey = k; saveConfig(); return true
    end)
keybindRow(SettingsPage, "Swap Location", "Teleport to the other location",
    function() return SwapKey end, function(k)
        if k == Enum.KeyCode.Unknown or k == Enum.KeyCode.Escape or k == HideKey or k == ToggleKey or k == AntiAFKKey then return false end
        SwapKey = k; saveConfig(); return true
    end)
keybindRow(SettingsPage, "Anti-AFK Key", "Choose which key Anti-AFK presses",
    function() return AntiAFKKey end, function(k)
        if k == Enum.KeyCode.Unknown or k == Enum.KeyCode.Escape
            or k == Enum.KeyCode.W or k == Enum.KeyCode.A or k == Enum.KeyCode.S or k == Enum.KeyCode.D
            or k == ToggleKey or k == SwapKey or k == HideKey then
            return false
        end
        sendKey(false, AntiAFKKey)
        AntiAFKKey = k
        Jumping = false
        LastJump = os.clock()
        saveConfig()
        return true
    end)
keybindRow(SettingsPage, "Show / Hide Menu", "Hide the window out of the way",
    function() return HideKey end, function(k)
        if k == Enum.KeyCode.Unknown or k == Enum.KeyCode.Escape or k == ToggleKey or k == SwapKey or k == AntiAFKKey then return false end
        HideKey = k; saveConfig(); return true
    end)

section(SettingsPage, "Locations")
infoRow(SettingsPage, "Random mode", "After falling off the vehicle")

section(SettingsPage, "Anti-AFK timing")
sliderRow(SettingsPage, "Key Interval", "Seconds between key presses", 15, 120, Cfg.JumpInterval, "s", function(v)
    Cfg.JumpInterval = v
    saveConfig()
end)
sliderRow(SettingsPage, "Press Length", "How long the selected key is held (seconds)", 1, 30, math.floor(Cfg.HoldTime * 10 + 0.5), "", function(v)
    Cfg.HoldTime = v / 10
    saveConfig()
end, function(v)
    return string.format("%.1fs", v / 10)
end)

section(SettingsPage, "Behavior")
toggleRow(SettingsPage, "Teleport on respawn", "Teleport again after your character respawns", "RespawnTeleport")
toggleRow(SettingsPage, "Notifications", "Show pop-up messages in the corner", "Notifications")

section(SettingsPage, "Performance")
toggleRow(SettingsPage, "FPS Boost", "Lowest graphics quality and no shadows", "FpsBoost")
toggleRow(SettingsPage, "Save GPU mode", "Turns off 3D rendering while AFK (screen goes blank)", "Render3DOff")

section(SettingsPage, "Appearance")
toggleRow(SettingsPage, "Snowfall", "Falling snow inside the menu", "Snow")
do
    local row = makeRow(SettingsPage, 56)
    rowTitle(row, "Accent Color", "Changes highlights across the menu", 168)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(6 * 26, 22),
    }, row)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, holder)

    local rings = {}
    local function setAccent(color, index)
        C.accent = color
        AccentIndex = index
        saveConfig()
        for _, r in ipairs(AccentRefs) do
            if r[1].Parent then r[1][r[2]] = color end
        end
        for _, paint in pairs(Painters) do paint() end
        for i, ring in pairs(rings) do
            ring.Transparency = (i == index) and 0 or 1
        end
    end

    for i, sw in ipairs(Swatches) do
        local b = new("TextButton", {
            BackgroundColor3 = sw[2],
            Size = UDim2.fromOffset(22, 22),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
        }, holder)
        corner(b, 11)
        rings[i] = new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 1 }, b)
        b.MouseButton1Click:Connect(function()
            setAccent(sw[2], i)
        end)
    end
    rings[AccentIndex].Transparency = 0
end

section(SettingsPage, "Language")
do
    local function setLanguage(code)
        if code ~= "en" and not Strings[code] then return end
        Lang = code
        local keep = {}
        for _, e in ipairs(Localized) do
            if e[1].Parent then
                e[1].Text = T(e[2])
                table.insert(keep, e)
            end
        end
        Localized = keep
        saveConfig()
    end

    local row = makeRow(SettingsPage, 112)
    label(row, "Language", 13, C.text, F_MED, UDim2.fromOffset(14, 7), UDim2.new(1, -28, 0, 18))
    label(row, "Choose the menu language", 11, C.dim, F_REG, UDim2.fromOffset(14, 24), UDim2.new(1, -28, 0, 14))
    local grid = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 50),
        Size = UDim2.new(1, -28, 0, 56),
    }, row)
    new("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -5, 0, 25),
        CellPadding = UDim2.fromOffset(7, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local chips = {}
    local function paintChips()
        for code, b in pairs(chips) do
            local on = (code == Lang)
            b.BackgroundColor3 = on and C.accent or C.cardHi
            b.TextColor3 = on and WHITE or C.dim
        end
    end
    Painters["_language"] = paintChips

    for i, l in ipairs(Languages) do
        local b = new("TextButton", {
            LayoutOrder = i,
            BackgroundColor3 = C.cardHi,
            Text = l[2],
            TextColor3 = C.dim,
            TextSize = 12,
            Font = F_BOLD,
            AutoButtonColor = false,
        }, grid)
        corner(b, 6)
        chips[l[1]] = b
        b.MouseButton1Click:Connect(function()
            setLanguage(l[1])
            paintChips()
        end)
    end
    paintChips()
end

section(SettingsPage, "Script")

---------------------------------------------------------------------
-- Info page
---------------------------------------------------------------------
section(InfoPage, "About")
infoRow(InfoPage, "Script", "Bike Universe")
infoRow(InfoPage, "Developer", "NostraTeam")
section(InfoPage, "How it works")
infoRow(InfoPage, "Dual Teleport", "Switches between 2 spots")
infoRow(InfoPage, "Auto Drive", "Holds W non-stop")
infoRow(InfoPage, "Auto Re-sit", "Sits back on vehicle")
infoRow(InfoPage, "Auto Rejoin", "Reconnects if kicked")
local AfkInfo = infoRow(InfoPage, "Anti-AFK", "")
local AfkKeyInfo = infoRow(InfoPage, "Anti-AFK Key", AntiAFKKey.Name)
section(InfoPage, "Session")
local TopSpeedInfo = infoRow(InfoPage, "Top speed", "0 studs/s")
local VehicleChangesInfo = infoRow(InfoPage, "Vehicle changes", "0")
section(InfoPage, "Hotkeys")
local DriveKeyInfo = infoRow(InfoPage, "Auto Drive", ToggleKey.Name)
local SwapKeyInfo = infoRow(InfoPage, "Swap Location", SwapKey.Name)
local HideKeyInfo = infoRow(InfoPage, "Show / Hide", HideKey.Name)

buttonPair(MainPage,
    { "Teleport Now", "accent", function()
        goTo(activeIdx())
    end },
    { "Reset Stats", C.cardHi, function()
        TeleportCount, JumpCount, TopSpeed, VehicleChangeCount = 0, 0, 0, 0
        StartTime = os.clock()
        notify("Session stats reset", C.dim)
    end })

local PulseTween
local function Shutdown()
    if not Alive then return end
    Alive = false
    if SharedEnv.__BikeUniverseCleanup == Shutdown then
        SharedEnv.__BikeUniverseCleanup = nil
    end
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    if PulseTween then pcall(function() PulseTween:Cancel() end) end
    pcall(applyWeather, "Default")
    applyBoost(false)
    apply3D(false)
    releaseKeys()
    cleanupIntro()
    Gui:Destroy()
end

SharedEnv.__BikeUniverseCleanup = Shutdown
buttonRow(SettingsPage, "Unload Script", C.bad, Shutdown)
CloseBtn.MouseButton1Click:Connect(Shutdown)

-- window drag
local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Root.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
track(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        local ox, oy = startPos.X.Offset + d.X, startPos.Y.Offset + d.Y
        local vp = Gui.AbsoluteSize
        local s = RootScale.Scale
        local halfW = WIN_W * s / 2
        ox = math.clamp(ox, -(vp.X / 2) - halfW + 70, (vp.X / 2) + halfW - 70)
        oy = math.clamp(oy, -(vp.Y / 2), (vp.Y / 2) - TOP_H * s)
        Root.Position = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
    end
end))

MinBtn.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    SnowLayer.Visible = Cfg.Snow and not Minimized
    if Minimized then
        Body.Visible = false
        tween(Root, smooth, { Size = UDim2.fromOffset(WIN_W, TOP_H) })
    else
        Body.Visible = true
        tween(Root, smooth, { Size = UDim2.fromOffset(WIN_W, WIN_H) })
    end
    MinBtn.Text = Minimized and "+" or "–"
end)

-- floating launcher button
local Launcher
do
    Launcher = new("TextButton", {
        Name = "Launcher",
        BackgroundColor3 = PINE,
        Position = UDim2.new(0, 12, 0.5, -20),
        Size = UDim2.fromOffset(40, 40),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
    }, Gui)
    local btn = Launcher
    corner(btn, 20)
    reg(stroke(btn, C.accent, 0), "Color")
    bikeIcon(btn, 24)
    santaHat(btn, 18, 1, 0.82, 3)

    local down, moved, startInput, startPos2 = false, false, nil, nil
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            down, moved = true, false
            startInput = input.Position
            startPos2 = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if down and not moved and IntroDone then
                        Root.Visible = not Root.Visible
                    end
                    down = false
                end
            end)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if down and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then
                local vp = Gui.AbsoluteSize
                local x = math.clamp(startPos2.X.Offset + d.X, 0, vp.X - 40)
                local y = math.clamp(startPos2.Y.Offset + d.Y, -vp.Y / 2, vp.Y / 2 - 40)
                btn.Position = UDim2.new(0, x, 0.5, y)
            end
        end
    end))
end

-- live UI refresh (protected: an error here can never stop the engine)
local function refreshUI()
    local seat = getSeat()
    local text, color, sub
    if Rejoining then
        text, color, sub = "Rejoining", C.warn, "Connection lost - joining a new server"
    elseif not Cfg.AutoDrive then
        text, color, sub = "Paused", C.warn, "Auto Drive is turned off"
    elseif seat then
        text, color = "Driving", C.good
        sub = T("Vehicle: ") .. (seat.Parent and seat.Parent.Name or seat.Name)
    else
        text, color, sub = "Waiting", C.dim, "Sit on a vehicle to begin"
    end
    text = T(text)
    if not seat or Rejoining or not Cfg.AutoDrive then sub = T(sub) end
    setProp(HeroStatus, "Text", text)
    setProp(HeroSub, "Text", sub)
    setProp(HeroDot, "BackgroundColor3", color)
    setProp(PillDot, "BackgroundColor3", color)

    local act = activeIdx()
    if seat then
        local speed = math.floor(seat.AssemblyLinearVelocity.Magnitude + 0.5)
        if speed > TopSpeed then TopSpeed = speed end
        setProp(SpeedVal, "Text", tostring(speed))
        local target = Locs[act] and Locs[act].pos
        setProp(DistVal, "Text", target and (math.floor((seat.Position - target).Magnitude + 0.5) .. " st") or "-")
    else
        setProp(SpeedVal, "Text", "0")
        setProp(DistVal, "Text", "-")
    end

    for i = 1, 2 do
        setProp(LocTitles[i], "TextColor3", (act == i) and C.accent or C.text)
    end

    local t = math.floor(os.clock() - StartTime)
    setProp(RuntimeVal, "Text", string.format("%02d:%02d", math.floor(t / 60), t % 60))
    setProp(TeleportVal, "Text", tostring(TeleportCount))
    setProp(JumpVal, "Text", tostring(JumpCount))
    setProp(TopSpeedInfo, "Text", string.format(T("%d studs/s"), TopSpeed))
    setProp(VehicleChangesInfo, "Text", tostring(VehicleChangeCount))
    setProp(AfkInfo, "Text", string.format(T("%s every %ds (%.1fs)"), AntiAFKKey.Name, Cfg.JumpInterval, Cfg.HoldTime))
    setProp(AfkKeyInfo, "Text", AntiAFKKey.Name)
    setProp(DriveKeyInfo, "Text", ToggleKey.Name)
    setProp(VehicleDetectedValue, "Text", seat and CurrentVehicleName or T("Not seated"))
    setProp(SwapKeyInfo, "Text", SwapKey.Name)
    setProp(HideKeyInfo, "Text", HideKey.Name)

    if not Cfg.AntiAFK then
        setProp(CountVal, "Text", T("Off"))
        CountFill.Size = UDim2.new(0, 0, 1, 0)
    elseif Jumping then
        setProp(CountVal, "Text", T("Pressing..."))
        CountFill.Size = UDim2.new(1, 0, 1, 0)
    else
        local left = math.max(0, Cfg.JumpInterval - (os.clock() - LastJump))
        if seat and left <= 0 then
            setProp(CountVal, "Text", T("Protected while riding"))
        else
            setProp(CountVal, "Text", math.ceil(left) .. "s")
        end
        CountFill.Size = UDim2.new(math.clamp(1 - left / Cfg.JumpInterval, 0, 1), 0, 1, 0)
    end

    if Cfg.TeleMode ~= 3 then
        setProp(SwitchVal, "Text", T("Off"))
        SwitchFill.Size = UDim2.new(0, 0, 1, 0)
    else
        setProp(SwitchVal, "Text", T(PendingRandomSwitch and "Waiting for re-seat" or "After fall"))
        SwitchFill.Size = UDim2.new(PendingRandomSwitch and 0.65 or 0.22, 0, 1, 0)
    end
end

do
    local fpsAcc, frames, uiAcc, bulbAcc, phase = 0, 0, 0, 0, 0
    track(RunService.Heartbeat:Connect(function(dt)
        fpsAcc = fpsAcc + dt
        frames = frames + 1
        if fpsAcc >= 0.5 then
            setProp(FpsLabel, "Text", math.floor(frames / fpsAcc + 0.5) .. " FPS")
            fpsAcc, frames = 0, 0
        end

        if Root.Visible then
            bulbAcc = bulbAcc + dt
            if bulbAcc >= 0.5 then
                bulbAcc = 0
                phase = 1 - phase
                for i, b in ipairs(Bulbs) do
                    b.BackgroundTransparency = ((i + phase) % 2 == 0) and 0 or 0.6
                end
            end

            if not Minimized then
                if Cfg.Snow then SnowStep(dt) end

                uiAcc = uiAcc + dt
                if uiAcc >= 0.1 then
                    uiAcc = 0
                    local ok, err = pcall(refreshUI)
                    if not ok then warn("[BikeUniverse] UI refresh: " .. tostring(err)) end
                end
            end
        end
    end))
end

PulseTween = TweenService:Create(HeroDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.65 })
PulseTween:Play()

-- hotkeys
track(UIS.InputBegan:Connect(function(input, processed)
    if Listening then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local l = Listening
            if input.KeyCode == Enum.KeyCode.Escape then
                Listening = nil
                l.btn.Text = l.get().Name
                l.btn.TextColor3 = C.accent
                return
            end

            local applied = l.set(input.KeyCode)
            if applied == false then
                notify(T("This key is already assigned to another control"), C.warn)
                l.btn.Text = T("Press a key...")
                l.btn.TextColor3 = C.dim
                return
            end

            Listening = nil
            notify(string.format(T("Key set to %s"), input.KeyCode.Name), C.good)
            l.btn.Text = l.get().Name
            l.btn.TextColor3 = C.accent
        end
        return
    end

    if not IntroDone then return end
    if processed then return end

    if input.KeyCode == ToggleKey then
        setFlag("AutoDrive", not Cfg.AutoDrive)
    elseif input.KeyCode == SwapKey then
        goTo(activeIdx() == 1 and 2 or 1)
    elseif input.KeyCode == HideKey then
        if IntroDone then Root.Visible = not Root.Visible end
    end
end))

---------------------------------------------------------------------
-- INTRO: frosted blur + snow -> NOSTRA TEAM -> key system + Discord -> menu
---------------------------------------------------------------------
local function playIntro()
    local finalPos = Root.Position
    Root.Visible = false

    IntroGui = new("ScreenGui", {
        Name = "NostraIntro",
        ResetOnSpawn = false,
        DisplayOrder = 1000,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    -- real blur of the game behind everything
    IntroBlur = new("BlurEffect", { Name = "NostraBlur", Size = 0 }, Lighting)

    -- everything lives in one CanvasGroup so it can fade out as a whole
    local group = new("CanvasGroup", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        GroupTransparency = 0,
    }, IntroGui)

    -- frosted veil (hides the background completely)
    local veil = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    }, group)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 28, 30)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 18, 26)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 12, 20)),
        }),
        Rotation = 60,
    }, veil)

    -- soft colored haze blobs (red / green) for a festive glow
    local function haze(color, ax, ay, px, py)
        local f = new("Frame", {
            BackgroundColor3 = color,
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(ax, ay),
            Position = UDim2.fromScale(px, py),
            Size = UDim2.fromOffset(520, 520),
            ZIndex = 2,
        }, group)
        corner(f, 260)
        return f
    end
    haze(Color3.fromRGB(214, 40, 57), 0, 0, -0.05, -0.1)
    haze(Color3.fromRGB(46, 160, 98), 1, 1, 1.05, 1.1)

    -- snow over the whole screen
    local _, snowStep = makeSnow(group, 18, 3, 6)
    IntroSnowConn = track(RunService.Heartbeat:Connect(function(dt)
        snowStep(dt)
    end))

    -- ===== phase 1: NOSTRA TEAM =====
    local title = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -14),
        Size = UDim2.new(0.92, 0, 0, 110),
        Text = "NOSTRA TEAM",
        Font = F_BLACK,
        TextScaled = true,
        TextColor3 = WHITE,
        TextTransparency = 1,
        ZIndex = 10,
    }, group)
    new("UITextSizeConstraint", { MaxTextSize = 96, MinTextSize = 20 }, title)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 232, 190)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }),
    }, title)
    local titleStroke = new("UIStroke", {
        Color = Color3.fromRGB(214, 40, 57),
        Thickness = 3,
        Transparency = 1,
    }, title)

    local subtitle = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 52),
        Size = UDim2.new(0.8, 0, 0, 26),
        Text = "Bike Universe Script",
        Font = F_MED,
        TextSize = 20,
        TextColor3 = GOLD,
        TextTransparency = 1,
        ZIndex = 10,
    }, group)

    local fadeIn = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    tween(veil, fadeIn, { BackgroundTransparency = 0.08 })
    tween(IntroBlur, fadeIn, { Size = 14 })
    tween(title, fadeIn, { TextTransparency = 0 })
    tween(titleStroke, fadeIn, { Transparency = 0.25 })
    tween(subtitle, fadeIn, { TextTransparency = 0 })

    task.wait(1 + 3) -- fade-in, then 3 seconds on screen
    if not Alive then return end

    -- slowly fade the center text out
    local slow = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    tween(title, slow, { TextTransparency = 1 })
    tween(titleStroke, slow, { Transparency = 1 })
    tween(subtitle, slow, { TextTransparency = 1 })
    task.wait(1.8)
    if not Alive then return end
    title:Destroy()
    subtitle:Destroy()

    -- ===== phase 2: NostraTeam winter access panel =====
    -- Keep the intro's existing full-screen winter backdrop; the panel itself is one unified surface.
    RunService.RenderStepped:Wait()
    local vp = IntroGui.AbsoluteSize
    if vp.X < 1 or vp.Y < 1 then
        local camera = workspace.CurrentCamera
        vp = camera and camera.ViewportSize or Vector2.new(900, 700)
    end

    local panelW, panelH = 430, 386
    local panelScale = math.clamp(math.min((vp.X - 28) / panelW, (vp.Y - 28) / panelH), 0.68, 1)
    holder = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(15, 24, 21),
        BackgroundTransparency = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -470),
        Size = UDim2.fromOffset(panelW, panelH),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, group)
    new("UIScale", { Scale = panelScale }, holder)
    corner(holder, 18)
    stroke(holder, Color3.fromRGB(125, 151, 119), 0.18)
    -- One restrained top accent keeps the access card consistent with the menu.
    local trim = new("Frame", {
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 3),
        ZIndex = 11,
    }, holder)
    corner(trim, 3)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(26, 17),
        Size = UDim2.new(1, -52, 0, 15),
        Text = T("WINTER ACCESS"),
        Font = F_BOLD,
        TextSize = 10,
        TextColor3 = GOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, holder)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(26, 49),
        Size = UDim2.new(1, -52, 0, 29),
        Text = T("Welcome to Bike Universe"),
        Font = F_BLACK,
        TextSize = 21,
        TextColor3 = WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 12,
    }, holder)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 80),
        Size = UDim2.new(1, -54, 0, 18),
        Text = T("Enter your access key to continue"),
        Font = F_REG,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(171, 190, 178),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, holder)

    local dividerTop = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(91, 119, 100),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(26, 112),
        Size = UDim2.new(1, -52, 0, 1),
        ZIndex = 11,
    }, holder)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(28, 127),
        Size = UDim2.new(1, -56, 0, 16),
        Text = T("ACCESS KEY"),
        Font = F_BOLD,
        TextSize = 10,
        TextColor3 = GOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, holder)

    local keyBox = new("TextBox", {
        BackgroundColor3 = Color3.fromRGB(13, 25, 21),
        BackgroundTransparency = 0,
        Position = UDim2.fromOffset(26, 150),
        Size = UDim2.new(1, -52, 0, 48),
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = T("Paste or type your key"),
        PlaceholderColor3 = Color3.fromRGB(117, 143, 130),
        TextColor3 = Color3.fromRGB(246, 247, 241),
        TextSize = 14,
        Font = F_MED,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        MultiLine = false,
        TextEditable = true,
        ZIndex = 13,
    }, holder)
    corner(keyBox, 10)
    local keyBoxStroke = stroke(keyBox, Color3.fromRGB(83, 111, 94), 0.08)
    local keyAccepted = false
    local keyInvalid = false
    local verifying = false
    local status = nil

    keyBox.TextSize = 14
    keyBox.TextWrapped = false
    keyBox.TextScaled = false
    keyBox.TextYAlignment = Enum.TextYAlignment.Center
    keyBox.TextXAlignment = Enum.TextXAlignment.Left
    keyBox.PlaceholderText = T("Paste or type your key")
    keyBox.PlaceholderColor3 = Color3.fromRGB(139, 155, 146)
    keyBox.TextColor3 = Color3.fromRGB(245, 247, 242)
    padding(keyBox, 0, 14, 0, 14)

    keyBox.Focused:Connect(function()
        if not keyAccepted then
            tween(keyBoxStroke, fast, { Color = GOLD, Transparency = 0 })
        end
    end)
    keyBox.FocusLost:Connect(function()
        if not keyAccepted and status and status.Text == "" then
            tween(keyBoxStroke, fast, { Color = Color3.fromRGB(76, 108, 88), Transparency = 0.12 })
        end
    end)

    local verifyBtn = new("TextButton", {
        BackgroundColor3 = Color3.fromRGB(174, 43, 55),
        Position = UDim2.fromOffset(26, 214),
        Size = UDim2.new(1, -52, 0, 42),
        BorderSizePixel = 0,
        Text = T("VERIFY & CONTINUE"),
        TextColor3 = WHITE,
        TextSize = 11,
        TextScaled = false,
        TextWrapped = false,
        Font = F_BLACK,
        AutoButtonColor = false,
        ZIndex = 13,
    }, holder)
    corner(verifyBtn, 10)
    local verifyStroke = stroke(verifyBtn, Color3.fromRGB(255, 154, 144), 0.58)
    status = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(26, 263),
        Size = UDim2.new(1, -52, 0, 19),
        Text = "",
        Font = F_MED,
        TextSize = 11,
        TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 12,
    }, holder)

    new("Frame", {
        BackgroundColor3 = Color3.fromRGB(91, 119, 100),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(26, 294),
        Size = UDim2.new(1, -52, 0, 1),
        ZIndex = 11,
    }, holder)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 307),
        Size = UDim2.new(1, -54, 0, 15),
        Text = T("Need help getting access?"),
        Font = F_MED,
        TextSize = 10,
        TextColor3 = GOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, holder)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 327),
        Size = UDim2.new(1, -142, 0, 18),
        Text = T("Join the NostraTeam community"),
        Font = F_BOLD,
        TextSize = 12,
        TextColor3 = WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 12,
    }, holder)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 347),
        Size = UDim2.new(1, -142, 0, 15),
        Text = "discord.gg/s6HmYXrjX",
        Font = F_REG,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(177, 190, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 12,
    }, holder)

    local copyBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -24, 0, 340),
        Size = UDim2.fromOffset(105, 34),
        BackgroundColor3 = Color3.fromRGB(42, 62, 54),
        Text = T("COPY INVITE"),
        Font = F_BOLD,
        TextSize = 10,
        TextColor3 = WHITE,
        AutoButtonColor = false,
        ZIndex = 13,
    }, holder)
    corner(copyBtn, 9)
    stroke(copyBtn, Color3.fromRGB(103, 137, 111), 0.28)
    copyBtn.MouseButton1Click:Connect(function()
        local copied = false
        pcall(function()
            local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
            if fn then
                fn(DISCORD_LINK)
                copied = true
            end
        end)
        if copied then
            copyBtn.Text = "✓ " .. T("Copied")
            copyBtn.TextColor3 = Color3.fromRGB(146, 226, 171)
        else
            copyBtn.Text = T("Copy")
            status.Text = "Clipboard copy is not supported by this executor."
            status.TextColor3 = C.warn
        end
        task.delay(1.6, function()
            if copyBtn.Parent then
                copyBtn.Text = T("COPY INVITE")
                copyBtn.TextColor3 = WHITE
            end
        end)
    end)

    local function normalizePastedKey(value)
        value = tostring(value or "")
        -- Clipboard sources sometimes append CR/LF, zero-width spaces or a BOM.
        value = value:gsub("\239\187\191", "")
        value = value:gsub("\226\128\139", "")
        value = value:gsub("[%c%s]", "")
        return value
    end
    keyBox:GetPropertyChangedSignal("Text"):Connect(function()
        if keyAccepted or verifying then return end
        status.Text = ""
        status.TextColor3 = C.dim
        keyInvalid = false
        keyBoxStroke.Color = Color3.fromRGB(76, 108, 88)
        verifyBtn.Text = T("VERIFY & CONTINUE")
        verifyBtn.BackgroundColor3 = C.accent
        verifyStroke.Color = Color3.fromRGB(255, 154, 144)
    end)
    local function verifyKey()
        if verifying or keyAccepted then return end
        verifying = true
        local entered = normalizePastedKey(keyBox.Text)
        if entered == SCRIPT_KEY then
            keyBox.Text = entered
            keyInvalid = false
            keyAccepted = true
            status.Text = "✓ " .. T("Key accepted")
            status.TextColor3 = C.good
            keyBoxStroke.Color = C.good
            keyBox.TextEditable = false
            verifyBtn.Text = "✓ " .. T("Key accepted")
            verifyBtn.BackgroundColor3 = C.good
            verifyStroke.Color = Color3.fromRGB(146, 226, 171)
        else
            -- Keep the user's text visible, but remove invisible pasted control
            -- characters so they can see exactly what is being checked.
            if #entered <= 96 then keyBox.Text = entered end
            keyInvalid = true
            status.Text = (#entered == 0) and T("Enter your key") or ("✕ " .. T("Invalid key"))
            status.TextColor3 = C.bad
            keyBoxStroke.Color = C.bad
            verifyBtn.Text = T("TRY AGAIN")
            verifyBtn.BackgroundColor3 = C.bad
        end
        verifying = false
    end
    verifyBtn.MouseButton1Click:Connect(verifyKey)
    keyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then verifyKey() end
    end)
    verifyBtn.MouseEnter:Connect(function()
        if not keyAccepted and not keyInvalid then
            tween(verifyBtn, fast, { BackgroundColor3 = Color3.fromRGB(222, 67, 78) })
        end
    end)
    verifyBtn.MouseLeave:Connect(function()
        if not keyAccepted then
            tween(verifyBtn, fast, { BackgroundColor3 = keyInvalid and C.bad or C.accent })
        end
    end)

    -- Slide the complete panel into the center; no pre-filled or auto-typed key.
    tween(holder, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.fromScale(0.5, 0.5),
    })
    while Alive and not keyAccepted do
        task.wait(0.1)
    end
    if not Alive then return end
    task.wait(0.65)

    -- ===== phase 3: everything slowly fades away in 3 seconds =====
    local out = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    tween(group, out, { GroupTransparency = 1 })
    tween(IntroBlur, out, { Size = 0 })
    task.wait(3.05)

    cleanupIntro()
    if not Alive then return end

    -- ===== phase 4: the script appears =====
    IntroDone = true
    Launcher.Visible = true
    Root.Position = finalPos + UDim2.fromOffset(0, 28)
    Root.Visible = true
    tween(Root, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = finalPos })
    notify("Bike Universe loaded", C.accent)
end

selectTab("Main")
paintWeather()
if Cfg.FpsBoost then applyBoost(true) end
ConfigReady = true
task.spawn(function()
    local ok, err = pcall(playIntro)
    if not ok then
        warn("[BikeUniverse] intro: " .. tostring(err))
    end
    -- If the access screen fails, keep the menu locked instead of bypassing the key.
    if Alive and not IntroDone then
        cleanupIntro()
        Launcher.Visible = false
        Root.Visible = false
        warn("[BikeUniverse] Access screen could not start. Re-run the script.")
    end
end)

end -- buildUI

buildUI()
