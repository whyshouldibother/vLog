# vLog - Vehicle Maintenance Tracker

A FOSS (Free and Open Source), privacy-first, offline-first vehicle maintenance tracking app.

## What is this?

**vLog** lets you track fuel consumption, maintenance records, and expenses for your vehicles - cars, bikes, custom builds, whatever you have.

## Why Does This Exist?

I needed something that:
- Works with custom vehicles (not just standard cars)
- Respects privacy (no accounts, no cloud)
- Works offline
- Is actually open source

I also discovered [CarVita](https://f-droid.org/packages/com.axelmdev.carvita/) on F-Droid while building this - check it out if you mostly track cars.

## ⚠️ Important Note

**This app was generated almost entirely by AI.**

I had basic Flutter knowledge (like a day of tinkering, never continued). I described what I wanted to ChatGPT, got a dev prompt, then did revisions on whatever AI model had credits available. Waited. Repeat. And now here we are.

The code works. I tested it. It's usable for me, so I'm putting it on GitHub (and hoping for F-Droid) so I can get it easily. Future updates may or may not arrive - this still needs a lot of work.

## Features

- **Multiple Vehicle Management**: Track all your vehicles
- **Fuel History**: Record fuel entries and track consumption  
- **Maintenance Records**: Log services and repairs
- **Reminders**: Set up recurring maintenance reminders
- **Dashboard**: Visualize costs and statistics
- **Local Storage**: Everything stored locally in SQLite
- **Backup/Restore**: Export to JSON
- **No Internet Required**: Works completely offline
- **No Ads or Tracking**: Privacy first

## Download

Grab the APK from releases or build it yourself.

## Building From Source

```bash
git clone https://github.com/whyshouldibother/vlog.git
cd vlog
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

## Tech Stack

- **Flutter 3.x** + **Dart**
- **Riverpod** - State management
- **SQLite** - Local database
- **fl_chart** - Charts
- **flutter_animate** - Animations
- See `pubspec.yaml` for complete list

## Privacy & Security

- ✅ Zero data collection
- ✅ Zero network calls
- ✅ Zero third-party APIs
- ✅ Zero accounts required
- ✅ Open source

Your data is yours. Period.

## Architecture

```
Screens → Riverpod → Repository → SQLite
```

Simple.

## Known Issues

- AI-generated code (obviously)
- Probably has anti-patterns
- Dashboard animations might be overkill
- There are definitely better ways to do some things
- Use at your own risk

## Contributing

PRs welcome. Especially if you actually know Flutter and want to fix my AI-generated mess.

## License

MIT - Do whatever.

## Acknowledgments

- Whatever AI models had credits at the time
- ChatGPT for the initial dev prompt
- Flutter team for making this possible
- CarVita devs for the inspiration

---

*Made with AI assistance and minimal Flutter knowledge. It works. That's the point.*
