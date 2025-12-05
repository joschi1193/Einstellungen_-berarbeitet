import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fines_manager/dialogs/edit_transaction_dialog.dart';
import 'package:fines_manager/dialogs/expense_dialog.dart';
import 'package:fines_manager/main.dart';
import 'package:fines_manager/models/expense.dart';
import 'package:fines_manager/models/transaction.dart';
import 'package:fines_manager/screens/expenses_screen.dart';
import 'package:fines_manager/screens/past_round_screen.dart';
import 'package:fines_manager/utils/date_utils.dart';
import 'package:fines_manager/widgets/location_notes_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/diagnostics.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_data_provider.dart';
import '../models/predefined_fine.dart';
import '../models/player.dart';
import '../dialogs/edit_name_dialog.dart';
import '../dialogs/edit_fine_dialog.dart';
import '../dialogs/password_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final int initialTabIndex;
  const SettingsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final bool _isLoading = false;
  late int _selectedIndex;
  bool _isSidebarOpen = true;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
  }

  Future<void> _resetData(BuildContext context) async {
    // Zuerst Passwortabfrage
    final passwordConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );

    // Nur fortfahren wenn das Passwort korrekt war
    if (passwordConfirmed == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daten zurücksetzen'),
          content: const Text(
            'Möchtest du wirklich alle Strafen, Anwesenheiten und Spenden zurücksetzen? '
            'Die Namen und vordefinierten Strafen bleiben erhalten.\n\n'
            'Dies betrifft auch die Strafenliste, Historie und Statistik.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Zurücksetzen'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // SharedPreferences Instanz holen
        final prefs = await SharedPreferences.getInstance();
        // Anwesenheitssperre entfernen
        await prefs.remove('attendance_lock_expiry');

        final appData = Provider.of<AppDataProvider>(context, listen: false);
        await appData.resetData();

        if (!mounted) return;

        // Erzwinge einen kompletten Neuaufbau der App
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Daten wurden zurückgesetzt'),
          ),
        );
      }
    }
  }

  // Modifiziere die build Methode, um den IconButton anzupassen
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () {
            setState(() {
              _isSidebarOpen = !_isSidebarOpen;
            });
          },
        ),
      ),
      body: Stack(
        children: [
          // Gesture detector für die gesamte Fläche
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (details.delta.dx > 0 && !_isSidebarOpen) {
                setState(() {
                  _isSidebarOpen = true;
                });
              } else if (details.delta.dx < 0 && _isSidebarOpen) {
                setState(() {
                  _isSidebarOpen = false;
                });
              }
            },
            // Transparente Box für die gesamte Fläche
            child: Container(
              color: Colors.transparent,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
          // Hauptinhalt
          AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(left: _isSidebarOpen ? 200 : 0),
            child: _selectedIndex == -1
                ? const Center(
                    child: Text('Bitte wähle eine Option aus.'),
                  )
                : Stack(
                    children: [
                      _buildContent(),
                      if (_isLoading)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
          ),
          // Sidebar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            left: _isSidebarOpen ? 0 : -200,
            top: 0,
            bottom: 0,
            width: 200,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListView(
                children: [
                  _buildNavItem(0, 'Info', Icons.info_outline,
                      iconColor: Colors.green),
                  _buildNavItem(1, 'Kalender', Icons.calendar_today),
                  _buildNavItem(6, 'Notizen', Icons.place),
                  _buildNavItem(2, 'Namen', Icons.people),
                  _buildNavItem(3, 'Strafen', Icons.euro),
                  _buildNavItem(7, 'Finanzen', Icons.account_balance),
                  _buildNavItem(
                      8, 'Grundbetrag', Icons.account_balance_wallet_sharp),
                  _buildNavItem(12, 'Nachtrag', Icons.fast_rewind_outlined,
                      iconColor: const Color.fromARGB(255, 5, 122, 255)),
                  _buildNavItem(
                    11,
                    'Zusatzstrafe',
                    Icons.warning_amber_rounded,
                  ),
                  _buildNavItem(5, 'Daten', Icons.import_export_sharp),
                  _buildNavItem(9, 'Dark Mode', Icons.dark_mode_outlined),
                  _buildNavItem(10, 'Reset', Icons.delete_forever_outlined,
                      iconColor: Colors.redAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nur beim ersten Build die Sidebar öffnen
    if (_isFirstBuild) {
      _isFirstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSidebarOpen = true;
          });
        }
      });
    }
  }

  Widget _buildNavItem(int index, String title, IconData icon,
      {Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (isDark ? Colors.white70 : Colors.black87),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor:
          isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
      onTap: () {
        setState(() {
          _selectedIndex = index;
          if (MediaQuery.of(context).size.width < 600) {
            _isSidebarOpen = false;
          }
        });
      },
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 11:
        return const _PenaltyFineTab();
      case 2:
        return const _NamesTab();
      case 3:
        return const _FinesTab();
      case 8:
        return const _BaseFineTab();
      case 7:
        return const EinnahmeUndAusgabeTab();
      case 1:
        return const _CalendarTab();
      case 5:
        return _DataTab();
      case 10:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hier kannst du alle Daten zurücksetzen.\n'
                'Die Namen und vordefinierten Strafen bleiben erhalten.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _resetData(context),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
                child: const Text('Daten zurücksetzen'),
              ),
            ],
          ),
        );
      case 12:
        return const PastRoundTab();
      case 6:
        return const LocationNotesTab();
      case 9:
        return const _ThemeTab();
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : const Color.fromARGB(255, 0, 0, 0),
                    fontSize: 14,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Allgemeine Informationen:\n\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                        text: '• Beispiel: Importieren oder Exportieren. \n\n'
                            'Person A (Kassenwart) und Person B (Vertreter) nutzen beide die „SchockClub“ App, um das Spiel zu verwalten. Angenommen, Person A kann an einem Spieltag nicht teilnehmen und Person B übernimmt stattdessen. Damit das Spiel ohne Unterbrechung oder Neustart fortgesetzt werden kann, bietet die App die Möglichkeit, Spieldaten zwischen Nutzern auszutauschen.\n\n'
                            'In diesem Fall exportiert Person A ihre zuletzt gesammelten Spieldaten aus der App. Diese Daten können anschließend von Person B in ihre eigene App importiert werden. Dadurch wird sichergestellt, dass das Spiel exakt an der Stelle fortgesetzt werden kann, an der Person A zuletzt aufgehört hat – nahtlos und ohne Datenverlust.\n\n'
                            '• Grundbetrag und Durchschnitt.\n\n'
                            '• Der Grundbetrag kann, wenn nicht gewünscht auf 0.00€ gesetzt werden, dann gibt es keinen Grundbetrag.\n'
                            'Personen, die als „Anwesend" oder „Zu spät“ gemeldet sind, zahlen den Grundbetrag (wenn gewünscht) sowie die Strafen, die sie während der Runde selbst verursacht haben. Für abwesende Personen wird ein Durchschnitt aller in der Runde angefallenen Strafen berechnet. Sobald die Option „Runde speichern" ausgewählt wird, wird dieser Durchschnitt den Abwesenden zugeteilt – sie zahlen also den Grundbetrag plus den berechneten Durchschnittsbetrag.\n\n'
                            '\n\n'),
                    TextSpan(
                      text: 'Neustart (Beispiel)\n\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                        text: ''
                            '1. Beispielrunde vorbereiten \n\n'
                            '• Optionen:\n'
                            '• Namen der Teilnehmer hinzufügen.\n'
                            '• Strafen festlegen. (Runde verloren, Schock Hand, ...)\n'
                            '• Grundbetrag anpassen.\n'
                            '• Zusatzstrafe aktivieren (optional).\n\n'
                            '2. Neue Runde starten im Reiter "Runde".\n\n'
                            '• Neue Runde einleiten.\n'
                            '• Automatische Weiterleitung zur Anwesenheitskontrolle.\n'
                            '• Anwesenheit der Teilnehmer überprüfen.\n'
                            '• Speichern der Anwesenheit.\n'
                            '• Automatische Weiterleitung zur aktuellen Runde.\n'
                            '• Spiel durchführen und Strafen vergeben.\n'
                            '• Falsch vergebene Strafen gegebenenfalls löschen.\n'
                            '• Zu spät kommende Spieler nachtragen (dies ist bis zum Punkt „Runde speichern“ möglich).\n'
                            '• Runde speichern, wenn das Spiel beendet ist (Abend vorbei).\n'
                            '• Automatische Weiterleitung zur Strafenliste.\n\n'
                            '3. Bezahlen:\n\n'
                            '• In der Strafenliste wird vermerkt, wer welche offenen, noch nicht bezahlten Strafen zu begleichen hat.\n'
                            '• Über den Button „Bezahlen“ kann eingetragen werden, welcher Beitrag bezahlt werden soll.\n'
                            '• Als Information kann die Strafenliste einfach Kopiert (Über die Zwischenablage) und z.B. in WhatsApp eingefügt und versendet werden.\n\n'
                            '4. Anpassungen vornehmen:\n\n'
                            '• Falsche Eingaben können in der Historie korrigiert oder gelöscht werden.\n'
                            '• Gelöschte oder bearbeitete Daten in der Historie werden vermerkt, so das jede Änderung sichtbar bleibt!\n\n'
                            ' \n\n'),
                    TextSpan(
                      text: 'Bestehende Runde:\n\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' 1. Backup importieren: Lade das aktuellste Backup, um den letzten Stand des Spiels wiederherzustellen. \n\n'
                          ' 2. Daten prüfen: Stelle sicher, dass alle importierten Daten vollständig und korrekt sind. \n\n'
                          ' 3. Anpassungen vornehmen: Passe bei Bedarf Strafen oder Teilnehmer an, z. B. durch das Hinzufügen von Gästen. \n\n'
                          ' 4. Anwesenheitskontrolle durchführen.\n\n'
                          ' 5. Spielrunde starten: Nach Abschluss aller Vorbereitungen kann die Runde beginnen. \n\n'
                          ' \n\n'
                          ' \n\n',
                    ),
                    TextSpan(
                      text: 'Alle Informationen:\n\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '1️⃣ Startseite:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '\n\n - Kassenstand: Zeigt den aktuellen Gesamtbetrag aller eingezahlten Strafen\n\n'
                          ' - Spenden: Überzahlungen werden als Spenden vermerkt\n\n'
                          ' - Offene Strafen: Liste aller noch nicht bezahlten Strafen pro Person\n\n'
                          ' • Schnellzugriff-Buttons\n\n'
                          ' - Vordefinierte Strafen für häufige Vergehen\n\n'
                          ' - Tippe auf einen Button und wähle dann den Spieler aus\n\n'
                          ' - Versehentlich falsch eingetragene Strafen können während der Runde auch wieder entfernt werden.\n\n'
                          ' - Bei „Benutzerdefinierter Betrag“ kannst du einen beliebigen Betrag eingeben\n\n'
                          ' - "Alle anderen müssen zahlen" verteilt die Strafe automatisch an alle anderen Spieler\n\n'
                          ' - "Personengebundene Strafen werden nicht in den Durchschnitt einberechnet" Beispiel: „Unabgemeldetes Fehlen.“ Auch nicht anwesende Spieler können ausgewählt werden.\n\n',
                    ),
                    TextSpan(
                      text: '2️⃣ Anwesenheit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '\n\n - Anwesenheit markieren (): \n\n'
                          ' - ✅ Pünktlich (grün)\n\n'
                          ' - ⏰ Zu spät (orange)\n\n'
                          ' - ❌ Abwesend (rot)\n\n'
                          ' - Grundbetrag: Wird automatisch für alle Spieler berechnet.\n\n'
                          ' - Gäste: Zahlen keinen Grundbetrag (Einstellungen --> Namen: als Gast markieren).\n\n'
                          ' - Es kann jederzeit eine Änderungen der Anwesenheit während der aktuellen Runde vorgenommen werden.\n\n',
                    ),
                    TextSpan(
                      text: '3️⃣ Strafenliste',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '\n\n - Offene Strafen: Nach Spielern gruppiert\n\n'
                          ' - Bezahlen: \n\n'
                          ' 1. Tippe auf einen Spieler\n\n'
                          ' 2. Wähle das Datum der zu bezahlenden Strafen\n\n'
                          ' 3. Gib den Betrag ein oder wähle einen vordefinierten Wert\n\n'
                          ' - Überzahlung: Wird automatisch als Spende vermerkt\n\n'
                          ' - Export: Teile die Liste der offenen Strafen als Text per WhatsApp oder andere Apps\n\n'
                          ' - Der Text wird in die Zwischenablage kopiert und kann dann einfach eingefügt werden\n\n',
                    ),
                    TextSpan(
                      text: '4️⃣ Historie',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' \n\n - Tagesansicht: Alle Ereignisse chronologisch sortiert\n\n'
                          ' - Details pro Tag:\n\n'
                          ' - Anwesenheitsliste\n\n'
                          ' - Verhängte Strafen\n\n'
                          ' - Bezahlte Beträge 🟢\n\n'
                          ' - nicht bezahlte Beträge 🔴\n\n'
                          ' - Bearbeiten: Strafen können nachträglich angepasst werden (Passwort erforderlich)\n\n'
                          ' - Export: Exportiere einzelne Tage oder die gesamte Historie als PDF- oder XML-Datei\n\n',
                    ),
                    TextSpan(
                      text: '5️⃣ Statistik',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '\n\n- Top-Zahler: Rangliste der höchsten Strafen\n\n'
                          '- Kategorien:  \n\n'
                          '- 💰 Gesamtstrafen  \n\n'
                          '- ⚠️ Offene Strafen  \n\n'
                          '- 🎁 Spenden  \n\n'
                          '- Entwicklung: Grafische Darstellung der Strafen über Zeit.  \n\n'
                          '- Monatlich oder jährlich  \n\n'
                          '- Gesamtbetrag und offene Strafen\n\n',
                    ),
                    TextSpan(
                      text: '6️⃣ Spielerverwaltung',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '\n\n - Namen hinzufügen/bearbeiten\n\n'
                          ' - Gaststatus vergeben (keine Grundbeträge)\n\n'
                          ' - Notizen für Spieler hinterlegen\n\n',
                    ),
                    TextSpan(
                      text: '7️⃣ Strafen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '\n\n- Grundbetrag anpassen (Standard: 15.00€, falls nicht gewünscht kann dieser Wert auf 0.00€ gesetzt werden)\n\n'
                          '- Strafen verwalten\n\n'
                          '- Zusatzstrafe aktivieren:\n\n'
                          '- Automatische Zusatzstrafe bei hohen offenen Beträgen\n\n'
                          '- Schwellenwert und Strafbetrag einstellbar\n\n',
                    ),
                    TextSpan(
                      text: '8️⃣ Daten',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '\n\n- Import/Export der Gesamtdaten\n\n'
                          '- Backup erstellen\n\n',
                    ),
                    TextSpan(
                      text: '9️⃣ Tipps & Tricks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '\n\n- Bezahlen\n\n'
                          '1. Öffne die Strafenliste\n\n'
                          '2. Wähle einen Spieler\n\n'
                          '3. Tippe auf "Bezahlen"\n\n'
                          '4. Wähle das Datum\n\n'
                          '5. Gib den Betrag ein oder wähle einen vordefinierten Wert\n\n'
                          '\n\n- Export der Strafenliste\n\n'
                          '1. Teile offene Strafen direkt per WhatsApp\n\n'
                          '2. Exportiere die Historie als PDF oder XML\n\n'
                          '3. Sichere alle Daten im JSON-Format\n\n',
                    ),
                    TextSpan(
                      text: '1️⃣0️⃣ Offline/Online:\n\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Die „SchockClub" App ist so konzipiert, dass sie vollständig offline funktioniert. Das bedeutet, dass die App keine Verbindung zum Internet benötigt, wodurch sie werbefrei bleibt und keinerlei persönliche Daten online gespeichert werden. Dieses Design wurde gewählt, um den Nutzern maximale Privatsphäre zu gewährleisten und unnötige Kosten, wie beispielsweise für den Serverbetrieb, zu vermeiden.\n\n'
                          'Eine Internetverbindung wird lediglich für das Exportieren und Importieren der ausschließlich eigenen Daten benötigt. Dies erlaubt es den Nutzern, ihre Daten sicher zu übertragen und optional in ihrer eigenen Cloud zu speichern. Dadurch bleibt die Kontrolle über die Daten vollständig bei den Nutzern, ohne die Funktionsweise der App insgesamt zu beeinträchtigen. Auf diese Weise bleibt die App unabhängig, kosteneffizient und sicher nutzbar.\n\n',
                    ),
                    TextSpan(
                      text: '1️⃣1️⃣ Nachtrag',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '\n\nHier können nicht Spielrunden nachgetragen werden!\n'
                          'Bis ins Jahr 2020!\n\n',
                    ),
                    TextSpan(
                      text: '1️⃣2️⃣ Support',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '\n\nBei Fragen, Problemen oder Verbesserungsvorschlägen:\n\n'
                          'schockclub.app@gmail.com\n\n',
                    )
                  ],
                ),
              );
            },
          ),
        );
      default:
        return const Center(
          child: Text('Bitte wähle eine Option aus'),
        );
    }
  }
}

