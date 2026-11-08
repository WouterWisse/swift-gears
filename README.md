# SwiftGears

Virtual shifting on your trainer without the Zwift app. Shift with the Zwift Ride handlebars and the
Wahoo KICKR CORE (Zwift One, with the Zwift Cog) changes resistance, while you ride in any training app.

- The left shifters make it easier, the right shifters harder.
- Zwift's own 24 gear ratios, on a flat road. The trainer works out the resistance itself.
- Keeps shifting in the background, so your training app can stay in front.
- No account, no tracking, no settings to get through.

## Requirements

- iPhone with iOS 17 or later
- Wahoo KICKR CORE with the Zwift Cog, on recent firmware (update it in the Wahoo app)
- Zwift Ride handlebars. A Ride on firmware 1.3 or later must be unlocked in Zwift once a day.
- Let your training app only read power and cadence from the trainer. If it also sets resistance
  (ERG workouts, hills), the two apps will fight over the trainer.

## Build

```sh
brew install xcodegen
xcodegen            # creates SwiftGears.xcodeproj
open SwiftGears.xcodeproj
```

Pick your own team under Signing & Capabilities, then run it on your iPhone. Bluetooth does not work in
the simulator. The protocol code has tests that run on the Mac: `swift test`.

## How it works

Both the trainer and the Ride speak Zwift's Bluetooth protocol: one opcode byte followed by a protobuf
message. SwiftGears sends the trainer the same gear message Zwift sends, with the gear ratio and your
weight, and reads the Ride's button presses. See [`Sources/GearsCore/Zwift.swift`](Sources/GearsCore/Zwift.swift).

The protocol was reverse engineered by others. Thanks to:

- [Makinolo](https://www.makinolo.com/blog/2024/10/20/zwift-trainer-protocol/) for the Zwift Ride and trainer protocol write-ups
- [SHIFTR](https://github.com/JuergenLeber/SHIFTR) for the gear ratios and message layout
- [BikeControl](https://github.com/OpenBikeControl/bikecontrol) for the Ride button map

## Disclaimer

SwiftGears is not affiliated with, endorsed by or connected to Zwift, Inc. or Wahoo Fitness. Zwift,
Zwift Ride, Zwift Cog, KICKR and KICKR CORE are trademarks of their owners. Zwift can change the
protocol with a firmware update at any time.

## License

MIT
