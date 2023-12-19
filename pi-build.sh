#Uses flutter-pi to build a flutter release for a Pi Zero 2W
echo Building for flutter-pi
flutterpi_tool build --release --cpu=pi3 --arch=arm
#flutterpi_tool build --debug --cpu=pi3 --arch=arm
echo "Copy build to PI zero host (thermostat-host)"
rsync -a --progress ./build/flutter_assets/ thermostat-host:thermostat-flutter/