class PastRoundTab extends StatelessWidget {
  const PastRoundTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const PastRoundScreen();
  }
}

class _ThemeTab extends StatelessWidget {
  const _ThemeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, appData, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Erscheinungsbild',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('aktivieren'),
                value: appData.settings.isDarkMode,
                onChanged: (bool value) {
                  appData.updateThemeMode(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NamesTab extends StatelessWidget {
  const _NamesTab();

  Future<bool> _checkPassword(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final players = appData.players;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: player.isGuest
                      ? const Text(
                          'Gast',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : null,
                  onTap: () async {
                    final editedPlayer = await showDialog<Player>(
                      context: context,
                      builder: (context) => EditNameDialog(player: player),
                    );

                    if (editedPlayer != null) {
                      final newPlayers = List<Player>.from(players);
                      newPlayers[index] = editedPlayer;
                      appData.updatePlayers(newPlayers);
                    }
                  },
                  onLongPress: () async {
                    if (await _checkPassword(context)) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Name löschen'),
                          content: Text(
                              'Möchtest du "${player.name}" wirklich löschen?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Abbrechen'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Löschen'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        final newPlayers = List<Player>.from(players);
                        newPlayers.removeAt(index);
                        appData.updatePlayers(newPlayers);
                      }
                    }
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () async {
              final newPlayer = await showDialog<Player>(
                context: context,
                builder: (context) => const EditNameDialog(),
              );

              if (newPlayer != null) {
                final newPlayers = List<Player>.from(players)..add(newPlayer);
                appData.updatePlayers(newPlayers);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Neuen Namen hinzufügen'),
          ),
        ),
      ],
    );
  }
}

class _FinesTab extends StatelessWidget {
  const _FinesTab();

  Future<bool> _checkPassword(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final fines = appData.predefinedFines;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: fines.length,
            itemBuilder: (context, index) {
              final fine = fines[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    fine.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    fine.isCustomAmount
                        ? 'Benutzerdefinierter Betrag'
                        : '${fine.amount.toStringAsFixed(2)}€',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onTap: () async {
                    final editedFine = await showDialog<PredefinedFine>(
                      context: context,
                      builder: (context) => EditFineDialog(fine: fine),
                    );

                    if (editedFine != null) {
                      final newFines = List<PredefinedFine>.from(fines);
                      newFines[index] = editedFine;
                      appData.updatePredefinedFines(newFines);
                    }
                  },
                  onLongPress: () async {
                    if (await _checkPassword(context)) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Strafe löschen'),
                          content: Text(
                              'Möchtest du "${fine.name}" wirklich löschen?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Abbrechen'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Löschen'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        final newFines = List<PredefinedFine>.from(fines);
                        newFines.removeAt(index);
                        appData.updatePredefinedFines(newFines);
                      }
                    }
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () async {
              final newFine = await showDialog<PredefinedFine>(
                context: context,
                builder: (context) => const EditFineDialog(),
              );

              if (newFine != null) {
                final newFines = List<PredefinedFine>.from(fines)..add(newFine);
                appData.updatePredefinedFines(newFines);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Neue Strafe hinzufügen'),
          ),
        ),
      ],
    );
  }
}

class _BaseFineTab extends StatefulWidget {
  const _BaseFineTab();

  @override
  State<_BaseFineTab> createState() => _BaseFineTabState();
}

class _BaseFineTabState extends State<_BaseFineTab> {
  final _baseFineController = TextEditingController();
  bool _hasChanges = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appData = Provider.of<AppDataProvider>(context);
    _baseFineController.text = appData.baseFineAmount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Grundbetrag',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Der Grundbetrag wird automatisch für alle Spieler berechnet.\n'
            'Gäste sind von dieser Regelung ausgenommen.\n\n'
            'Wenn kein Grundbetrag gewünscht ist, kann der Wert auch auf 0.00€ gesetzt werden.',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseFineController,
            decoration: const InputDecoration(
              labelText: 'Grundbetrag (€)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _hasChanges = true;
              });
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _hasChanges
                ? () async {
                    final baseFine = double.tryParse(_baseFineController.text);

                    if (baseFine != null) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => const PasswordDialog(),
                      );

                      if (confirmed == true) {
                        if (!context.mounted) return;
                        final appData = Provider.of<AppDataProvider>(context,
                            listen: false);
                        await appData.updateSettings(
                          baseFineAmount: baseFine,
                          previousYearsBalance: appData.previousYearsBalance,
                        );

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Grundbetrag wurde aktualisiert'),
                          ),
                        );
                        setState(() {
                          _hasChanges = false;
                        });
                      }
                    }
                  }
                : null,
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _baseFineController.dispose();
    super.dispose();
  }
}

