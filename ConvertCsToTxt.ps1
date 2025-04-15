<#
.SYNOPSIS
Konvertiert alle .cs- und .xaml-Dateien im Verzeichnis des Skripts (einschließlich Unterordnern)
in .txt-Dateien und speichert sie in einem neuen 'txt'-Unterordner.
Der Zieldateiname enthält einen Hinweis auf den ursprünglichen Dateityp (_cs.txt oder _xaml.txt).
Überspringt die Konvertierung, wenn die Zieldatei bereits existiert.
Hält das Fenster am Ende 5 Sekunden offen.

.DESCRIPTION
Das Skript verwendet automatisch das Verzeichnis, in dem es ausgeführt wird, als Quellordner.
Es sucht dann rekursiv nach allen Dateien mit den Endungen .cs ODER .xaml in diesem Verzeichnis und dessen Unterordnern.
Für jede gefundene Datei wird der Zieldateiname generiert: 'ursprünglicherName_cs.txt' für .cs-Dateien
und 'ursprünglicherName_xaml.txt' für .xaml-Dateien.
Es prüft, ob im 'txt'-Zielordner bereits eine Datei mit diesem spezifischen Namen existiert.
Wenn ja, wird diese Datei übersprungen und eine Warnung ausgegeben.
Wenn nein, wird deren Inhalt gelesen und in die neue .txt-Datei geschrieben.
Alle neu erstellten .txt-Dateien werden im automatisch erstellten
Unterordner namens 'txt' im Skriptverzeichnis abgelegt.
Nach Abschluss der Operation wartet das Skript 5 Sekunden, bevor es endet.
Diese Version benötigt KEINE Konfigurationsdatei (config.txt/config.json).

.EXAMPLE
# Speichern Sie das Skript als ConvertCsXamlToTxt_WithTypeSuffix.ps1 in dem Ordner,
# den Sie durchsuchen möchten (z.B. C:\Users\xST4R\Desktop\tmp cs xaml),
# und führen Sie es dann einfach ohne Parameter aus:
.\ConvertCsXamlToTxt_WithTypeSuffix.ps1
# Ergebnis im 'txt'-Ordner: Beispiel.cs -> Beispiel_cs.txt, Fenster.xaml -> Fenster_xaml.txt

.NOTES
Autor: xST4R
Version: 1.2
Datum: 2025-04-06
Stellt sicher, dass der 'txt'-Ordner im Skriptverzeichnis erstellt wird.
Existierende .txt-Dateien im Zielordner werden NICHT überschrieben, sondern übersprungen.
Verwendet UTF-8 POM Kodierung für die erstellten Textdateien.
Konvertiert .cs und .xaml Dateien.
Zieldateinamen enthalten jetzt _cs oder _xaml Suffix.
#>

# Das Skript benötigt keine Parameter und keine Konfigurationsdatei.
param()

# Das Verzeichnis ermitteln, in dem das Skript ausgeführt wird
$SourceFolder = $PSScriptRoot
Write-Host "Verwende Skriptverzeichnis als Quellordner: $SourceFolder"

# Pfad für den Ausgabeordner definieren (Unterordner 'txt' im Skriptverzeichnis)
$OutputFolder = Join-Path -Path $SourceFolder -ChildPath "txt"

# Ausgabeordner erstellen, falls er nicht existiert
Write-Host "Erstelle Ausgabeordner (falls nicht vorhanden): $OutputFolder"
try {
    New-Item -Path $OutputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Error "Fehler beim Erstellen des Ausgabeordners '$OutputFolder'. Überprüfen Sie die Berechtigungen. Details: $($_.Exception.Message)"
    Write-Host "Drücken Sie Enter zum Beenden..."
    Read-Host
    return # Skript beenden
}

# Suche nach .cs UND .xaml Dateien
Write-Host "Suche nach .cs und .xaml Dateien in '$SourceFolder' und Unterordnern..."
try {
    # Schließe den 'txt'-Ausgabeordner von der Suche aus
    $sourceFiles = Get-ChildItem -Path $SourceFolder -Include *.cs, *.xaml -Recurse -File -Exclude $OutputFolder -ErrorAction Stop
}
catch {
    Write-Error "Fehler beim Suchen nach .cs/.xaml-Dateien in '$SourceFolder'. Details: $($_.Exception.Message)"
    Write-Host "Drücken Sie Enter zum Beenden..."
    Read-Host
    return # Skript beenden
}


