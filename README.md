# Craft Reminder – Programmierbeispiel

Dieses Projekt wurde im Rahmen eines Bewerbungsprozesses umgesetzt.

Es handelt sich um eine einfache Webanwendung zur Verwaltung von Kalendererinnerungen, realisiert mit **Craft CMS 5**.

---

## 🎯 Ziel der Aufgabe

Implementierung einer Anwendung zur Verwaltung von Erinnerungen mit:

- CRUD-Funktionalität (Create, Read, Update, Delete)
- Filtermöglichkeiten
- Sortierfunktion

---

## 📌 Projektübersicht

Die Anwendung bietet folgende Funktionen:

- ✅ Erinnerungen erstellen  
- ✅ Erinnerungen bearbeiten  
- ✅ Erinnerungen löschen  
- ✅ Filter: nur zukünftige Termine  
- ✅ Filter: nur offene (nicht erledigte) Einträge  
- ✅ Sortierung nach Datum (ASC / DESC)  

Die Benutzeroberfläche wurde mit Tailwind CSS umgesetzt.

---

## 🛠 Technischer Stack

- **Craft CMS 5**
- **PHP 8.2+**
- **MySQL / MariaDB**
- **Composer**
- **Tailwind CSS**
- **DDEV** (für lokale Entwicklung)

---

## 🚀 Installation

### Voraussetzungen

- PHP 8.2 oder höher
- MySQL oder MariaDB
- Composer
- Optional: DDEV (empfohlen)

---

## 🔧 Installation mit DDEV (empfohlen)

```bash
git clone https://github.com/Stoyanovski1/craft-reminder.git
cd craft-reminder
ddev start
ddev composer install
ddev craft install