class EinnahmeUndAusgabeTab extends StatefulWidget {
  const EinnahmeUndAusgabeTab({super.key});

  @override
  State<EinnahmeUndAusgabeTab> createState() => _EinnahmeUndAusgabeTabState();
}

class _EinnahmeUndAusgabeTabState extends State<EinnahmeUndAusgabeTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addTransaction(
      BuildContext context, TransactionType type) async {
    final isAuthorized = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );

    if (isAuthorized != true) return;
    if (!context.mounted) return;

    final result = await showDialog<Transaction>(
      context: context,
      builder: (context) => EditTransactionDialog(type: type),
    );

    if (result != null && context.mounted) {
      Provider.of<AppDataProvider>(context, listen: false)
          .addTransaction(result);
    }
  }

  Future<void> _editTransaction(
      BuildContext context, Transaction transaction) async {
    final isAuthorized = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );

    if (isAuthorized != true) return;
    if (!context.mounted) return;

    final result = await showDialog<Transaction>(
      context: context,
      builder: (context) => EditTransactionDialog(
        transaction: transaction,
        type: transaction.type,
      ),
    );

    if (result != null && context.mounted) {
      Provider.of<AppDataProvider>(context, listen: false)
          .updateTransaction(transaction, result);
    }
  }

  Future<void> _deleteTransaction(
      BuildContext context, Transaction transaction) async {
    final isAuthorized = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );

    if (isAuthorized != true) return;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transaction.type == TransactionType.income
            ? 'Einnahme löschen'
            : 'Ausgabe löschen'),
        content: Text(
            'Möchtest du diese ${transaction.type == TransactionType.income ? "Einnahme" : "Ausgabe"} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Provider.of<AppDataProvider>(context, listen: false)
          .deleteTransaction(transaction);
    }
  }

  Widget _buildTransactionList(
      List<Transaction> transactions, TransactionType type) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(type == TransactionType.income
            ? 'Keine Einnahmen vorhanden'
            : 'Keine Ausgaben vorhanden'),
      );
    }

    final total = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  type == TransactionType.income ? 'Gesamt:' : 'Gesamt:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: type == TransactionType.income
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: transactions.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                child: ListTile(
                  title: Text(transaction.description),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatDate(transaction.date)),
                      if (transaction.notes != null)
                        Text(
                          transaction.notes!,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${transaction.amount.toStringAsFixed(2)}€',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: type == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Bearbeiten'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Löschen'),
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _editTransaction(context, transaction);
                              break;
                            case 'delete':
                              _deleteTransaction(context, transaction);
                              break;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, appData, child) {
        final incomeTransactions = appData.transactions
            .where((t) => t.type == TransactionType.income)
            .toList();
        final expenseTransactions = appData.transactions
            .where((t) => t.type == TransactionType.expense)
            .toList();

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kassenstand:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${appData.actualBalance.toStringAsFixed(2)}€',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appData.actualBalance >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Einnahmen'),
                Tab(text: 'Ausgaben'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tabController.index == 0 ? 'Einnahmen' : 'Ausgaben',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addTransaction(
                      context,
                      _tabController.index == 0
                          ? TransactionType.income
                          : TransactionType.expense,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _tabController.index == 0 ? '' : '',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransactionList(
                      incomeTransactions, TransactionType.income),
                  _buildTransactionList(
                      expenseTransactions, TransactionType.expense),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarTab extends StatefulWidget {
  const _CalendarTab();
  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {};
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  @override
  void dispose() {
    super.dispose();
    _saveEvents();
  }

  Future<void> _loadEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? eventsJson = prefs.getString('Termine');
    if (eventsJson != null) {
      Map<String, dynamic> decodedJson = jsonDecode(eventsJson);
      setState(() {
        _events = decodedJson.map((key, value) {
          DateTime dateKey = DateTime.parse(key);
          List<String> events = List<String>.from(value);
          return MapEntry(dateKey, events);
        });
      });
    }
  }

  Future<void> _saveEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> eventsToSave = _events.map((key, value) {
      String dateKey = key.toIso8601String();
      return MapEntry(dateKey, value);
    });
    String eventsJson = jsonEncode(eventsToSave);
    await prefs.setString('Termine', eventsJson);
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  List<MapEntry<DateTime, List<String>>> _getMonthEvents() {
    final monthEvents = <DateTime, List<String>>{};
    final currentMonth = _focusedDay.month;
    final currentYear = _focusedDay.year;

    _events.forEach((date, events) {
      if (date.month == currentMonth && date.year == currentYear) {
        monthEvents[date] = events;
      }
    });

    final sortedEntries = monthEvents.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries;
  }

  void _addEvent(String event) {
    if (_selectedDay != null) {
      setState(() {
        if (_events[_selectedDay!] == null) {
          _events[_selectedDay!] = [];
        }
        final timeStr = _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')} Uhr'
            : '';
        final fullEvent = '$timeStr - $event';
        _events[_selectedDay!]!.add(fullEvent);
        _saveEvents();
      });
    }
  }

  void _editEvent(String oldEvent) {
    TextEditingController eventController = TextEditingController();
    TimeOfDay? editTime;

    // Extrahiere Zeit und Event aus dem String
    if (oldEvent.contains(' - ')) {
      final parts = oldEvent.split(' - ');
      if (parts[0].contains('Uhr')) {
        final timePart = parts[0].replaceAll(' Uhr', '').split(':');
        editTime = TimeOfDay(
            hour: int.parse(timePart[0]), minute: int.parse(timePart[1]));
        eventController.text = parts[1];
      } else {
        eventController.text = oldEvent;
      }
    } else {
      eventController.text = oldEvent;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Termin bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eventController,
                decoration: InputDecoration(
                  hintText: 'Termin bearbeiten',
                  border: const OutlineInputBorder(),
                  filled: isDark,
                  fillColor: isDark ? Colors.grey[800] : null,
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: editTime ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() => editTime = time);
                  }
                },
                child: Text(editTime != null
                    ? '${editTime!.hour.toString().padLeft(2, '0')}:${editTime!.minute.toString().padLeft(2, '0')} Uhr'
                    : 'Zeit auswählen'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                if (eventController.text.isNotEmpty) {
                  setState(() {
                    List<String> events = _events[_selectedDay!]!;
                    final timeStr = editTime != null
                        ? '${editTime!.hour.toString().padLeft(2, '0')}:${editTime!.minute.toString().padLeft(2, '0')} Uhr'
                        : '';
                    final newEvent = timeStr.isNotEmpty
                        ? '$timeStr - ${eventController.text}'
                        : eventController.text;
                    events[events.indexOf(oldEvent)] = newEvent;
                    _saveEvents();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEvent(String event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termin löschen'),
        content: const Text(
            'Bist du sicher, dass du diesen Termin löschen möchtest?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                List<String> events = _events[_selectedDay!]!;
                events.remove(event);
                if (events.isEmpty) {
                  _events.remove(_selectedDay);
                }
                _saveEvents();
              });
              Navigator.pop(context);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    TextEditingController eventController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Termin hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eventController,
                decoration: InputDecoration(
                  hintText: 'Termin hier eintragen!',
                  border: const OutlineInputBorder(),
                  filled: isDark,
                  fillColor: isDark ? Colors.grey[800] : null,
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() => _selectedTime = time);
                  }
                },
                child: Text(_selectedTime != null
                    ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')} Uhr'
                    : 'Zeit auswählen'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                if (eventController.text.isNotEmpty) {
                  _addEvent(eventController.text);
                }
                Navigator.pop(context);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember'
    ];
    return monthNames[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthEvents = _getMonthEvents();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              defaultTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.white,
              ),
              markerDecoration: BoxDecoration(
                color: isDark ? Colors.blue[300] : Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 17.0,
              ),
              formatButtonTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: isDark ? Colors.white : Colors.black,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              weekendStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_selectedDay != null) {
                _showAddEventDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Du musst schon ein Datum auswählen!'),
                  ),
                );
              }
            },
            child: const Text('Termin hinzufügen'),
          ),
          if (monthEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Termine im ${_getMonthName(_focusedDay.month)}:',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...monthEvents
                      .map((entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _formatDate(entry.key),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      entry.value.join(', '),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedDay != null) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _events[_selectedDay!]
                        ?.map((event) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: isDark ? Colors.grey[800] : null,
                              child: ListTile(
                                title: Text(
                                  event,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                onTap: () => _editEvent(event),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: isDark ? Colors.white70 : null,
                                  ),
                                  onPressed: () => _deleteEvent(event),
                                ),
                              ),
                            ))
                        .toList() ??
                    [],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataTab extends StatefulWidget {
  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hier können Daten Exportiert, sowie Importiert werden.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        try {
                          setState(() => _isLoading = true);
                          await appData.exportData(context);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Daten wurden erfolgreich exportiert!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fehler beim Exportieren: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Daten exportieren'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        try {
                          setState(() => _isLoading = true);
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                          );

                          if (result != null &&
                              result.files.single.path != null) {
                            final file = File(result.files.single.path!);
                            final jsonString = await file.readAsString();
                            await appData.importData(jsonString, context);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Daten wurden erfolgreich importiert! Neustart erforderlich.'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // Erzwinge einen Rebuild der gesamten App
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fehler beim Importieren: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Daten importieren'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Hinweis: Der Export erstellt eine JSON-Datei mit allen App-Daten, die du auf anderen Geräten importieren kannst.',
                style: TextStyle(
                  color: Color.fromARGB(255, 98, 98, 99),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _PasswordTab extends StatefulWidget {
  const _PasswordTab();

  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Passwort ändern',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _currentPasswordController,
            obscureText: !_showCurrentPassword,
            decoration: InputDecoration(
              labelText: 'Aktuelles Passwort',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _showCurrentPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _showCurrentPassword = !_showCurrentPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              labelText: 'Neues Passwort',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _showNewPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Neues Passwort bestätigen',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (_currentPasswordController.text != '123456789') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Das aktuelle Passwort ist falsch'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (_newPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte gib ein neues Passwort ein'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (_newPasswordController.text !=
                  _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Die neuen Passwörter stimmen nicht überein'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Here you would update the password in your storage
              // For now, we'll just show a success message
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Passwort wurde erfolgreich geändert'),
                  backgroundColor: Colors.green,
                ),
              );

              // Clear the text fields
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
            },
            child: const Text('Passwort ändern'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _PenaltyFineTab extends StatefulWidget {
  const _PenaltyFineTab();

  @override
  State<_PenaltyFineTab> createState() => _PenaltyFineTabState();
}

class _PenaltyFineTabState extends State<_PenaltyFineTab> {
  final _thresholdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _hasChanges = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appData = Provider.of<AppDataProvider>(context);
    _thresholdController.text =
        appData.settings.penaltyFineThreshold.toString();
    _amountController.text = appData.settings.penaltyFineAmount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, appData, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Zusatzstrafe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Zusatzstrafe aktivieren'),
                    subtitle: const Text(
                        'Automatisch eine zusätzliche Strafe für hohe offene Strafen vergeben'),
                    value: appData.settings.isPenaltyFineEnabled,
                    onChanged: (value) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => const PasswordDialog(),
                      );

                      if (confirmed == true) {
                        await appData.updatePenaltyFineSettings(
                            isEnabled: value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Grenzwert für offene Strafen (€)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Ab diesem Betrag wird die Zusatzstrafe verhängt',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _hasChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Höhe der Zusatzstrafe (€)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Dieser Betrag wird als zusätzliche Strafe verhängt',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _hasChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _hasChanges
                        ? () async {
                            final threshold =
                                double.tryParse(_thresholdController.text);
                            final amount =
                                double.tryParse(_amountController.text);

                            if (threshold != null && amount != null) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => const PasswordDialog(),
                              );

                              if (confirmed == true) {
                                if (!context.mounted) return;
                                await appData.updatePenaltyFineSettings(
                                  threshold: threshold,
                                  amount: amount,
                                );

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Zusatzstrafe wurde aktualisiert'),
                                  ),
                                );
                                setState(() {
                                  _hasChanges = false;
                                });
                              }
                            }
                          }
                        : null,
                    child: const Text('Speichern'),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Die Zusatzstrafe wird automatisch verhängt, wenn:\n'
                            '• Die Funktion aktiviert ist\n'
                            '• Eine Person offene Strafen über dem Grenzwert hat\n'
                            '• Wenn die Anwesenheit kontrolliert wird, wird die Strafe erst verhängt.\n\n'
                            'Die Zusatzstrafe wird nicht in den Durchschnitt einberechnet.',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