if ($sourceFiles.Count -eq 0) {
    Write-Host "Keine .cs- oder .xaml-Dateien im Skriptverzeichnis '$SourceFolder' oder dessen Unterordnern gefunden (Ausgabeordner '$OutputFolder' ignoriert)."
    Write-Host "Das Fenster wird in 5 Sekunden geschlossen..."
    Start-Sleep -Seconds 5
    return
}

Write-Host "$($sourceFiles.Count) .cs/.xaml-Datei(en) gefunden. Beginne mit der Konvertierung..."

# Zähler initialisieren
$convertedCount = 0
$skippedCount = 0
$errorFiles = [System.Collections.Generic.List[string]]::new()

# Jede gefundene Datei durchgehen (jetzt .cs oder .xaml)
foreach ($sourceFile in $sourceFiles) {

    # --- MODIFIZIERT: Zieldateiname mit Suffix erstellen ---
    $baseName = $sourceFile.BaseName
    $extensionSuffix = "" # Standardmäßig leer

    # Suffix basierend auf der ursprünglichen Dateiendung bestimmen
    if ($sourceFile.Extension -eq '.cs') {
        $extensionSuffix = "_cs"
    }
    elseif ($sourceFile.Extension -eq '.xaml') {
        $extensionSuffix = "_xaml"
    }
    # Anmerkung: Wenn zukünftig weitere Dateitypen unterstützt werden sollen,
    # muss diese if/elseif-Struktur erweitert werden.

    # Neuen Zieldateinamen zusammensetzen
    $txtFileName = "$($baseName)$($extensionSuffix).txt"
    $txtFilePath = Join-Path -Path $OutputFolder -ChildPath $txtFileName
    # --- Ende der Modifikation ---

    # Sicherstellen, dass die Quelldatei nicht das Skript selbst ist
    if ($sourceFile.FullName -eq $MyInvocation.MyCommand.Path) {
        Write-Warning "Überspringe das Skript selbst: $($sourceFile.FullName)"
        continue # Nächste Datei
    }

    # Prüfung, ob Zieldatei bereits existiert
    if (Test-Path -Path $txtFilePath -PathType Leaf) {
        Write-Warning "Zieldatei existiert bereits und wird übersprungen: $txtFilePath"
        $skippedCount++
        continue # Verarbeite die nächste Datei
    }

    # Wenn die Datei nicht existiert, wird hier weitergemacht:
    Write-Host "Verarbeite: $($sourceFile.FullName) -> $($txtFilePath)"

    try {
        # Inhalt lesen
        $content = Get-Content -Path $sourceFile.FullName -Raw -ErrorAction Stop
        # Inhalt schreiben
        Set-Content -Path $txtFilePath -Value $content -Encoding UTF8 -Force -ErrorAction Stop
        $convertedCount++
    }
    catch {
        # Fehler bei Lese-/Schreibvorgang
        Write-Error "Fehler beim Verarbeiten der Datei $($sourceFile.FullName): $($_.Exception.Message)"
        $errorFiles.Add($sourceFile.FullName)
    }
}

Write-Host "-----------------------------------------------------"
Write-Host "Konvertierung abgeschlossen."
Write-Host "$convertedCount Datei(en) erfolgreich nach '$OutputFolder' konvertiert."
if ($skippedCount -gt 0) {
    Write-Host "$skippedCount Datei(en) übersprungen, da sie im Zielordner bereits existierten."
}
if ($errorFiles.Count -gt 0) {
    Write-Warning "$($errorFiles.Count) Datei(en) konnten nicht verarbeitet werden (Lese-/Schreibfehler):"
    foreach ($errFile in $errorFiles) {
        Write-Warning "- $errFile"
    }
}
Write-Host "-----------------------------------------------------"

# Nachricht vor dem Warten
Write-Host "Das Fenster wird in 5 Sekunden geschlossen..."

# 5 Sekunden warten
Start-Sleep -Seconds 5
